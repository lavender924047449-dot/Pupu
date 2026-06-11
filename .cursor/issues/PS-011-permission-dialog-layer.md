# PS-011 Permission Dialog Layering

## Background

`private_permission_helper.dart` currently lives in `services/` but directly renders UI (`SnackBar` and `AlertDialog`) via `BuildContext`.

This violates the layering target in `PLAN-ARCH-001`:

- service/data layer should return state/intent only
- feature UI layer should decide how to render dialog/snackbar

## Current State

- File: `lib/services/private_permission_helper.dart`
- Behavior:
  - requests permission with `permission_handler`
  - on denied/permanently denied, directly shows snack/dialog

## Risk

- service layer becomes coupled to widget tree and UI style
- hard to unit test permission flow without widget context
- future platform-specific permission UX is harder to customize

## Proposed Direction (out of ARCH mainline)

1. Keep permission querying/request in service helper.
2. Replace direct dialog/snackbar calls with semantic result enum, e.g.:
   - granted
   - deniedRetryable
   - deniedPermanently
3. Let `private_space_screen.dart` (or feature widget) map enum to UI feedback.

## Scope

- Separate issue by decision R8.
- Not included in ARCH P0/P1/P2 execution path.
