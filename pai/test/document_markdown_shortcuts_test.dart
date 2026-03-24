import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:pai/services/document_markdown_shortcuts.dart';

void main() {
  group('markdown list shortcuts', () {
    test('dash-space at empty line start becomes bullet list and undoes cleanly', () {
      final controller = _controllerWithText('-');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 1),
        quill.ChangeSource.local,
      );

      final pending = applyMarkdownListShortcut(
        controller: controller,
        index: 1,
        len: 0,
        data: ' ',
      );

      expect(pending, isNotNull);
      expect(controller.document.toPlainText(), '\n');
      expect(
        controller.document.collectStyle(0, 0).attributes[quill.Attribute.list.key]?.value,
        'bullet',
      );

      controller.document.undo();
      expect(controller.document.toPlainText(), '-\n');
    });

    test('one-dot-space at empty line start becomes ordered list', () {
      final controller = _controllerWithText('1.');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 2),
        quill.ChangeSource.local,
      );

      final pending = applyMarkdownListShortcut(
        controller: controller,
        index: 2,
        len: 0,
        data: ' ',
      );

      expect(pending, isNotNull);
      expect(controller.document.toPlainText(), '\n');
      expect(
        controller.document.collectStyle(0, 0).attributes[quill.Attribute.list.key]?.value,
        'ordered',
      );
    });

    test('does not trigger in the middle of text', () {
      final controller = _controllerWithText('hello-');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 6),
        quill.ChangeSource.local,
      );

      final pending = applyMarkdownListShortcut(
        controller: controller,
        index: 6,
        len: 0,
        data: ' ',
      );

      expect(pending, isNull);
      controller.replaceText(
        6,
        0,
        ' ',
        const TextSelection.collapsed(offset: 7),
      );
      expect(controller.document.toPlainText(), 'hello- \n');
    });

    test('immediate backspace restores the literal bullet shortcut', () {
      final controller = _controllerWithText('-');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 1),
        quill.ChangeSource.local,
      );

      final pending = applyMarkdownListShortcut(
        controller: controller,
        index: 1,
        len: 0,
        data: ' ',
      );

      expect(pending, isNotNull);
      controller.updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );

      final reverted = revertMarkdownListShortcut(
        controller: controller,
        pending: pending!,
      );

      expect(reverted, isTrue);
      expect(controller.document.toPlainText(), '- \n');
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
    });

    test('backspace key detection only handles actual backspace keydown', () {
      expect(
        isListShortcutBackspace(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.backspace,
            logicalKey: LogicalKeyboardKey.backspace,
            timeStamp: Duration.zero,
          ),
        ),
        isTrue,
      );
      expect(
        isListShortcutBackspace(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.enter,
            logicalKey: LogicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        ),
        isFalse,
      );
    });
  });
}

quill.QuillController _controllerWithText(String text) {
  final document = quill.Document.fromJson([
    {'insert': '$text\n'},
  ]);
  return quill.QuillController(
    document: document,
    selection: const TextSelection.collapsed(offset: 0),
  );
}
