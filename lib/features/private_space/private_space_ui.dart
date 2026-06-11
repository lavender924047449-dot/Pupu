import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared gesture timings for Private Space embeds (double-tap > long-press > drag).
abstract final class PrivateSpaceGestures {
  /// Drop-target highlight when dragging an embed over another slot.
  static const Duration embedDropHighlight = Duration(milliseconds: 120);

  /// Long-press delay on the drag handle before reorder starts.
  static const Duration embedDragDelay = Duration(milliseconds: 220);
}

/// Private Space dark-gold visual tokens for sheets and menus.
abstract final class PrivateSpaceColors {
  static const Color sheetBackground = Color(0xFF121A26);
  static const Color accent = Color(0xFFE2BE57);
  static const Color dialogTitle = Color(0xFFF6E6B3);
}

/// Typography shared by Save Changes / Rename voice dialogs.
abstract final class PrivateSpaceDialogStyles {
  static const TextStyle title = TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: PrivateSpaceColors.dialogTitle,
  );

  static const TextStyle action = TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 17,
    fontWeight: FontWeight.w400,
  );
}

/// One row in a unified bottom action sheet.
class PrivateSpaceAction<T> {
  const PrivateSpaceAction({
    required this.value,
    required this.icon,
    required this.label,
    this.subtitle,
  });

  final T value;
  final IconData icon;
  final String label;
  final String? subtitle;
}

/// Light haptic cues aligned with embed / menu interactions.
abstract final class PrivateSpaceHaptics {
  static void menuOpen() => HapticFeedback.selectionClick();

  static void embedDragStart() => HapticFeedback.mediumImpact();

  static void embedDrop() => HapticFeedback.lightImpact();

  static void imageFullscreen() => HapticFeedback.lightImpact();
}

/// Bottom sheet with consistent shape, colors, and open haptic.
Future<T?> showPrivateActionSheet<T>({
  required BuildContext context,
  required List<PrivateSpaceAction<T>> actions,
}) {
  PrivateSpaceHaptics.menuOpen();
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: PrivateSpaceColors.sheetBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            ListTile(
              leading: Icon(action.icon, color: PrivateSpaceColors.accent),
              title: Text(
                action.label,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: action.subtitle == null
                  ? null
                  : Text(
                      action.subtitle!,
                      style: const TextStyle(color: Colors.white38),
                    ),
              onTap: () => Navigator.pop(ctx, action.value),
            ),
        ],
      ),
    ),
  );
}

/// Popup menu item styled like bottom-sheet actions.
PopupMenuItem<T> privatePopupMenuItem<T>({
  required T value,
  required String label,
}) {
  return PopupMenuItem<T>(
    value: value,
    child: Text(label, style: const TextStyle(color: Colors.white)),
  );
}

/// iOS-style split-action alert shell (Save Changes / Rename voice).
class _PrivateSpaceSplitDialog extends StatelessWidget {
  const _PrivateSpaceSplitDialog({
    required this.title,
    this.content,
    required this.leftLabel,
    required this.rightLabel,
    required this.onLeft,
    required this.onRight,
    this.rightIsDefault = false,
  });

  final String title;
  final Widget? content;
  final String leftLabel;
  final String rightLabel;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final bool rightIsDefault;

  static const _actionHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PrivateSpaceColors.sheetBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, content == null ? 20 : 12),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: PrivateSpaceDialogStyles.title,
              ),
            ),
            if (content != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: content,
              ),
            SizedBox(
              height: _actionHeight,
              child: Row(
                children: [
                  Expanded(
                    child: _SplitDialogAction(
                      label: leftLabel,
                      style: PrivateSpaceDialogStyles.action.copyWith(
                        color: Colors.white54,
                      ),
                      onTap: onLeft,
                    ),
                  ),
                  Expanded(
                    child: _SplitDialogAction(
                      label: rightLabel,
                      style: PrivateSpaceDialogStyles.action.copyWith(
                        color: PrivateSpaceColors.accent,
                        fontWeight:
                            rightIsDefault ? FontWeight.w600 : FontWeight.w400,
                      ),
                      onTap: onRight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitDialogAction extends StatelessWidget {
  const _SplitDialogAction({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(label, style: style, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// Rename / text-input dialog — title & actions match Save Changes layout.
Future<String?> showPrivateTextDialog({
  required BuildContext context,
  required String title,
  String hintText = '',
  String initialText = '',
  String confirmLabel = 'Save',
}) {
  final controller = TextEditingController(text: initialText);
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PrivateSpaceSplitDialog(
      title: title,
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(
          fontFamily: 'SF Pro',
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: PrivateSpaceColors.accent, width: 1),
          ),
        ),
      ),
      leftLabel: 'Cancel',
      rightLabel: confirmLabel,
      rightIsDefault: true,
      onLeft: () => Navigator.pop(ctx),
      onRight: () => Navigator.pop(ctx, controller.text.trim()),
    ),
  );
}

/// User choice from the unsaved-changes confirmation dialog.
enum PrivateUnsavedChoice { save, discard }

/// Unsaved-changes alert — English copy, split actions, sheetBackground chrome.
Future<PrivateUnsavedChoice?> showPrivateUnsavedChangesDialog({
  required BuildContext context,
}) {
  return showDialog<PrivateUnsavedChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PrivateSpaceSplitDialog(
      title: 'Save Changes?',
      leftLabel: "Don't Save",
      rightLabel: 'Save',
      rightIsDefault: true,
      onLeft: () => Navigator.pop(ctx, PrivateUnsavedChoice.discard),
      onRight: () => Navigator.pop(ctx, PrivateUnsavedChoice.save),
    ),
  );
}

/// Delete confirmation for History records, matching Save Changes dialog chrome.
Future<bool?> showPrivateDeleteRecordDialog({
  required BuildContext context,
  required bool plural,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => _PrivateSpaceSplitDialog(
      title: plural ? 'Delete Records?' : 'Delete Record?',
      leftLabel: 'No',
      rightLabel: 'Yes',
      rightIsDefault: true,
      onLeft: () => Navigator.pop(ctx, false),
      onRight: () => Navigator.pop(ctx, true),
    ),
  );
}
