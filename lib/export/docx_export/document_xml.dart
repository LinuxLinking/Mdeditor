import '../../md_ast/ast.dart';
import 'docx_options.dart';
import 'code_tokenizer.dart';
import 'image_source.dart';
import 'media.dart';
import 'rels.dart';
import 'toc.dart';

/// 生成 word/document.xml:遍历 AST 输出 OOXML 段落 + 行内元素。
///
/// 历史修复:
///   - 表格解析(parser 已加 md.TableSyntax)
///   - sectPr 子元素顺序(headerReference/footerReference 在 pgSz/pgMar 之前)
///   - 图片 namespace 在根元素声明,不在 <pic:pic> 内重复
///   - CodeBlock 跳过尾部空行、字体改由 SourceCode 样式继承
///   - 嵌套格式(粗体套斜体)合并到一个 rPr,不再丢内层属性
class DocumentXmlBuilder {
  final DocxOptions options;
  final MediaCollector mediaCollector;
  final RelsCollector relsCollector;

  DocumentXmlBuilder(this.options, this.mediaCollector, this.relsCollector);

  String build(Document ast) {
    final body = StringBuffer();
    if (options.includeToc) {
      body.write(TocBuilder.buildParagraph());
    }
    for (final child in ast.children) {
      body.write(_block(child, ilvl: 0));
    }
    final sectPr = StringBuffer();
    sectPr.writeln('<w:sectPr>');
    // OOXML spec: header/footer reference 必须先于 pgSz/pgMar
    if (options.includeHeaderFooter) {
      final headerRId = relsCollector.register(
        target: 'header1.xml',
        type: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header',
      );
      final footerRId = relsCollector.register(
        target: 'footer1.xml',
        type: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer',
      );
      sectPr.writeln(
        '<w:headerReference w:type="default" r:id="' + headerRId + '"/>',
      );
      sectPr.writeln(
        '<w:footerReference w:type="default" r:id="' + footerRId + '"/>',
      );
    }
    sectPr.writeln('<w:pgSz w:w="11906" w:h="16838"/>');
    sectPr.writeln(
      '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>',
    );
    sectPr.writeln('<w:cols w:space="720"/>');
    sectPr.writeln('<w:docGrid w:linePitch="312"/>');
    sectPr.writeln('</w:sectPr>');
    final bodyXml = body.toString();
    final sectPrXml = sectPr.toString();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" ' +
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" ' +
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" ' +
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" ' +
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">' +
        '<w:body>' +
        bodyXml +
        sectPrXml +
        '</w:body></w:document>';
  }

  // ─── 块级节点 ──────────────────────────────────────────────

  String _block(MdNode node, {required int ilvl}) {
    switch (node) {
      case Heading(:final level, :final children):
        return '<w:p><w:pPr><w:pStyle w:val="Heading' +
            level.toString() +
            '"/></w:pPr>' +
            _inlines(children) +
            '</w:p>';
      case Paragraph(:final children):
        return '<w:p>' + _inlines(children) + '</w:p>';
      case BulletList(:final items):
        return items.map((i) => _listItem(i, numId: 1, ilvl: ilvl)).join();
      case OrderedList(:final items):
        return items.map((i) => _listItem(i, numId: 2, ilvl: ilvl)).join();
      case ListItem():
        return '';
      case CodeBlock(:final language, :final code):
        return _codeBlock(language, code);
      case BlockQuote(:final children):
        final buf = StringBuffer();
        for (final c in children) {
          if (c is Paragraph) {
            buf.write(
              '<w:p><w:pPr><w:pStyle w:val="Quote"/></w:pPr>' +
                  _inlines(c.children) +
                  '</w:p>',
            );
          } else if (c is Heading) {
            buf.write(
              '<w:p><w:pPr><w:pStyle w:val="Quote"/></w:pPr>' +
                  _inlines(c.children) +
                  '</w:p>',
            );
          } else {
            buf.write(_block(c, ilvl: 0));
          }
        }
        return buf.toString();
      case Table(:final rows, :final alignments):
        return _table(rows, alignments);
      case ThematicBreak():
        return '<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="auto"/></w:pBdr></w:pPr></w:p>';
      case Image(:final src, :final alt):
        return _imageParagraph(src, alt);
      case TaskList(:final items):
        return items.map((i) => _taskItem(i)).join();
      case TaskListItem():
        return '';
      case Document():
        return '';
    }
  }

  String _imageParagraph(String src, String? alt) {
    final source = ImageSource.parse(src);
    if (source == null) {
      final altText = alt ?? '';
      return '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
              '<w:r><w:rPr><w:i/><w:color w:val="666666"/></w:rPr>'
              '<w:t xml:space="preserve">[图片: ' +
          _esc(altText) +
          '] (' +
          _esc(src) +
          ')</w:t>'
              '</w:r></w:p>';
    }
    final filename = mediaCollector.register(
      src,
      source.bytes,
      ext: source.ext,
    );
    final rId = relsCollector.register(
      target: 'media/' + filename,
      type: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
    );
    const cx = 200 * 12700;
    const cy = 150 * 12700;
    return '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r>'
            '<w:drawing>'
            '<wp:inline distT="0" distB="0" distL="0" distR="0">'
            '<wp:extent cx="' +
        cx.toString() +
        '" cy="' +
        cy.toString() +
        '"/>'
            '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
            '<wp:docPr id="0" name="Picture"/>'
            '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>'
            '<a:graphic>'
            '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
            '<pic:pic>'
            '<pic:nvPicPr><pic:cNvPr id="0" name=""/><pic:cNvPicPr/></pic:nvPicPr>'
            '<pic:blipFill>'
            '<a:blip r:embed="' +
        rId +
        '"/>'
            '<a:stretch><a:fillRect/></a:stretch>'
            '</pic:blipFill>'
            '<pic:spPr>'
            '<a:xfrm><a:off x="0" y="0"/><a:ext cx="' +
        cx.toString() +
        '" cy="' +
        cy.toString() +
        '"/></a:xfrm>'
            '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
            '</pic:spPr>'
            '</pic:pic>'
            '</a:graphicData>'
            '</a:graphic>'
            '</wp:inline>'
            '</w:drawing></w:r></w:p>';
  }

  String _taskItem(TaskListItem item) {
    final mark = item.checked ? '☑' : '☐';
    final buf = StringBuffer();
    for (final child in item.children) {
      if (child is Paragraph) {
        buf.write(
          '<w:p><w:pPr><w:pStyle w:val="ListParagraph"/><w:ind w:left="720"/></w:pPr>'
                  '<w:r><w:t xml:space="preserve">' +
              mark +
              ' </w:t></w:r>' +
              _inlines(child.children) +
              '</w:p>',
        );
      } else {
        buf.write(_block(child, ilvl: 0));
      }
    }
    return buf.toString();
  }

  String _listItem(ListItem item, {required int numId, required int ilvl}) {
    final buf = StringBuffer();
    for (final child in item.children) {
      if (child is BulletList) {
        buf.write(_block(child, ilvl: ilvl + 1));
      } else if (child is OrderedList) {
        buf.write(_block(child, ilvl: ilvl + 1));
      } else if (child is Paragraph) {
        buf.write(
          '<w:p><w:pPr><w:pStyle w:val="ListParagraph"/>'
                  '<w:numPr><w:ilvl w:val="' +
              ilvl.toString() +
              '"/><w:numId w:val="' +
              numId.toString() +
              '"/></w:numPr>'
                  '</w:pPr>' +
              _inlines(child.children) +
              '</w:p>',
        );
      } else {
        buf.write(_block(child, ilvl: ilvl));
      }
    }
    return buf.toString();
  }

  String _codeBlock(String? language, String code) {
    final lines = code.split('\n');
    final buf = StringBuffer();
    for (final line in lines) {
      if (line.isEmpty) continue;
      buf.write(
        '<w:p><w:pPr><w:pStyle w:val="SourceCode"/>'
        '<w:shd w:val="clear" w:color="auto" w:fill="F5F5F5"/>'
        '</w:pPr>',
      );
      for (final token in CodeTokenizer.tokenize(language ?? '', line)) {
        if (token.text.isEmpty) continue;
        final color = _tokenColor(token.kind);
        buf.write(
          '<w:r><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" '
          'w:eastAsia="Consolas" w:cs="Consolas"/>',
        );
        if (color != null) buf.write('<w:color w:val="$color"/>');
        buf.write(
          '</w:rPr><w:t xml:space="preserve">${_esc(token.text)}</w:t></w:r>',
        );
      }
      buf.write('</w:p>');
    }
    return buf.toString();
  }

  String? _tokenColor(CodeTokenKind kind) => switch (kind) {
    CodeTokenKind.plain => null,
    CodeTokenKind.keyword => 'CF222E',
    CodeTokenKind.string => '0A3069',
    CodeTokenKind.number => '0550AE',
    CodeTokenKind.comment => '6E7781',
    CodeTokenKind.function => '8250DF',
  };

  String _table(List<List<List<Inline>>> rows, List<int> alignments) {
    if (rows.isEmpty) return '';
    final cols = rows.first.length;
    final buf = StringBuffer();
    buf.writeln('<w:tbl>');
    buf.writeln('  <w:tblPr>');
    buf.writeln('    <w:tblW w:w="0" w:type="auto"/>');
    buf.writeln('    <w:tblBorders>');
    buf.writeln('      <w:top w:val="single" w:sz="4" w:color="auto"/>');
    buf.writeln('      <w:left w:val="single" w:sz="4" w:color="auto"/>');
    buf.writeln('      <w:bottom w:val="single" w:sz="4" w:color="auto"/>');
    buf.writeln('      <w:right w:val="single" w:sz="4" w:color="auto"/>');
    buf.writeln('      <w:insideH w:val="single" w:sz="4" w:color="auto"/>');
    buf.writeln('      <w:insideV w:val="single" w:sz="4" w:color="auto"/>');
    buf.writeln('    </w:tblBorders>');
    buf.writeln('  </w:tblPr>');
    buf.writeln('  <w:tblGrid>');
    final colWidth = (9000 ~/ cols).toString();
    for (var c = 0; c < cols; c++) {
      buf.writeln('    <w:gridCol w:w="' + colWidth + '"/>');
    }
    buf.writeln('  </w:tblGrid>');
    for (var r = 0; r < rows.length; r++) {
      buf.writeln('  <w:tr>');
      for (var c = 0; c < rows[r].length; c++) {
        final isHeader = r == 0;
        final align = c < alignments.length ? alignments[c] : -1;
        final jc = align == 0 ? 'center' : (align == 1 ? 'right' : 'left');
        final pStyle = isHeader ? '<w:pStyle w:val="Heading6"/>' : '';
        buf.writeln(
          '    <w:tc>'
                  '<w:tcPr><w:tcW w:w="' +
              colWidth +
              '" w:type="dxa"/><w:jc w:val="' +
              jc +
              '"/></w:tcPr>'
                  '<w:p><w:pPr><w:jc w:val="' +
              jc +
              '"/>' +
              pStyle +
              '</w:pPr>' +
              _inlines(rows[r][c]) +
              '</w:p></w:tc>',
        );
      }
      buf.writeln('  </w:tr>');
    }
    buf.writeln('</w:tbl>');
    buf.writeln('<w:p/>');
    return buf.toString();
  }

  // ─── 行内节点(rPr 累加版) ────────────────────────────────

  String _inlines(List<Inline> inlines) {
    final buf = StringBuffer();
    for (final i in inlines) {
      buf.write(_emitInline(i, const _Rpr()));
    }
    return buf.toString();
  }

  String _emitInline(Inline node, _Rpr rpr) {
    switch (node) {
      case Text(:final text):
        return _wrapRun(_esc(text), rpr);
      case Emphasis(:final children):
        return _emitChildren(children, rpr.withItalic());
      case Strong(:final children):
        return _emitChildren(children, rpr.withBold());
      case Code(:final code):
        return _wrapRun(_esc(code), rpr.withMono().withShading());
      case Link(:final href, :final children):
        final rId = relsCollector.register(
          target: href,
          type: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink',
          targetMode: 'External',
        );
        final inner = _emitChildren(children, rpr.withHyperlink());
        return '<w:hyperlink r:id="' + rId + '">' + inner + '</w:hyperlink>';
      case HardBreak():
        final rprXml = rpr.toXml(monoFont: options.monoFont);
        if (rprXml.isEmpty) {
          return '<w:r><w:br/></w:r>';
        }
        return '<w:r><w:rPr>' + rprXml + '</w:rPr><w:br/></w:r>';
      case SoftBreak():
        return '';
      case Math(:final tex):
        return _wrapRun(_esc(tex), rpr.withMono());
      case ImageInline(:final alt):
        return _wrapRun('[' + _esc(alt ?? '') + ']', rpr);
    }
  }

  String _emitChildren(List<Inline> children, _Rpr rpr) {
    final buf = StringBuffer();
    for (final c in children) {
      buf.write(_emitInline(c, rpr));
    }
    return buf.toString();
  }

  String _wrapRun(String escapedText, _Rpr rpr) {
    final rprXml = rpr.toXml(monoFont: options.monoFont);
    if (rprXml.isEmpty) {
      return '<w:r><w:t xml:space="preserve">' + escapedText + '</w:t></w:r>';
    }
    return '<w:r><w:rPr>' +
        rprXml +
        '</w:rPr><w:t xml:space="preserve">' +
        escapedText +
        '</w:t></w:r>';
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// 不可变 run 属性集合,递归构造 inline 时累加。
///
/// 使用方式:从空 _Rpr() 开始,经 withItalic / withBold / withMono /
/// withShading / withHyperlink 累加,最终 toXml 输出 OOXML 片段。
/// 空 rPr 输出空串,便于 _wrapRun 优化省略 rPr 标签。
class _Rpr {
  final bool italic;
  final bool bold;
  final bool mono;
  final bool shading;
  final bool hyperlink;

  const _Rpr({
    this.italic = false,
    this.bold = false,
    this.mono = false,
    this.shading = false,
    this.hyperlink = false,
  });

  _Rpr withItalic() => _Rpr(
    italic: true,
    bold: bold,
    mono: mono,
    shading: shading,
    hyperlink: hyperlink,
  );
  _Rpr withBold() => _Rpr(
    italic: italic,
    bold: true,
    mono: mono,
    shading: shading,
    hyperlink: hyperlink,
  );
  _Rpr withMono() => _Rpr(
    italic: italic,
    bold: bold,
    mono: true,
    shading: shading,
    hyperlink: hyperlink,
  );
  _Rpr withShading() => _Rpr(
    italic: italic,
    bold: bold,
    mono: mono,
    shading: true,
    hyperlink: hyperlink,
  );
  _Rpr withHyperlink() => _Rpr(
    italic: italic,
    bold: bold,
    mono: mono,
    shading: shading,
    hyperlink: true,
  );

  bool get isEmpty => !(italic || bold || mono || shading || hyperlink);

  String toXml({required String monoFont}) {
    if (isEmpty) return '';
    final buf = StringBuffer();
    if (hyperlink) buf.write('<w:rStyle w:val="Hyperlink"/>');
    if (mono)
      buf.write(
        '<w:rFonts w:ascii="' +
            monoFont +
            '" w:hAnsi="' +
            monoFont +
            '" w:cs="' +
            monoFont +
            '"/>',
      );
    if (bold) buf.write('<w:b/>');
    if (italic) buf.write('<w:i/>');
    if (shading)
      buf.write('<w:shd w:val="clear" w:color="auto" w:fill="F0F0F0"/>');
    return buf.toString();
  }
}
