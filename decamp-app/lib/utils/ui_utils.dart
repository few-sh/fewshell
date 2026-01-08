import 'package:flutter/material.dart';

Widget adaptiveContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  // Use AdaptiveTextSelectionToolbar.buttonItems to allow customizing buttons
  // and ensuring we wrap it in a TapRegion to prevent focus loss.
  final List<ContextMenuButtonItem> buttonItems =
      editableTextState.contextMenuButtonItems;

  final Widget toolbar = AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: buttonItems,
  );

  // Wrap the toolbar in a TapRegion with the same groupId as the EditableText.
  // This ensures that taps on the toolbar are considered "inside" the text field's
  // interaction region, preventing the `onTapOutside` handler (which Unfocuses)
  // from being triggered.
  return TapRegion(groupId: editableTextState.widget.groupId, child: toolbar);
}
