# PLAN-TYPO-001: PS Entries + Archive 大标题字距统一

**进度:** 100% ✅

---

## Tasks

| # | 任务 | 状态 |
|---|------|------|
| 1 | Entries：17 / w500 / letterSpacing 0 | ✅ |
| 2 | Archive 三页大标题：共享 token + letterSpacing 0 | ✅ |
| 3 | `flutter test` 148/148 | ✅ |

## 规格

- **Entries**（`private_space_screen.dart`）：fontSize 17、w500、letterSpacing 0、`#FEF3C7`
- **Archive 大标题**（Log Calendar / Chart Analysis / Logs）：`ArchiveTypography.pageTitle` — 25pt bold、letterSpacing 0

## 改动文件

| 文件 | 改动 |
|------|------|
| `lib/features/archive/archive_typography.dart` | 新增共享 `pageTitle` |
| `lib/features/private_space/private_space_screen.dart` | Entries / N Selected 标题 |
| `lib/features/archive/new_archive_screen.dart` | Log Calendar |
| `lib/features/archive/chart_analysis_card.dart` | Chart Analysis |
| `lib/features/archive/logs_card.dart` | Logs |
