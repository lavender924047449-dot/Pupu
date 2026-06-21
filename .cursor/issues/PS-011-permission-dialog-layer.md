# PS-011 Permission Dialog Layering

**Status:** ✅ Resolved (PLAN-DIALOG-001, 2026-06-12)

## Background

`private_permission_helper.dart` previously lived in `services/` but directly rendered UI (`SnackBar` and `AlertDialog`) via `BuildContext`.

This violated the layering target in `PLAN-ARCH-001`:

- service/data layer should return state/intent only
- feature UI layer should decide how to render dialog/snackbar

## Resolution

1. `PrivatePermissionHelper.ensure()` returns `PrivatePermissionResult` enum — no UI, no `BuildContext`.
2. UI feedback in `private_space_ui.dart`:
   - `showPrivatePermissionSettingsDialog` — iOS Cupertino (system default) / Android Material + `AppTypography`
   - `showPrivatePermissionRetrySnack` — module-scoped SnackBar + Retry
   - `resolvePrivatePermissionResult` — maps enum → F3/F4
3. Callers: `private_space_screen.dart`, `private_voice_sheet.dart`
4. Tests: `test/private_permission_helper_test.dart`

## References

- [PLAN-DIALOG-001.md](../plans/PLAN-DIALOG-001.md)
- [DIALOG-LAYER-FAMILIES.md](../docs/DIALOG-LAYER-FAMILIES.md) — F3, F4
