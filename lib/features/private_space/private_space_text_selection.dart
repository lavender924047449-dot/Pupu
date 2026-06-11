import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pupu/features/private_space/private_space_clipboard.dart';

/// Text selection toolbar for Private Space text segments.
///
/// Extends [MaterialTextSelectionControls] so the toolbar keeps the platform
/// default look; only copy/cut/paste routing is customized for semantic ranges.
class PrivateSpaceTextSelectionControls extends MaterialTextSelectionControls {  PrivateSpaceTextSelectionControls({
    required this.onPaste,
    this.onCopiedText,
    this.onCutText,
    this.onSemanticCopy,
    this.onSemanticCut,
  });

  final Future<void> Function() onPaste;
  final void Function(String text)? onCopiedText;
  final void Function(String text)? onCutText;
  final bool Function()? onSemanticCopy;
  final bool Function()? onSemanticCut;

  @override
  bool canPaste(TextSelectionDelegate delegate) => delegate.pasteEnabled;

  @override
  Future<void> handlePaste(TextSelectionDelegate delegate) => onPaste();

  @override
  void handleCopy(TextSelectionDelegate delegate) {
    if (onSemanticCopy?.call() == true) {
      onCopiedText?.call('');
      return;
    }

    final value = delegate.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = value.text.substring(selection.start, selection.end);
    if (text.isEmpty) return;

    PrivateSpaceClipboard.copyText(text);
    onCopiedText?.call(text);
    Clipboard.setData(ClipboardData(text: text));
  }

  @override
  void handleCut(TextSelectionDelegate delegate) {
    if (onSemanticCut?.call() == true) {
      onCutText?.call('');
      return;
    }

    final value = delegate.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = value.text.substring(selection.start, selection.end);
    if (text.isEmpty) return;

    PrivateSpaceClipboard.copyText(text);
    onCutText?.call(text);
    Clipboard.setData(ClipboardData(text: text));

    final next = value.text.replaceRange(selection.start, selection.end, '');
    delegate.userUpdateTextEditingValue(
      value.copyWith(
        text: next,
        selection: TextSelection.collapsed(offset: selection.start),
      ),
      SelectionChangedCause.toolbar,
    );
  }
}
