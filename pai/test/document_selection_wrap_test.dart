import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:pai/services/document_selection_wrap.dart';

void main() {
  group('applySelectionWrapEdit', () {
    test('wraps selected text with parentheses', () {
      final controller = _controllerWithText('hello');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        quill.ChangeSource.local,
      );

      final handled = applySelectionWrapEdit(
        controller: controller,
        index: 0,
        len: 5,
        data: '(',
        replaceText: controller.replaceText,
      );

      expect(handled, isTrue);
      expect(controller.document.toPlainText(), '(hello)\n');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 6),
      );
    });

    test('wraps selected text with double quotes', () {
      final controller = _controllerWithText('hello');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        quill.ChangeSource.local,
      );

      final handled = applySelectionWrapEdit(
        controller: controller,
        index: 0,
        len: 5,
        data: '"',
        replaceText: controller.replaceText,
      );

      expect(handled, isTrue);
      expect(controller.document.toPlainText(), '"hello"\n');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 6),
      );
    });

    test('ignores surrounding spaces when wrapping a selection', () {
      final controller = _controllerWithText(' hello ');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 7),
        quill.ChangeSource.local,
      );

      final handled = applySelectionWrapEdit(
        controller: controller,
        index: 0,
        len: 7,
        data: '(',
        replaceText: controller.replaceText,
      );

      expect(handled, isTrue);
      expect(controller.document.toPlainText(), ' (hello) \n');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 7),
      );
    });

    test('ignores surrounding line breaks when wrapping a selection', () {
      final controller = _controllerWithText('\nhello\n');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 7),
        quill.ChangeSource.local,
      );

      final handled = applySelectionWrapEdit(
        controller: controller,
        index: 0,
        len: 7,
        data: '[',
        replaceText: controller.replaceText,
      );

      expect(handled, isTrue);
      expect(controller.document.toPlainText(), '\n[hello]\n\n');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 7),
      );
    });

    test('does nothing when there is no selection', () {
      final controller = _controllerWithText('hello');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 5),
        quill.ChangeSource.local,
      );

      final handled = applySelectionWrapEdit(
        controller: controller,
        index: 5,
        len: 0,
        data: '(',
        replaceText: controller.replaceText,
      );

      expect(handled, isFalse);
      controller.replaceText(
        5,
        0,
        '(',
        const TextSelection.collapsed(offset: 6),
      );
      expect(controller.document.toPlainText(), 'hello(\n');
    });

    test('preserves inline formatting inside the wrapped selection', () {
      final controller = _controllerWithText('hello');
      controller.formatText(0, 5, quill.Attribute.bold);
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        quill.ChangeSource.local,
      );

      final handled = applySelectionWrapEdit(
        controller: controller,
        index: 0,
        len: 5,
        data: '(',
        replaceText: controller.replaceText,
      );

      expect(handled, isTrue);
      expect(
        controller.document.collectStyle(1, 5).attributes,
        contains(quill.Attribute.bold.key),
      );
    });
  });
}

quill.QuillController _controllerWithText(String text) {
  final document = quill.Document()..insert(0, text);
  return quill.QuillController(
    document: document,
    selection: const TextSelection.collapsed(offset: 0),
  );
}
