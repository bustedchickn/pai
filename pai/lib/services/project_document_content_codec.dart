import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;

class ProjectDocumentContentCodec {
  static quill.Document decode(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) {
      return quill.Document();
    }

    final deltaJson = _tryParseDeltaJson(trimmed);
    if (deltaJson != null) {
      return quill.Document.fromJson(deltaJson);
    }

    return quill.Document.fromJson(_markdownToDeltaJson(rawContent));
  }

  static String encode(quill.Document document) {
    return jsonEncode(document.toDelta().toJson());
  }

  static String toPlainText(String rawContent) {
    final plainText = decode(rawContent).toPlainText();
    return plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String previewText(String rawContent, {int maxLength = 160}) {
    final plainText = toPlainText(rawContent);
    if (plainText.length <= maxLength) {
      return plainText;
    }
    return '${plainText.substring(0, maxLength - 1).trimRight()}...';
  }

  static String toMarkdown(quill.Document document) {
    final ops = document.toDelta().toJson();
    final lines = <_MarkdownLine>[];
    var currentLine = _MarkdownLine();

    void commitLine(Map<String, dynamic> attributes) {
      lines.add(
        _MarkdownLine(
          text: currentLine.text.toString(),
          lineAttributes: attributes,
        ),
      );
      currentLine = _MarkdownLine();
    }

    for (final rawOp in ops.whereType<Map<dynamic, dynamic>>()) {
      final op = Map<String, dynamic>.from(rawOp);
      final insert = op['insert'];
      if (insert is! String) {
        continue;
      }

      final attributes = _attributeMap(op['attributes']);
      final parts = insert.split('\n');
      for (var index = 0; index < parts.length; index++) {
        final part = parts[index];
        if (part.isNotEmpty) {
          currentLine.text.write(_inlineOpsToMarkdown(part, attributes));
        }

        if (index < parts.length - 1) {
          commitLine(attributes);
        }
      }
    }

    final outputLines = <String>[];
    var inCodeBlock = false;
    var orderedIndex = 0;

    for (final line in lines) {
      final attrs = line.lineAttributes;
      final isCodeBlock = attrs['code-block'] == true;
      if (isCodeBlock && !inCodeBlock) {
        outputLines.add('```');
        inCodeBlock = true;
      } else if (!isCodeBlock && inCodeBlock) {
        outputLines.add('```');
        inCodeBlock = false;
      }

      if (isCodeBlock) {
        outputLines.add(line.text.toString());
        orderedIndex = 0;
        continue;
      }

      final listKind = attrs['list'];
      final prefix = switch (listKind) {
        'bullet' => '- ',
        'ordered' => '${++orderedIndex}. ',
        _ => () {
            orderedIndex = 0;
            final headerLevel = attrs['header'];
            if (headerLevel == 1) {
              return '# ';
            }
            if (headerLevel == 2) {
              return '## ';
            }
            if (headerLevel == 3) {
              return '### ';
            }
            if (attrs['blockquote'] == true) {
              return '> ';
            }
            return '';
          }(),
      };

      if (line.text.toString().trim().isEmpty && prefix.isEmpty) {
        outputLines.add('');
      } else {
        outputLines.add('$prefix${line.text}');
      }
    }

    if (inCodeBlock) {
      outputLines.add('```');
    }

    while (outputLines.isNotEmpty && outputLines.last.trim().isEmpty) {
      outputLines.removeLast();
    }

    return outputLines.join('\n');
  }

  static List<Map<String, dynamic>>? _tryParseDeltaJson(String rawContent) {
    try {
      final decoded = jsonDecode(rawContent);
      if (decoded is! List) {
        return null;
      }

      final ops = <Map<String, dynamic>>[];
      for (final entry in decoded) {
        if (entry is! Map || !entry.containsKey('insert')) {
          return null;
        }
        ops.add(Map<String, dynamic>.from(entry));
      }
      return ops;
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _markdownToDeltaJson(String markdown) {
    final normalized = markdown.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    final ops = <Map<String, dynamic>>[];
    var inCodeBlock = false;

    for (final rawLine in lines) {
      final line = rawLine.replaceAll('\r', '');
      final trimmed = line.trimRight();

      if (trimmed.trim().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }

      if (inCodeBlock) {
        _appendText(ops, trimmed);
        _appendNewline(ops, const {'code-block': true});
        continue;
      }

      if (trimmed.trim().isEmpty) {
        _appendNewline(ops, const {});
        continue;
      }

      final headingMatch = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
      if (headingMatch != null) {
        _appendInlineMarkdown(ops, headingMatch.group(2)!);
        _appendNewline(
          ops,
          <String, dynamic>{'header': headingMatch.group(1)!.length},
        );
        continue;
      }

      final bulletMatch = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        _appendInlineMarkdown(ops, bulletMatch.group(1)!);
        _appendNewline(ops, const {'list': 'bullet'});
        continue;
      }

      final orderedMatch = RegExp(r'^\d+\.\s+(.*)$').firstMatch(trimmed);
      if (orderedMatch != null) {
        _appendInlineMarkdown(ops, orderedMatch.group(1)!);
        _appendNewline(ops, const {'list': 'ordered'});
        continue;
      }

      final quoteMatch = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
      if (quoteMatch != null) {
        _appendInlineMarkdown(ops, quoteMatch.group(1)!);
        _appendNewline(ops, const {'blockquote': true});
        continue;
      }

      _appendInlineMarkdown(ops, trimmed);
      _appendNewline(ops, const {});
    }

    if (ops.isEmpty || ops.last['insert'] != '\n') {
      ops.add(<String, dynamic>{'insert': '\n'});
    }

    return ops;
  }

  static void _appendInlineMarkdown(
    List<Map<String, dynamic>> ops,
    String source, {
    Map<String, dynamic> activeAttributes = const {},
  }) {
    if (source.isEmpty) {
      return;
    }

    var cursor = 0;
    final plainBuffer = StringBuffer();

    void flushPlain() {
      if (plainBuffer.isEmpty) {
        return;
      }

      _appendText(ops, plainBuffer.toString(), activeAttributes);
      plainBuffer.clear();
    }

    while (cursor < source.length) {
      final boldItalicEnd = source.startsWith('***', cursor)
          ? source.indexOf('***', cursor + 3)
          : -1;
      if (boldItalicEnd > cursor) {
        flushPlain();
        _appendInlineMarkdown(
          ops,
          source.substring(cursor + 3, boldItalicEnd),
          activeAttributes: {
            ...activeAttributes,
            'bold': true,
            'italic': true,
          },
        );
        cursor = boldItalicEnd + 3;
        continue;
      }

      final boldEnd = source.startsWith('**', cursor)
          ? source.indexOf('**', cursor + 2)
          : -1;
      if (boldEnd > cursor) {
        flushPlain();
        _appendInlineMarkdown(
          ops,
          source.substring(cursor + 2, boldEnd),
          activeAttributes: {...activeAttributes, 'bold': true},
        );
        cursor = boldEnd + 2;
        continue;
      }

      final underlineEnd = source.startsWith('__', cursor)
          ? source.indexOf('__', cursor + 2)
          : -1;
      if (underlineEnd > cursor) {
        flushPlain();
        _appendInlineMarkdown(
          ops,
          source.substring(cursor + 2, underlineEnd),
          activeAttributes: {...activeAttributes, 'underline': true},
        );
        cursor = underlineEnd + 2;
        continue;
      }

      final italicEnd = source.startsWith('*', cursor) &&
              !source.startsWith('**', cursor)
          ? source.indexOf('*', cursor + 1)
          : -1;
      if (italicEnd > cursor) {
        flushPlain();
        _appendInlineMarkdown(
          ops,
          source.substring(cursor + 1, italicEnd),
          activeAttributes: {...activeAttributes, 'italic': true},
        );
        cursor = italicEnd + 1;
        continue;
      }

      final linkMatch = RegExp(
        r'^\[([^\]]+)\]\(([^)]+)\)',
      ).matchAsPrefix(source.substring(cursor));
      if (linkMatch != null) {
        flushPlain();
        _appendInlineMarkdown(
          ops,
          linkMatch.group(1)!,
          activeAttributes: {
            ...activeAttributes,
            'link': linkMatch.group(2)!,
          },
        );
        cursor += linkMatch.group(0)!.length;
        continue;
      }

      plainBuffer.write(source[cursor]);
      cursor++;
    }

    flushPlain();
  }

  static void _appendText(
    List<Map<String, dynamic>> ops,
    String text, [
    Map<String, dynamic> attributes = const {},
  ]) {
    if (text.isEmpty) {
      return;
    }

    final op = <String, dynamic>{'insert': text};
    if (attributes.isNotEmpty) {
      op['attributes'] = attributes;
    }
    ops.add(op);
  }

  static void _appendNewline(
    List<Map<String, dynamic>> ops,
    Map<String, dynamic> attributes,
  ) {
    final op = <String, dynamic>{'insert': '\n'};
    if (attributes.isNotEmpty) {
      op['attributes'] = attributes;
    }
    ops.add(op);
  }

  static Map<String, dynamic> _attributeMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  static String _inlineOpsToMarkdown(
    String text,
    Map<String, dynamic> attributes,
  ) {
    var value = text;
    if (attributes['underline'] == true) {
      value = '<u>$value</u>';
    }
    if (attributes['bold'] == true && attributes['italic'] == true) {
      value = '***$value***';
    } else if (attributes['bold'] == true) {
      value = '**$value**';
    } else if (attributes['italic'] == true) {
      value = '*$value*';
    }
    if (attributes['link'] is String) {
      value = '[$value](${attributes['link']})';
    }
    return value;
  }
}

class _MarkdownLine {
  _MarkdownLine({String text = '', Map<String, dynamic>? lineAttributes})
    : text = StringBuffer(text),
      lineAttributes = lineAttributes ?? const <String, dynamic>{};

  final StringBuffer text;
  final Map<String, dynamic> lineAttributes;
}
