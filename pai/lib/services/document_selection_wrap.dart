import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';

const Map<String, String> kSelectionWrapPairs = {
  '"': '"',
  "'": "'",
  '(': ')',
  '[': ']',
  '{': '}',
  '`': '`',
  '<': '>',
};

bool applySelectionWrapEdit({
  required quill.QuillController controller,
  required int index,
  required int len,
  required Object? data,
  required void Function(
    int index,
    int len,
    Object? data,
    TextSelection? selection,
  )
  replaceText,
}) {
  final openingCharacter = data is String && data.length == 1 ? data : null;
  final closingCharacter = openingCharacter == null
      ? null
      : kSelectionWrapPairs[openingCharacter];
  final selection = controller.selection;
  if (closingCharacter == null ||
      !selection.isValid ||
      selection.isCollapsed ||
      len <= 0) {
    return false;
  }

  final trimmedSelection = _trimmedSelectionRange(
    plainText: controller.document.toPlainText(),
    index: index,
    len: len,
  );
  if (trimmedSelection == null) {
    return false;
  }

  final documentDelta = controller.document.toDelta();
  final leadingContent = trimmedSelection.leadingLength == 0
      ? Delta()
      : documentDelta.slice(index, trimmedSelection.start);
  final selectedContent = documentDelta.slice(
    trimmedSelection.start,
    trimmedSelection.end,
  );
  final trailingContent = trimmedSelection.trailingLength == 0
      ? Delta()
      : documentDelta.slice(trimmedSelection.end, index + len);
  if (selectedContent.isEmpty) {
    return false;
  }

  final wrapperAttributes = _wrapperAttributesForSelection(controller);
  final wrappedSelection = Delta()
    ..operations.addAll(leadingContent.toList())
    ..insert(openingCharacter, wrapperAttributes)
    ..operations.addAll(selectedContent.toList())
    ..insert(closingCharacter, wrapperAttributes)
    ..operations.addAll(trailingContent.toList());

  replaceText(
    index,
    len,
    wrappedSelection,
    null,
  );
  controller.updateSelection(
    TextSelection(
      baseOffset: trimmedSelection.start + 1,
      extentOffset: trimmedSelection.start + 1 + trimmedSelection.length,
    ),
    quill.ChangeSource.local,
  );
  return true;
}

Map<String, dynamic>? _wrapperAttributesForSelection(
  quill.QuillController controller,
) {
  final attributes = <String, dynamic>{};
  for (final attribute in controller.getSelectionStyle().attributes.values) {
    if (attribute.scope == quill.AttributeScope.inline &&
        attribute.key != quill.Attribute.link.key) {
      attributes[attribute.key] = attribute.value;
    }
  }

  return attributes.isEmpty ? null : attributes;
}

_TrimmedSelectionRange? _trimmedSelectionRange({
  required String plainText,
  required int index,
  required int len,
}) {
  if (len <= 0 || plainText.isEmpty) {
    return null;
  }

  final start = index.clamp(0, plainText.length);
  final end = (index + len).clamp(start, plainText.length);
  if (end <= start) {
    return null;
  }

  var trimmedStart = start;
  var trimmedEnd = end;

  while (trimmedStart < trimmedEnd &&
      _isIgnoredSelectionBoundaryCharacter(plainText[trimmedStart])) {
    trimmedStart++;
  }
  while (trimmedEnd > trimmedStart &&
      _isIgnoredSelectionBoundaryCharacter(plainText[trimmedEnd - 1])) {
    trimmedEnd--;
  }

  if (trimmedEnd <= trimmedStart) {
    return null;
  }

  return _TrimmedSelectionRange(
    start: trimmedStart,
    end: trimmedEnd,
    leadingLength: trimmedStart - start,
    trailingLength: end - trimmedEnd,
  );
}

bool _isIgnoredSelectionBoundaryCharacter(String character) =>
    character == ' ' || character == '\n' || character == '\r';

class _TrimmedSelectionRange {
  const _TrimmedSelectionRange({
    required this.start,
    required this.end,
    required this.leadingLength,
    required this.trailingLength,
  });

  final int start;
  final int end;
  final int leadingLength;
  final int trailingLength;

  int get length => end - start;
}
