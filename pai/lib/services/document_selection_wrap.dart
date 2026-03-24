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

  final selectedContent = controller.document.toDelta().slice(index, index + len);
  if (selectedContent.isEmpty) {
    return false;
  }

  final wrapperAttributes = _wrapperAttributesForSelection(controller);
  final wrappedSelection = Delta()
    ..insert(openingCharacter, wrapperAttributes)
    ..operations.addAll(selectedContent.toList())
    ..insert(closingCharacter, wrapperAttributes);

  replaceText(
    index,
    len,
    wrappedSelection,
    null,
  );
  controller.updateSelection(
    TextSelection(
      baseOffset: index + 1,
      extentOffset: index + 1 + len,
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
