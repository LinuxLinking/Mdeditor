enum CodeTokenKind { plain, keyword, string, number, comment, function }

class CodeToken {
  const CodeToken(this.text, this.kind);

  final String text;
  final CodeTokenKind kind;
}

class CodeTokenizer {
  static const _supportedLanguages = <String>{
    'python',
    'javascript',
    'typescript',
    'java',
    'sql',
    'bash',
    'json',
    'html',
    'xml',
    'css',
  };

  static const _keywords = <String, Set<String>>{
    'python': {
      'and',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'class',
      'continue',
      'def',
      'del',
      'elif',
      'else',
      'except',
      'False',
      'finally',
      'for',
      'from',
      'global',
      'if',
      'import',
      'in',
      'is',
      'lambda',
      'None',
      'nonlocal',
      'not',
      'or',
      'pass',
      'raise',
      'return',
      'True',
      'try',
      'while',
      'with',
      'yield',
    },
    'javascript': {
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'delete',
      'do',
      'else',
      'export',
      'extends',
      'false',
      'finally',
      'for',
      'from',
      'function',
      'if',
      'import',
      'in',
      'instanceof',
      'let',
      'new',
      'null',
      'return',
      'static',
      'super',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'typeof',
      'var',
      'void',
      'while',
      'yield',
    },
    'typescript': {
      'as',
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'delete',
      'do',
      'else',
      'export',
      'extends',
      'false',
      'finally',
      'for',
      'from',
      'function',
      'if',
      'implements',
      'import',
      'in',
      'instanceof',
      'interface',
      'let',
      'new',
      'null',
      'private',
      'public',
      'readonly',
      'return',
      'static',
      'super',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'type',
      'typeof',
      'var',
      'void',
      'while',
    },
    'java': {
      'abstract',
      'boolean',
      'break',
      'byte',
      'case',
      'catch',
      'char',
      'class',
      'const',
      'continue',
      'default',
      'do',
      'double',
      'else',
      'enum',
      'extends',
      'final',
      'finally',
      'float',
      'for',
      'if',
      'implements',
      'import',
      'instanceof',
      'int',
      'interface',
      'long',
      'native',
      'new',
      'package',
      'private',
      'protected',
      'public',
      'return',
      'short',
      'static',
      'strictfp',
      'super',
      'switch',
      'synchronized',
      'this',
      'throw',
      'throws',
      'transient',
      'try',
      'void',
      'volatile',
      'while',
    },
    'sql': {
      'alter',
      'and',
      'as',
      'by',
      'case',
      'create',
      'delete',
      'distinct',
      'drop',
      'else',
      'end',
      'from',
      'group',
      'having',
      'in',
      'insert',
      'into',
      'is',
      'join',
      'left',
      'limit',
      'not',
      'null',
      'on',
      'or',
      'order',
      'select',
      'set',
      'table',
      'then',
      'true',
      'union',
      'update',
      'values',
      'when',
      'where',
    },
    'bash': {
      'case',
      'do',
      'done',
      'elif',
      'else',
      'esac',
      'fi',
      'for',
      'function',
      'if',
      'in',
      'select',
      'then',
      'time',
      'until',
      'while',
    },
    'json': {'false', 'null', 'true'},
  };

  static List<CodeToken> tokenize(String language, String line) {
    final lang = _normalize(language);
    if (!_supportedLanguages.contains(lang)) {
      return [CodeToken(line, CodeTokenKind.plain)];
    }
    final keywords = _keywords[lang];
    final tokens = <CodeToken>[];
    var i = 0;
    while (i < line.length) {
      final start = i;
      final c = line[i];

      if (_isCommentStart(lang, line, i)) {
        tokens.add(CodeToken(line.substring(i), CodeTokenKind.comment));
        break;
      }
      if (c == '\'' || c == '"' || (lang == 'python' && c == '`')) {
        final quote = c;
        i++;
        while (i < line.length) {
          if (line[i] == r'\' && i + 1 < line.length) {
            i += 2;
          } else if (line[i++] == quote) {
            break;
          }
        }
        tokens.add(CodeToken(line.substring(start, i), CodeTokenKind.string));
        continue;
      }
      if (_isDigit(c)) {
        i++;
        while (i < line.length && _isNumberChar(line[i])) {
          i++;
        }
        tokens.add(CodeToken(line.substring(start, i), CodeTokenKind.number));
        continue;
      }
      if (_isIdentifierStart(c)) {
        i++;
        while (i < line.length && _isIdentifierPart(line[i])) {
          i++;
        }
        final word = line.substring(start, i);
        final kind = keywords?.contains(word) == true
            ? CodeTokenKind.keyword
            : (lang == 'html' || lang == 'xml') &&
                  (start > 0 && line[start - 1] == '<' ||
                      start > 1 && line.substring(start - 2, start) == '</')
            ? CodeTokenKind.keyword
            : lang == 'css' && _nextNonSpace(line, i) == ':'
            ? CodeTokenKind.keyword
            : _nextNonSpace(line, i) == '(' && _isCodeLanguage(lang)
            ? CodeTokenKind.function
            : CodeTokenKind.plain;
        tokens.add(CodeToken(word, kind));
        continue;
      }
      i++;
      tokens.add(CodeToken(line.substring(start, i), CodeTokenKind.plain));
    }
    return tokens;
  }

  static String _normalize(String language) {
    final value = language.toLowerCase();
    if (value == 'js' || value == 'jsx' || value == 'mjs') return 'javascript';
    if (value == 'ts' || value == 'tsx') return 'typescript';
    if (value == 'py') return 'python';
    if (value == 'sh' || value == 'shell' || value == 'zsh') return 'bash';
    return value;
  }

  static bool _isCommentStart(String lang, String line, int i) {
    if ((lang == 'python' || lang == 'bash') && line[i] == '#') return true;
    if (_isCodeLanguage(lang) && line.startsWith('//', i)) return true;
    if (_isCodeLanguage(lang) && line.startsWith('/*', i)) return true;
    return lang == 'sql' && line.startsWith('--', i);
  }

  static bool _isCodeLanguage(String lang) =>
      lang == 'javascript' ||
      lang == 'typescript' ||
      lang == 'java' ||
      lang == 'python' ||
      lang == 'bash';

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  static bool _isIdentifierStart(String c) =>
      (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) ||
      (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122) ||
      c == '_' ||
      c == r'$';
  static bool _isIdentifierPart(String c) =>
      _isIdentifierStart(c) || _isDigit(c);
  static bool _isNumberChar(String c) => _isDigit(c) || c == '.';

  static String? _nextNonSpace(String line, int start) {
    var i = start;
    while (i < line.length && line[i].trim().isEmpty) {
      i++;
    }
    return i < line.length ? line[i] : null;
  }
}
