package com.mdeditor.app

internal object ExportCodeHighlighter {
    fun embedRuntime(document: String, runtime: String): String {
        if (runtime.isBlank()) return document
        val scripts = "<script>$runtime</script><script>" +
            "document.querySelectorAll('pre code[class*=language-]').forEach(function(code){" +
            "try{var language=(code.className.match(/language-([\\w+-]+)/)||[])[1];" +
            "if(language&&window.hljs.getLanguage(language)){code.innerHTML=window.hljs.highlight(code.textContent,{language:language,ignoreIllegals:true}).value;" +
            "code.classList.add('hljs')}}catch(e){console.error('Code highlighting failed',e)}})</script>"
        return document.replace("</body>", "$scripts</body>")
    }
}
