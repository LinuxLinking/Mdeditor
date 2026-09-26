/**
 * Milkdown v7 编辑器入口。
 *
 * Vite 打包为 IIFE 单文件 `assets/web/editor.js`,由 Flutter WebView 通过
 * `loadFlutterAsset('assets/web/index.html')` 加载。
 *
 * Phase 7b 改造:
 *   - 移除硬编码 codeHighlight,改为根据 `bridge.init(opts.theme)` 注入
 *   - 移除 `use(nord)` 旧装饰逻辑(由 themes 变量驱动)
 *   - codeHighlight / codeBadgeMap / codeFonts 由 Dart 端推送
 */
import { Editor, rootCtx, defaultValueCtx } from '@milkdown/kit/core';
import { commonmark } from '@milkdown/kit/preset/commonmark';
import { gfm } from '@milkdown/kit/preset/gfm';
import { history } from '@milkdown/kit/plugin/history';
import { clipboard } from '@milkdown/kit/plugin/clipboard';
import { listener, listenerCtx } from '@milkdown/kit/plugin/listener';
import { cursor } from '@milkdown/kit/plugin/cursor';
import { codeBlockComponent, codeBlockConfig } from '@milkdown/kit/component/code-block';
import { LanguageDescription, StreamLanguage, StreamParser } from '@codemirror/language';
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language';
import { Tag, tags as t } from '@lezer/highlight';

import { setupBridge, postBridge, applyThemeVariables, type BridgeMode } from './bridge';

let editor: Editor | null = null;
let currentTheme: EditorTheme | null = null;
let currentContent: string = '';  // 保存切换前的编辑器内容
let editorMode: 'wysiwyg' | 'source' = 'wysiwyg';

/** Theme payload delivered from Dart through `bridge.init`. */
export interface EditorTheme {
  name: string;
  variables: Record<string, string>;
  codeHighlight: HighlightSpec[];
  codeBadgeMap: Record<string, string>;
  codeFonts: string[];
}

export interface HighlightSpec {
  tag: string;
  color: string;
  fontStyle?: string;
  fontWeight?: string;
}

/** Map of lezer/highlight tag string → tag instance. */
const TAG_MAP: Record<string, Tag> = {
  comment: t.comment,
  lineComment: t.lineComment,
  blockComment: t.blockComment,
  docComment: t.docComment,
  string: t.string,
  string2: t.string2,
  number: t.number,
  integer: t.integer,
  float: t.float,
  keyword: t.keyword,
  controlKeyword: t.controlKeyword,
  operatorKeyword: t.operatorKeyword,
  typeName: t.typeName,
  typeOperator: t.typeOperator,
  function: t.function(t.name),
  functionName: t.function(t.definition(t.variableName)),
  operator: t.operator,
  punctuation: t.punctuation,
  variableName: t.variableName,
  variableName2: t.variableName2,
  definition: t.definition(t.variableName),
  special: t.special(t.string),
  meta: t.meta,
  tagName: t.tagName,
  attributeName: t.attributeName,
  attributeValue: t.attributeValue,
  heading: t.heading,
  link: t.link,
  url: t.url,
  emphasis: t.emphasis,
  strong: t.strong,
  monospace: t.monospace,
  strikethrough: t.strikethrough,
  inserted: t.inserted,
  deleted: t.deleted,
  changed: t.changed,
  invalid: t.invalid,
  regexp: t.regexp,
  escape: t.escape,
  contentSeparator: t.contentSeparator,
};

/** Build HighlightStyle from Dart-pushed HighlightSpec[]. */
function buildHighlightStyle(specs: HighlightSpec[]): HighlightStyle {
  const styles = specs.map((s) => {
    const tag = TAG_MAP[s.tag];
    if (!tag) return null;
    return {
      tag,
      color: s.color,
      ...(s.fontStyle ? { fontStyle: s.fontStyle } : {}),
      ...(s.fontWeight ? { fontWeight: s.fontWeight } : {}),
    };
  }).filter((x): x is NonNullable<typeof x> => x !== null);
  return HighlightStyle.define(styles as any);
}

/**
 * Keep the editing surface usable if a Milkdown plugin fails to initialise on
 * an older Android WebView.  A blank WebView is much worse than a plain
 * Markdown textarea: users can still open, edit and save the document.
 */
function mountFallback(root: HTMLElement, initialContent: string, theme: EditorTheme | null): void {
  root.innerHTML = '';
  const textarea = document.createElement('textarea');
  textarea.value = initialContent;
  textarea.setAttribute('aria-label', 'Markdown source');
  textarea.addEventListener('input', () => {
    postBridge('changed', { md: textarea.value });
  });
  root.appendChild(textarea);
  if (theme) applyThemeVariables(theme);
  window.bridge = {
    init: async () => {},
    setContent: (md: string) => { textarea.value = md; },
    getContent: () => textarea.value,
    getHTML: () => `<pre>${textarea.value.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c] ?? c))}</pre>`,
    setMode: (mode: BridgeMode) => {
      if (mode === 'source') {
        // 切换到源码模式：保存当前内容并显示 textarea
        currentContent = editor ? (editor.action(getMarkdown()) ?? '') : textarea.value;
        textarea.value = currentContent;
        if (editor) {
          // 隐藏 ProseMirror 但保留
          const proseEl = root.querySelector('.ProseMirror');
          if (proseEl) proseEl.attachShadow?.({ mode: 'closed' }) || (proseEl as HTMLElement).style?.setProperty('display', 'none');
        }
        textarea.style.display = 'block';
        editorMode = 'source';
      } else {
        // 切换到 WYSIWYG 模式：textarea 保持显示（Milkdown fallback 时）
        textarea.style.display = 'block';
        editorMode = 'wysiwyg';
      }
    },
    setTheme: (t: EditorTheme) => applyThemeVariables(t),
    applyPatches: () => {},
    renderMermaid: () => {},
  };
  postBridge('ready');
}

async function init(opts: { initialContent: string; theme: EditorTheme }): Promise<void> {
  const root = document.getElementById('app');
  try {
    if (!root) throw new Error('#app element not found');
    currentTheme = opts.theme;
    applyThemeVariables(opts.theme);


    const codeHighlight = buildHighlightStyle(opts.theme.codeHighlight);
    const monoFontFamily = opts.theme.codeFonts.length
      ? opts.theme.codeFonts.map((f) => /[\s]/.test(f) ? `"${f}"` : f).join(', ')
      : 'monospace';

    // 强制保留 codeBlockComponent:通过 setupBridge 引用防止 tree-shaking 消除
    const _codeBlockRef = { component: codeBlockComponent, config: codeBlockConfig };
    editor = await Editor.make()
      .use(commonmark)
      .use(gfm)
      .use(history)
      .use(clipboard)
      .use(cursor)
      .use(listener)
      .use(codeBlockComponent)
      .config((ctx) => {
        ctx.set(rootCtx, root);
        ctx.set(defaultValueCtx, opts.initialContent);
        // CodeBlock 字体从主题变量栈读取
        document.documentElement.style.setProperty('--code-font-family', monoFontFamily);
        // CodeBlock 徽章颜色暴露给 native_features 用于高亮顶部 toolbar
        Object.entries(opts.theme.codeBadgeMap).forEach(([lang, color]) => {
          document.documentElement.style.setProperty(`--code-badge-${lang}`, color);
        });
        const mkLang = (name: string, aliases: string[], keywords: string[], builtins: string[] = []) =>
          LanguageDescription.of({
            name,
            alias: aliases,
            support: StreamLanguage.define<StreamParser>({
              token: (stream: any) => {
                if (stream.eatSpace()) return null;
                if (stream.match(/(?:[^`\\]|\\.)*?`/)) return 'string';
                if (stream.match(/\/\/[^\n]*/)) return 'comment';
                if (stream.match(/\/\*[\s\S]*?\*\//)) return 'comment';
                if (stream.match(/"(?:[^"\\]|\\.)*"/)) return 'string';
                if (stream.match(/'(?:[^'\\]|\\.)*'/)) return 'string';
                if (stream.match(/\b\d+\.?\d*\b/)) return 'number';
                if (stream.match(new RegExp('\\b(' + keywords.join('|') + ')\\b'))) return 'keyword';
                if (builtins.length && stream.match(new RegExp('\\b(' + builtins.join('|') + ')\\b'))) return 'typeName';
                if (stream.match(/\b[a-zA-Z_]\w*(?=\s*\()/)) return 'function';
                stream.next();
                return null;
              },
            }),
          });
        const langs = [
          mkLang('javascript', ['js', 'jsx', 'ts', 'typescript', 'tsx'],
            ['const','let','var','function','return','if','else','for','while','do','switch','case','break','continue','new','this','class','extends','import','export','from','default','async','await','try','catch','finally','throw','typeof','instanceof','in','of','yield','delete','void','null','undefined','true','false','super','static','get','set'],
            ['console','window','document','Math','JSON','Promise','Array','Object','String','Number','Boolean','Map','Set','Date','RegExp','Error','Symbol','parseInt','parseFloat','setTimeout','setInterval','fetch','require','module','exports','process']),
          mkLang('python', ['py'],
            ['def','class','if','elif','else','for','while','return','import','from','as','try','except','finally','raise','with','yield','lambda','pass','break','continue','and','or','not','is','in','True','False','None','global','nonlocal','assert','del','print'],
            ['range','len','int','str','float','list','dict','tuple','set','bool','type','input','open','print','enumerate','zip','map','filter','sorted','reversed','abs','max','min','sum','any','all','isinstance','hasattr','getattr','setattr']),
          mkLang('bash', ['sh', 'shell', 'zsh'],
            ['if','then','else','elif','fi','for','while','do','done','case','esac','function','return','in','select','until','local','export','source','alias','unalias','readonly','shift','exit','exec','eval','set','unset','trap','wait']),
          mkLang('html', ['xml'],
            ['html','head','body','div','span','p','a','img','ul','ol','li','table','tr','td','th','form','input','button','select','option','script','style','link','meta','title','h1','h2','h3','h4','h5','h6','br','hr']),
          mkLang('css', ['scss', 'less'],
            ['color','background','margin','padding','border','font','display','position','width','height','top','left','right','bottom','flex','grid','transition','animation','transform','opacity','z-index','overflow','cursor']),
          mkLang('json', [], []),
          mkLang('sql', [],
            ['SELECT','FROM','WHERE','INSERT','INTO','VALUES','UPDATE','SET','DELETE','CREATE','TABLE','ALTER','DROP','INDEX','JOIN','LEFT','RIGHT','INNER','OUTER','ON','AND','OR','NOT','IN','BETWEEN','LIKE','ORDER','BY','GROUP','HAVING','LIMIT','OFFSET','UNION','AS','DISTINCT','NULL','IS','TRUE','FALSE','COUNT','SUM','AVG','MIN','MAX']),
          mkLang('markdown', ['md'], []),
        ];

        ctx.set(codeBlockConfig.key, {
          extensions: [syntaxHighlighting(codeHighlight)],
          languages: langs,
          expandIcon: '⬇',
          searchIcon: '🔍',
          clearSearchIcon: '⌫',
          searchPlaceholder: '搜索语言',
          noResultText: '无结果',
          copyText: '复制',
          copyIcon: '📋',
          onCopy: () => {},
          renderLanguage: (lang: string) => lang,
          renderPreview: () => null,
          previewToggleButton: (previewOnly: boolean) => previewOnly ? '编辑' : '隐藏',
          previewLabel: '预览',
          previewLoading: '加载中...',
        });
        ctx.get(listenerCtx).markdownUpdated((_ctx, md) => {
          postBridge('changed', { md });
        });
      })
      .create();

    setupBridge(editor, opts.theme);
    // 暴露 codeBlockRef 到全局,防止 tree-shaking 消除
    (window as any).__codeBlockRef = _codeBlockRef;
    postBridge('ready');
  } catch (e) {
    // Do not leave #app empty when Milkdown is incompatible with the device.
    // The fallback still fulfils the core open/edit/save workflow.
    if (root) mountFallback(root, opts.initialContent, opts.theme);
    postBridge('error', { message: String(e) });
    console.error('Milkdown initialisation failed; using textarea fallback', e);
    if (e && e.stack) console.error('Stack:', e.stack);
  }
}

/** Get the active theme — used by bridge.setTheme to refresh. */
export function getActiveTheme(): EditorTheme | null {
  return currentTheme;
}

// 暴露给 Flutter 端 runJavaScript 调用。
window.bridge = {
  init,
  setContent: (_md: string) => { /* init 前为 noop */ },
  getContent: () => '',
  getHTML: () => '',
  setMode: (_mode: 'wysiwyg' | 'source') => { /* TODO Phase 1+ */ },
  setTheme: (theme: EditorTheme) => {
    currentTheme = theme;
    applyThemeVariables(theme);
    // 由 bridge 层处理 Milkdown 重渲染
  },
  applyPatches: (_patches) => { /* setupBridge installs the DOM implementation */ },
  renderMermaid: (_source, _hash) => { /* setupBridge installs the native request */ },
};
