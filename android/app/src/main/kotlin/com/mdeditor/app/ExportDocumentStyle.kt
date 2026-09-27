package com.mdeditor.app

internal object ExportDocumentStyle {
    fun css(themeVariables: Map<String, String>): String {
        val bg = themeVariables["--editor-bg"] ?: "#ffffff"
        val fg = themeVariables["--editor-fg"] ?: "#24292f"
        val code = themeVariables["--editor-code-bg"] ?: "#f6f8fa"
        val headings = (1..6).joinToString("") { level ->
            val size = themeVariables["--h$level-size"] ?: "${2.2 - level * 0.22}em"
            val color = themeVariables["--h$level-color"] ?: fg
            val space = themeVariables["--h$level-space"] ?: "16px"
            "h$level{font-size:$size;color:$color;margin-top:$space}"
        }
        val syntax = ".hljs-keyword,.hljs-selector-tag,.hljs-literal{color:#cf222e;font-weight:600}" +
            ".hljs-string,.hljs-attr{color:#0a3069}.hljs-number,.hljs-literal{color:#0550ae}" +
            ".hljs-comment{color:#6e7781;font-style:italic}.hljs-title,.hljs-function{color:#8250df}" +
            ".hljs-name,.hljs-type{color:#953800}.hljs-built_in{color:#0550ae}"
        return "*{box-sizing:border-box}" +
            "body{background:$bg;color:$fg;font:16px/1.65 sans-serif;max-width:900px;margin:24px auto;padding:0 20px}" +
            headings + syntax +
            "table{border-collapse:collapse;table-layout:fixed;width:100%;margin:1em 0}" +
            "th,td{border:1px solid #d0d7de;padding:6px 10px;text-align:left;vertical-align:top;overflow-wrap:anywhere;word-break:normal}" +
            "th{background:#f6f8fa;font-weight:600}" +
            "th p,td p{margin:0}" +
            "pre{background:$code;padding:16px;white-space:pre-wrap;overflow-wrap:anywhere}" +
            "pre code{white-space:pre-wrap;overflow-wrap:anywhere;background:transparent;padding:0}" +
            "code{font-family:Consolas,monospace}" +
            "img,svg,video,audio{max-width:100%}" +
            "blockquote{border-left:3px solid #8b949e;padding-left:12px}" +
            "blockquote blockquote,li>ul,li>ol{border-left:1px solid #8b949e;margin-left:4px;padding-left:16px}" +
            ".media-card{border:1px solid #8b949e;border-radius:8px;padding:12px;margin:16px 0}" +
            ".native-image{display:flex;margin:16px 0}.native-image.align-left{justify-content:flex-start}" +
            ".native-image.align-center{justify-content:center}.native-image.align-right{justify-content:flex-end}" +
            ".native-image img{width:min(var(--image-width,100%),100%);height:auto}" +
            "@page{size:A4;margin:18mm}" +
            "@media print{*{-webkit-print-color-adjust:exact;print-color-adjust:exact}" +
            "body{margin:0;padding:0;max-width:none}" +
            "thead{display:table-header-group}tfoot{display:table-footer-group}" +
            "tr{break-inside:avoid;page-break-inside:avoid}" +
            "h1,h2,h3,h4,h5,h6{break-after:avoid-page}" +
            "img,figure{break-inside:avoid}" +
            "pre{break-inside:auto}table{break-inside:auto}}"
    }
}
