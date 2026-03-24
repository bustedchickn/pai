import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';

class PendingListShortcutRevert {
  const PendingListShortcutRevert({
    required this.lineStart,
    required this.shortcutText,
    required this.listValue,
  });

  final int lineStart;
  final String shortcutText;
  final String listValue;
}

PendingListShortcutRevert? applyMarkdownListShortcut({
  required quill.QuillController controller,
  required int index,
  required int len,
  required Object? data,
}) {
  if (data != ' ' || len != 0) {
    return null;
  }

  final selection = controller.selection;
  if (!selection.isValid || !selection.isCollapsed || selection.baseOffset != index) {
    return null;
  }

  final plainText = controller.document.toPlainText();
  final lineStart = _lineStartForIndex(plainText, index);
  final lineEnd = _lineEndForIndex(plainText, lineStart);
  if (lineEnd != index) {
    return null;
  }

  final linePrefix = plainText.substring(lineStart, index);
  if (linePrefix == '-') {
    _convertLinePrefixToList(
      controller: controller,
      lineStart: lineStart,
      prefixLength: 1,
      listAttribute: quill.Attribute.ul,
    );
    return PendingListShortcutRevert(
      lineStart: lineStart,
      shortcutText: '- ',
      listValue: 'bullet',
    );
  }

  if (linePrefix == '1.') {
    _convertLinePrefixToList(
      controller: controller,
      lineStart: lineStart,
      prefixLength: 2,
      listAttribute: quill.Attribute.ol,
    );
    return PendingListShortcutRevert(
      lineStart: lineStart,
      shortcutText: '1. ',
      listValue: 'ordered',
    );
  }

  return null;
}

bool revertMarkdownListShortcut({
  required quill.QuillController controller,
  required PendingListShortcutRevert pending,
}) {
  final selection = controller.selection;
  if (!selection.isValid ||
      !selection.isCollapsed ||
      selection.baseOffset != pending.lineStart) {
    return false;
  }

  final plainText = controller.document.toPlainText();
  if (pending.lineStart < 0 || pending.lineStart >= plainText.length) {
    return false;
  }

  final lineEnd = _lineEndForIndex(plainText, pending.lineStart);
  final isEmptyLine = lineEnd == pending.lineStart && plainText[pending.lineStart] == '\n';
  if (!isEmptyLine) {
    return false;
  }

  final listAttribute =
      controller.document.collectStyle(pending.lineStart, 0).attributes[quill.Attribute.list.key];
  if (listAttribute?.value != pending.listValue) {
    return false;
  }

  final delta = Delta()
    ..retain(pending.lineStart)
    ..insert(pending.shortcutText)
    ..retain(1, <String, dynamic>{quill.Attribute.list.key: null});
  controller.compose(
    delta,
    TextSelection.collapsed(offset: pending.lineStart + pending.shortcutText.length),
    quill.ChangeSource.local,
  );
  controller.updateSelection(
    TextSelection.collapsed(offset: pending.lineStart + pending.shortcutText.length),
    quill.ChangeSource.local,
  );
  return true;
}

bool isListShortcutBackspace(
  KeyEvent event,
) => event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace;

void _convertLinePrefixToList({
  required quill.QuillController controller,
  required int lineStart,
  required int prefixLength,
  required quill.Attribute<dynamic> listAttribute,
}) {
  final delta = Delta()
    ..retain(lineStart)
    ..delete(prefixLength)
    ..retain(1, <String, dynamic>{listAttribute.key: listAttribute.value});
  controller.compose(
    delta,
    TextSelection.collapsed(offset: lineStart),
    quill.ChangeSource.local,
  );
  controller.updateSelection(
    TextSelection.collapsed(offset: lineStart),
    quill.ChangeSource.local,
  );
}

int _lineStartForIndex(String plainText, int index) {
  if (index <= 0) {
    return 0;
  }

  return plainText.lastIndexOf('\n', index - 1) + 1;
}

int _lineEndForIndex(String plainText, int lineStart) {
  final nextBreak = plainText.indexOf('\n', lineStart);
  return nextBreak < 0 ? plainText.length : nextBreak;
}
