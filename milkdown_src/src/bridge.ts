/**
 * JS ↔ Dart 桥接:把 Milkdown 编辑器封装为 `window.bridge` 全局对象,
 * 供 Flutter WebView 通过 `runJavaScript('window.bridge.xxx()')` 调用。
 *
 * 反向(Dart 接收 JS 消息):通过 `window.MdBridge.postMessage(json)`
 * 触发 Flutter 端 `addJavaScriptChannel('MdBridge', onMessageReceived: ...)`。
 *
 * Phase 7b 改造:
 *   - setupBridge 接收 EditorTheme,初始化时已注入
 *   - applyThemeVariables:把主题变量写入 :root,并触发 native_features 刷新
 *   - setTheme:运行时切换主题,触发 Milkdown 全量重渲染以更新 codeHighlight
 */
import type { Editor } from '@milkdown/kit';
import { getMarkdown, replaceAll } from '@milkdown/kit/utils';
import type { EditorTheme } from './main';

export type BridgeMode = 'wysiwyg' | 'source';

/** Block-level JSON patch emitted by the native incremental renderer. */
export interface NativeDomPatch {
  type?: string;
  path?: string;
  from: number;
  deleteCount: number;
  html: string[];
}

export interface BridgeApi {
  init(opts: { initialContent: string; theme: EditorTheme }): Promise<void>;
  setContent(md: string): void;
  getContent(): string;
  getHTML(): string;
  setMode(mode: BridgeMode): void;
  setTheme(theme: EditorTheme): void;
  applyPatches(patches: NativeDomPatch[]): void;
  renderMermaid(source: string, hash?: string): void;
}

declare global {
  interface Window {
    bridge?: BridgeApi;
    MdBridge?: { postMessage(msg: string): void };
    nativeFeatures?: {
      setTheme?: (variables: Record<string, string>) => void;
      applyPatches?: (patches: NativeDomPatch[]) => void;
      refresh?: (root?: ParentNode) => void;
      rememberSelection?: (range: Range | null) => void;
      applyCodeBadges?: (map: Record<string, string>) => void;
    };
  }
}

function nativePreview(): HTMLElement {
  let preview = document.getElementById('native-render-preview');
  if (!preview) {
    preview = document.createElement('div');
    preview.id = 'native-render-preview';
    preview.hidden = true;
    document.body.appendChild(preview);
  }
  return preview;
}

/** Apply only changed blocks to the existing DOM (never a full document HTML). */
function applyNativePatches(patches: NativeDomPatch[]): void {
  const preview = nativePreview();
  for (const patch of patches ?? []) {
    const from = Math.max(0, patch.from | 0);
    const deleteCount = Math.max(0, patch.deleteCount | 0);
    for (let i = 0; i < deleteCount; i += 1) preview.children[from]?.remove();
    const reference = preview.children[from] ?? null;
    for (const html of patch.html ?? []) {
      if (reference) reference.insertAdjacentHTML('beforebegin', html);
      else preview.insertAdjacentHTML('beforeend', html);
      const inserted = reference?.previousElementSibling ?? preview.lastElementChild;
      if (inserted) window.nativeFeatures?.refresh?.(inserted);
    }
  }
}

/**
 * Apply theme variables to the document root, plus drive native_features
 * (line-number / badge / font) tokens. Used both at init time and on
 * `bridge.setTheme`.
 */
export function applyThemeVariables(theme: EditorTheme): void {
  const html = document.documentElement;
  html.classList.add('theme-transitioning');
  Object.entries(theme.variables || {}).forEach(([key, value]) => {
    html.style.setProperty(key, value);
  });
  // Mono font stack
  if (theme.codeFonts && theme.codeFonts.length) {
    const family = theme.codeFonts.map((f) => /[\s]/.test(f) ? `"${f}"` : f).join(', ');
    html.style.setProperty('--code-font-family', family);
  }
  // Badge colors → per-language CSS variables
  if (theme.codeBadgeMap) {
    Object.entries(theme.codeBadgeMap).forEach(([lang, color]) => {
      html.style.setProperty(`--code-badge-${lang}`, color);
    });
  }
  window.setTimeout(() => html.classList.remove('theme-transitioning'), 500);
  window.nativeFeatures?.applyCodeBadges?.(theme.codeBadgeMap || {});
}

export function postBridge(
  type: 'ready' | 'changed' | 'selection' | 'mermaidRequest' | 'error' | 'codeCopied',
  payload: Record<string, unknown> = {},
): void {
  try {
    window.MdBridge?.postMessage(JSON.stringify({ type, ...payload }));
  } catch (e) {
    // Flutter 端 channel 未注册时 window.MdBridge 为 undefined,忽略
    console.error('postBridge failed', e);
  }
}

/**
 * 把已初始化的 [editor] 封装为 BridgeApi 并注册到 `window.bridge`。
 * 由 main.ts 在 `Editor.make().create()` 完成后调用。
 */
export function setupBridge(editor: Editor, theme: EditorTheme): void {
  // Coordinates are emitted in the WebView root's coordinate space, matching
  // the Flutter Stack that hosts WebViewWidget. This remains stable for text
  // in paragraphs, tables, and nested code editors.
  let lastSelectionMessage = '';
  const emitSelection = (value: Record<string, unknown>): void => {
    const next = JSON.stringify(value);
    if (next === lastSelectionMessage) return;
    lastSelectionMessage = next;
    postBridge('selection', value);
  };
  const onSelectionChange = (): void => {
    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0 || selection.isCollapsed) {
      window.nativeFeatures?.rememberSelection?.(null);
      emitSelection({
        text: '', left: 0, top: 0, width: 0, height: 0,
        start: 0, end: 0, collapsed: true,
      });
      return;
    }
    const range = selection.getRangeAt(0);
    const rect = range.getBoundingClientRect();
    const root = document.getElementById('app') || document.documentElement;
    const rootRect = root.getBoundingClientRect();
    const text = selection.toString();
    window.nativeFeatures?.rememberSelection?.(range.cloneRange());
    emitSelection({
      text,
      left: rect.left - rootRect.left,
      top: rect.top - rootRect.top,
      width: rect.width,
      height: rect.height,
      start: 0,
      end: text.length,
      collapsed: false,
    });
  };
  document.addEventListener('selectionchange', onSelectionChange);
  // Recalculate when the WebView content scrolls so the toolbar remains
  // attached to the selected rectangle instead of drifting in the Flutter UI.
  document.addEventListener('scroll', onSelectionChange, true);
  window.visualViewport?.addEventListener('resize', onSelectionChange);

  const api: BridgeApi = {
    async init() {
      // 初始化由 main.ts 的 init() 完成,这里 no-op
    },
    setContent(md: string) {
      // replaceAll 用解析后的 doc 替换整个编辑器内容
      editor.action(replaceAll(md));
    },
    getContent(): string {
      // getMarkdown 是 Milkdown v7 提供的 util,返回当前 md 文本
      return editor.action(getMarkdown()) ?? '';
    },
    getHTML(): string {
      // 取渲染后的 HTML(供 PDF 导出用),直接读 #app 内 innerHTML
      const el = document.getElementById('app');
      return el ? el.innerHTML : '';
    },
    setMode(mode: BridgeMode) {
      const root = document.getElementById('app');
      if (!root) return;
      const md = editor.action(getMarkdown()) ?? '';
      if (mode === 'source') {
        // 源码模式：隐藏 Milkdown，显示 textarea
        const proseEl = root.querySelector('.ProseMirror');
        if (proseEl) (proseEl as HTMLElement).style.display = 'none';
        let textarea = root.querySelector('#source-textarea') as HTMLTextAreaElement;
        if (!textarea) {
          textarea = document.createElement('textarea');
          textarea.id = 'source-textarea';
          textarea.className = 'source-textarea';
          textarea.value = md;
          textarea.setAttribute('aria-label', 'Markdown source');
          textarea.style.cssText = 'width:100%;height:100%;padding:18px;font-family:monospace;background:var(--editor-bg,#fff);color:var(--editor-fg,#24292f);border:none;resize:none;outline:none;box-sizing:border-box;';
          textarea.addEventListener('input', () => {
            postBridge('changed', { md: textarea.value });
          });
          root.appendChild(textarea);
        } else {
          textarea.value = md;
          textarea.style.display = 'block';
        }
      } else {
        // WYSIWYG 模式：显示 Milkdown，隐藏 textarea
        const textarea = root.querySelector('#source-textarea') as HTMLTextAreaElement;
        if (textarea) {
          textarea.style.display = 'none';
        }
        const proseEl = root.querySelector('.ProseMirror');
        if (proseEl) (proseEl as HTMLElement).style.display = '';
        // 将 textarea 内容应用回编辑器
        if (textarea && editor) {
          editor.action(replaceAll(textarea.value));
        }
      }
    },
    setTheme(newTheme: EditorTheme) {
      applyThemeVariables(newTheme);
      // 触发全量重渲染以让 CodeMirror HighlightStyle 重新应用
      const md = editor.action(getMarkdown()) ?? '';
      editor.action(replaceAll(md));
      // 让 native_features 刷新 toolbar / 徽章
      window.nativeFeatures?.refresh?.(document);
    },
    applyPatches: applyNativePatches,
    renderMermaid(source: string, hash = '') {
      postBridge('mermaidRequest', { source, hash });
    },
  };
  window.bridge = api;
}
