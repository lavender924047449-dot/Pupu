import 'dart:async';
import 'dart:io' show FileSystemException;
import 'dart:math';

import 'package:pupu/features/private_space/private_note_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pupu/core/app_typography.dart';
import 'package:pupu/features/private_space/private_entry_sort.dart';
import 'package:pupu/features/private_space/private_note_gallery_limits.dart';
import 'package:pupu/features/private_space/private_note_document_controller.dart';
import 'package:pupu/features/private_space/private_space_clipboard.dart';
import 'package:pupu/features/private_space/private_space_history.dart';
import 'package:pupu/features/private_space/private_space_ui.dart';
import 'package:pupu/features/private_space/private_voice_sheet.dart';
import 'package:pupu/features/private_space/private_space_background.dart';
import 'package:pupu/features/private_space/private_space_notepad.dart';
import 'package:pupu/features/private_space/private_space_categories.dart';
import 'package:pupu/features/timer/widgets/audio_picker.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';
import 'package:pupu/services/local_storage.dart';
import 'package:pupu/services/private_media_storage.dart';
import 'package:pupu/services/private_permission_helper.dart';
import 'package:pupu/providers/entries_provider.dart';
import 'package:pupu/providers/home_audio_provider.dart';

enum _Stage { idle, transitioning, notepad, history }

/// How to position the RECORDS list the next time history becomes visible.
enum _HistoryScrollOnShow {
  /// Fresh history mount — ListView starts at 0 naturally.
  defaultTop,

  /// Return from notepad — restore [_savedHistoryScrollOffset].
  restoreSaved,

  /// FAB new note saved — jump to top.
  jumpToTop,
}

enum _ImageInsertAction { gallery, camera }

enum _ImagePersistFailure { unavailable, tooLarge, saveFailed }

class _CategoryData {
  const _CategoryData({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;
  final Color color;

  PrivateSpaceCategoryData toViewData() {
    return PrivateSpaceCategoryData(id: id, name: name, color: color);
  }
}

class PrivateSpaceScreen extends ConsumerStatefulWidget {
  const PrivateSpaceScreen({super.key});

  @override
  ConsumerState<PrivateSpaceScreen> createState() => _PrivateSpaceScreenState();
}

class _PrivateSpaceScreenState extends ConsumerState<PrivateSpaceScreen>
    with TickerProviderStateMixin {
  static const int _maxImagesPerNote = 35;
  static const int _maxVoicesPerNote = 35;
  static const int _maxGalleryPickCount = 5;
  static const String _kSelectionLimitReached = 'Selection limit reached.';
  static const int _maxImageFileBytes = 12 * 1024 * 1024;
  static const Duration _stageSwitchDuration = Duration(milliseconds: 820);

  static const List<_CategoryData> _defaultCategories = [
    _CategoryData(id: '1', name: 'Ideas', color: Color(0xFF3B82F6)),
    _CategoryData(id: '2', name: 'Thoughts', color: Color(0xFF8B5CF6)),
    _CategoryData(id: '3', name: 'Feelings', color: Color(0xFFEC4899)),
    _CategoryData(id: '4', name: 'Journal', color: Color(0xFF10B981)),
    _CategoryData(id: '5', name: 'Uncategorized', color: Color(0xFF64748B)),
  ];

  static const List<Color> _newCategoryPalette = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
    Color(0xFF6366F1),
    Color(0xFFA855F7),
    Color(0xFFF43F5E),
  ];

  final ScrollController _noteScrollController = ScrollController();
  final ScrollController _historyListScrollController = ScrollController();
  final ScrollController _categoryPanelScrollController = ScrollController();
  final Random _random = Random();

  double _savedHistoryScrollOffset = 0;
  _HistoryScrollOnShow _historyScrollOnShow = _HistoryScrollOnShow.defaultTop;

  PrivateNoteDocumentController? _docController;

  _Stage _stage = _Stage.idle;
  _Stage _targetStage = _Stage.notepad;
  List<PrivateEntry> _entries = const [];
  bool _selectionMode = false;
  final Set<String> _selectedEntries = <String>{};
  List<_CategoryData> _categories = _defaultCategories;
  String? _editingEntryId;
  bool _showMarkBoard = false;
  bool _isAddingCategory = false;
  String? _showDeleteForCategoryId;
  String? _historySwipeCloseEntryId;
  int _historySwipeCloseNonce = 0;
  final TextEditingController _categoryController = TextEditingController();
  final FocusNode _categoryFocusNode = FocusNode();
  late final AnimationController _musicRotationController;
  bool _voicePlaybackOwnsHomePause = false;
  bool _resumeHomeMusicAfterVoicePlayback = false;

  @override
  void initState() {
    super.initState();
    _musicRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    PrivateVoicePlayer.instance.addListener(_onVoicePlayerChanged);
  }

  @override
  void dispose() {
    PrivateVoicePlayer.instance.removeListener(_onVoicePlayerChanged);
    PrivateVoicePlayer.instance.stop();
    _musicRotationController.dispose();
    _docController?.dispose();
    _noteScrollController.dispose();
    _historyListScrollController.dispose();
    _categoryPanelScrollController.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  void _syncMusicRotation(bool isPlaying) {
    if (isPlaying) {
      if (!_musicRotationController.isAnimating) {
        _musicRotationController.repeat();
      }
      return;
    }
    _musicRotationController.stop();
  }

  Future<void> _toggleHomeMusicFromSubPage() async {
    await ref.read(homeAudioServiceProvider).toggleFromSubPage(ref);
  }

  void _onVoicePlayerChanged() {
    if (!mounted) return;
    unawaited(_resumeHomeMusicIfVoicePlaybackEnded());
  }

  Future<void> _resumeHomeMusicIfVoicePlaybackEnded() async {
    if (!_voicePlaybackOwnsHomePause) return;
    if (PrivateVoicePlayer.instance.playingPath != null) return;

    final shouldResume = _resumeHomeMusicAfterVoicePlayback;
    _voicePlaybackOwnsHomePause = false;
    _resumeHomeMusicAfterVoicePlayback = false;
    if (!shouldResume) return;
    await ref.read(homeAudioServiceProvider).resume();
  }

  Future<void> _onVoicePlaybackToggle(String path) async {
    final homeAudioService = ref.read(homeAudioServiceProvider);
    final voicePlayer = PrivateVoicePlayer.instance;
    final wasTargetPlaying = voicePlayer.isPlaying(path);

    if (!wasTargetPlaying && !_voicePlaybackOwnsHomePause) {
      final wasHomePlaying = ref.read(homeMusicPlayingProvider).value ?? false;
      _voicePlaybackOwnsHomePause = true;
      _resumeHomeMusicAfterVoicePlayback = wasHomePlaying;
      if (wasHomePlaying) {
        await homeAudioService.pauseByUser();
      }
    }

    await voicePlayer.toggle(path);

    if (wasTargetPlaying) {
      await _resumeHomeMusicIfVoicePlaybackEnded();
    }
  }

  List<PrivateEntry> get _sortedEntries => sortPrivateEntriesForHistory(_entries);

  void _captureHistoryListScrollOffset() {
    if (_historyListScrollController.hasClients) {
      _savedHistoryScrollOffset = _historyListScrollController.offset;
    }
  }

  void _clearHistoryScrollMemory() {
    _savedHistoryScrollOffset = 0;
    _historyScrollOnShow = _HistoryScrollOnShow.defaultTop;
  }

  /// Applies pending scroll intent after history ListView lays out (may retry once).
  void _applyPendingHistoryScroll() {
    if (_historyScrollOnShow == _HistoryScrollOnShow.defaultTop) return;

    final intent = _historyScrollOnShow;

    void applyOnce() {
      if (!mounted || _stage != _Stage.history) return;
      if (_historyScrollOnShow == _HistoryScrollOnShow.defaultTop) return;
      if (!_historyListScrollController.hasClients) return;

      final maxExtent = _historyListScrollController.position.maxScrollExtent;
      final target = switch (intent) {
        _HistoryScrollOnShow.restoreSaved => clampHistoryScrollOffset(
            savedOffset: _savedHistoryScrollOffset,
            maxScrollExtent: maxExtent,
          ),
        _HistoryScrollOnShow.jumpToTop => 0.0,
        _HistoryScrollOnShow.defaultTop => 0.0,
      };
      _historyListScrollController.jumpTo(target);
      _historyScrollOnShow = _HistoryScrollOnShow.defaultTop;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyOnce();
      WidgetsBinding.instance.addPostFrameCallback((_) => applyOnce());
    });
  }

  bool _isPinned(PrivateEntry entry) => entry.tags.contains('pinned');

  _CategoryData? _categoryForEntry(PrivateEntry entry) {
    for (final category in _categories) {
      if (category.name == entry.category) return category;
    }
    return null;
  }

  Future<void> _openFromStar() async {
    if (_stage != _Stage.idle) return;
    setState(() {
      _targetStage = _entries.isNotEmpty ? _Stage.history : _Stage.notepad;
      _stage = _Stage.transitioning;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1650));
    if (!mounted) return;
    setState(() {
      _stage = _targetStage;
      if (_targetStage == _Stage.notepad) {
        _resetEditor();
      }
    });
  }

  /// Disposes the note controller. When [deferred] is true, teardown runs after
  /// AnimatedSwitcher finishes the outgoing notepad transition.
  ///
  /// A next-frame dispose is too early because the old notepad subtree remains
  /// mounted during switch-out animation and still depends on controller-owned
  /// FocusNodes/TextControllers.
  void _disposeDocController({bool deferred = false}) {
    final controller = _docController;
    if (controller == null) return;
    controller.removeListener(_onDocControllerChanged);
    _docController = null;
    if (deferred) {
      Future<void>.delayed(
        _stageSwitchDuration + const Duration(milliseconds: 40),
        controller.disposeController,
      );
    } else {
      controller.disposeController();
    }
  }

  void _onDocControllerChanged() {
    if (mounted) setState(() {});
  }

  void _resetEditor([PrivateEntry? entry]) {
    _disposeDocController();
    _docController = PrivateNoteDocumentController(
      initial: entry?.document ?? PrivateNoteDocument.empty,
      showEntryPlaceholder: entry == null,
    );
    _docController!.addListener(_onDocControllerChanged);
    _docController!.captureSavedBaseline();
  }

  void _undoNoteEdit() {
    _docController?.undo();
  }

  void _redoNoteEdit() {
    _docController?.redo();
  }

  void _returnToHistoryFromNotepad(_HistoryScrollOnShow scrollOnShow) {
    PrivateVoicePlayer.instance.stop();
    FocusManager.instance.primaryFocus?.unfocus();
    _editingEntryId = null;
    _disposeDocController(deferred: true);
    // No saved records — e.g. opened empty notepad from star and backed out.
    if (_entries.isEmpty) {
      setState(() => _stage = _Stage.idle);
      return;
    }
    _historyScrollOnShow = scrollOnShow;
    setState(() => _stage = _Stage.history);
    _applyPendingHistoryScroll();
  }

  void _exitNotepad({
    _HistoryScrollOnShow scrollOnShow = _HistoryScrollOnShow.restoreSaved,
  }) {
    _returnToHistoryFromNotepad(scrollOnShow);
  }

  /// Persists the current note when it has content. Returns false if empty/no controller.
  Future<bool> _persistNote({required bool touchUpdatedAt}) async {
    final controller = _docController;
    if (controller == null || controller.isEmpty) return false;

    final document = controller.buildDocument();
    final preview = controller.plainTextPreview();

    final existing = _editingEntryId == null
        ? null
        : _entries.where((entry) => entry.id == _editingEntryId).firstOrNull;
    final now = DateTime.now();
    final title = preview.trim().isNotEmpty
        ? _deriveTitle(preview)
        : _deriveTitleFromDocument(document);

    final entry = existing?.copyWith(
          title: title,
          document: document,
          updatedAt: touchUpdatedAt ? DateTime.now() : existing.updatedAt,
        ) ??
        PrivateEntry(
          id: now.microsecondsSinceEpoch.toString(),
          title: title,
          document: document,
          category: 'Uncategorized',
        );

    await LocalStorage.saveEntry(entry);
    if (mounted) {
      if (existing == null) {
        _entries = [..._entries, entry];
      } else {
        _entries = _entries
            .map((e) => e.id == entry.id ? entry : e)
            .toList(growable: false);
      }
    }
    bumpEntriesRefresh(ref);
    if (mounted) controller.captureSavedBaseline();
    return true;
  }

  Future<void> _handleNotepadBack() async {
    final controller = _docController;
    final isNew = _editingEntryId == null;

    if (isNew) {
      if (controller == null || controller.isEmpty) {
        _exitNotepad();
        return;
      }
      await _persistNote(touchUpdatedAt: true);
      if (mounted) {
        _exitNotepad(scrollOnShow: _HistoryScrollOnShow.jumpToTop);
      }
      return;
    }

    if (controller == null || !controller.hasUnsavedEdits) {
      _exitNotepad();
      return;
    }

    final choice = await showPrivateUnsavedChangesDialog(context: context);
    if (!mounted || choice == null) return;

    if (choice == PrivateUnsavedChoice.save) {
      if (await _persistNote(touchUpdatedAt: true) && mounted) {
        _exitNotepad();
      }
    } else if (mounted) {
      _exitNotepad();
    }
  }

  /// Unified back: overlay → stage → route (system back ≡ in-app chevron).
  Future<void> _handleBack() async {
    if (_stage == _Stage.transitioning) return;

    if (_showMarkBoard) {
      setState(() {
        _showMarkBoard = false;
        _isAddingCategory = false;
        _showDeleteForCategoryId = null;
        _categoryController.clear();
      });
      return;
    }

    if (_selectionMode) {
      setState(() {
        _selectionMode = false;
        _selectedEntries.clear();
      });
      return;
    }

    switch (_stage) {
      case _Stage.notepad:
        await _handleNotepadBack();
      case _Stage.history:
        _clearHistoryScrollMemory();
        setState(() => _stage = _Stage.idle);
      case _Stage.idle:
        if (mounted) Navigator.of(context).pop();
      case _Stage.transitioning:
        break;
    }
  }

  Future<void> _saveNote() async {
    if (!await _persistNote(touchUpdatedAt: true)) return;
    if (!mounted) return;
    final wasNewNote = _editingEntryId == null;
    _returnToHistoryFromNotepad(
      wasNewNote ? _HistoryScrollOnShow.jumpToTop : _HistoryScrollOnShow.restoreSaved,
    );
  }

  String _deriveTitle(String text) {
    final firstLine = text
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => 'Untitled');
    return firstLine.length <= 24 ? firstLine : '${firstLine.substring(0, 24)}...';
  }

  String _deriveTitleFromDocument(PrivateNoteDocument document) {
    for (final op in document.ops) {
      switch (op) {
        case PrivateDocVoiceOp(:final voice):
          final t = voice.title?.trim();
          if (t != null && t.isNotEmpty) {
            return t.length <= 24 ? t : '${t.substring(0, 24)}...';
          }
          return 'Voice Note';
        case PrivateDocImageOp():
          return 'Photo Note';
        case PrivateDocTextOp(:final text):
          if (text.trim().isNotEmpty) return _deriveTitle(text);
      }
    }
    return 'Untitled';
  }

  Future<void> _pickImage() async {
    if ((_docController?.imageCount ?? 0) >= _maxImagesPerNote) {
      _showSelectionLimitReached();
      return;
    }

    final action = await showPrivateActionSheet<_ImageInsertAction>(
      context: context,
      actions: const [
        PrivateSpaceAction(
          value: _ImageInsertAction.gallery,
          icon: Icons.photo_library_outlined,
          label: 'Photo Library',
        ),
        PrivateSpaceAction(
          value: _ImageInsertAction.camera,
          icon: Icons.photo_camera_outlined,
          label: 'Camera',
        ),
      ],
    );
    if (action == null || !mounted) return;

    final source = action == _ImageInsertAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    await _pickImageFromSource(source);
  }

  /// Permission gate + [ImagePicker] for a fixed [source].
  Future<void> _pickImageFromSource(ImageSource source) async {
    final permission = source == ImageSource.camera
        ? PrivatePermissionKind.camera
        : PrivatePermissionKind.photoLibrary;
    if (!await _resolvePrivatePermission(
      permission,
      onRetry: () => unawaited(_pickImageFromSource(source)),
    )) {
      return;
    }

    if ((_docController?.imageCount ?? 0) >= _maxImagesPerNote) {
      _showSelectionLimitReached();
      return;
    }

    if (source == ImageSource.camera) {
      await _pickSingleImage(source);
    } else {
      await _pickGalleryImages();
    }
  }

  Future<void> _pickSingleImage(ImageSource source) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    } on PlatformException {
      _showPrivateSnackBar('Cannot access image picker. Please retry.');
      return;
    } catch (_) {
      _showPrivateSnackBar('Image picker failed. Please retry.');
      return;
    }

    if (picked == null || !mounted) return;

    final persisted = await _persistPickedImage(
      picked,
      idSuffix: '',
    );
    if (!mounted) return;
    if (persisted.failure != null) {
      _showImagePersistFailureSnackBar(persisted.failure!);
      return;
    }
    _docController?.insertImagesAtCaret([
      PrivateImageData(
        id: 'img_${persisted.id}',
        path: persisted.path!,
        source: source == ImageSource.camera ? 'camera' : 'gallery',
      ),
    ]);
    setState(() {});
  }

  Future<void> _pickGalleryImages() async {
    final currentCount = _docController?.imageCount ?? 0;
    final pickLimit = galleryPickLimit(
      currentImageCount: currentCount,
      maxImagesPerNote: _maxImagesPerNote,
      maxGalleryPickCount: _maxGalleryPickCount,
    );
    if (pickLimit <= 0) {
      _showSelectionLimitReached();
      return;
    }

    List<XFile> picked;
    try {
      picked = await ImagePicker().pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        limit: pickLimit,
      );
    } on PlatformException {
      _showPrivateSnackBar('Cannot access image picker. Please retry.');
      return;
    } catch (_) {
      _showPrivateSnackBar('Image picker failed. Please retry.');
      return;
    }

    if (picked.isEmpty || !mounted) return;

    if (shouldRejectGalleryBatch(picked.length, pickLimit)) {
      _showSelectionLimitReached();
      return;
    }

    var tooLarge = 0;
    var unavailable = 0;
    var saveFailed = 0;
    final images = <PrivateImageData>[];

    for (var i = 0; i < picked.length; i++) {
      if (!mounted) return;

      final persisted = await _persistPickedImage(
        picked[i],
        idSuffix: '_$i',
      );
      if (persisted.failure == null && persisted.path != null) {
        images.add(
          PrivateImageData(
            id: 'img_${persisted.id}',
            path: persisted.path!,
            source: 'gallery',
          ),
        );
      } else {
        switch (persisted.failure) {
          case _ImagePersistFailure.unavailable:
            unavailable++;
          case _ImagePersistFailure.tooLarge:
            tooLarge++;
          case _ImagePersistFailure.saveFailed:
            saveFailed++;
          case null:
            break;
        }
      }
    }

    if (!mounted) return;

    if (images.isNotEmpty) {
      _docController?.insertImagesAtCaret(images);
      setState(() {});
    }

    final skipped = tooLarge + unavailable + saveFailed;
    if (skipped > 0) {
      _showGalleryImportSummary(
        inserted: images.length,
        tooLarge: tooLarge,
        unavailable: unavailable,
        saveFailed: saveFailed,
      );
    }
  }

  Future<({String id, String? path, _ImagePersistFailure? failure})>
      _persistPickedImage(
    XFile picked, {
    required String idSuffix,
  }) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}$idSuffix';

    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        return (id: id, path: null, failure: _ImagePersistFailure.unavailable);
      }
      if (bytes.length > _maxImageFileBytes) {
        return (id: id, path: null, failure: _ImagePersistFailure.tooLarge);
      }
      final ext = _imageExtensionFromPath(picked.path);
      final path = await PrivateMediaStorage.persistImageBytes(
        bytes,
        id: id,
        extension: ext,
      );
      return (id: id, path: path, failure: null);
    } on FileSystemException {
      return (id: id, path: null, failure: _ImagePersistFailure.saveFailed);
    } catch (_) {
      return (id: id, path: null, failure: _ImagePersistFailure.saveFailed);
    }
  }

  void _showImagePersistFailureSnackBar(_ImagePersistFailure failure) {
    switch (failure) {
      case _ImagePersistFailure.unavailable:
        _showPrivateSnackBar('Selected image is unavailable.');
      case _ImagePersistFailure.tooLarge:
        _showPrivateSnackBar('Image is too large (max 12MB).');
      case _ImagePersistFailure.saveFailed:
        _showPrivateSnackBar('Image import failed. Please try again.');
    }
  }

  void _showGalleryImportSummary({
    required int inserted,
    required int tooLarge,
    required int unavailable,
    required int saveFailed,
  }) {
    final parts = <String>[];
    if (tooLarge > 0) {
      parts.add(
        tooLarge == 1
            ? '1 too large (12MB max)'
            : '$tooLarge too large (12MB max)',
      );
    }
    if (unavailable > 0) {
      parts.add(unavailable == 1 ? '1 unavailable' : '$unavailable unavailable');
    }
    if (saveFailed > 0) {
      parts.add(saveFailed == 1 ? '1 save failed' : '$saveFailed save failed');
    }
    final detail = parts.join(', ');

    if (inserted == 0) {
      _showPrivateSnackBar('Could not import selected images: $detail.');
      return;
    }

    final skipped = tooLarge + unavailable + saveFailed;
    _showPrivateSnackBar(
      '$inserted ${inserted == 1 ? 'image' : 'images'} added. '
      '$skipped skipped: $detail.',
    );
  }

  void _showSelectionLimitReached() {
    _showPrivateSnackBar(_kSelectionLimitReached);
  }

  static String _imageExtensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    const allowed = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};
    return allowed.contains(ext) ? ext : '.jpg';
  }

  void _copyImageAt(int opIndex, PrivateImageData image) {
    PrivateSpaceClipboard.copyImage(image);
  }

  void _cutImageAt(int opIndex, PrivateImageData image) {
    PrivateSpaceClipboard.copyImage(image);
    _docController?.removeImageAt(opIndex);
    setState(() {});
  }

  void _deleteImageAt(int opIndex, PrivateImageData image) {
    _docController?.removeImageAt(opIndex);
    setState(() {});
    _showPrivateSnackBar('Image deleted.');
  }

  Future<void> _openImagePreview(int opIndex, PrivateImageData image) async {
    PrivateSpaceHaptics.imageFullscreen();
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: _PreviewImage(path: image.path)),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || _stage != _Stage.notepad) return;
  }

  Future<void> _showImageQuickActions(int opIndex, PrivateImageData image) async {
    const copy = 'copy';
    const cut = 'cut';
    const delete = 'delete';

    final action = await showPrivateActionSheet<String>(
      context: context,
      actions: const [
        PrivateSpaceAction(value: copy, icon: Icons.copy_outlined, label: 'Copy Image'),
        PrivateSpaceAction(value: cut, icon: Icons.content_cut_outlined, label: 'Cut Image'),
        PrivateSpaceAction(value: delete, icon: Icons.delete_outline, label: 'Delete Image'),
      ],
    );
    switch (action) {
      case copy:
        _copyImageAt(opIndex, image);
        break;
      case cut:
        _cutImageAt(opIndex, image);
        break;
      case delete:
        _deleteImageAt(opIndex, image);
        break;
      default:
        break;
    }
  }

  Future<bool> _resolvePrivatePermission(
    PrivatePermissionKind kind, {
    VoidCallback? onRetry,
  }) async {
    final result = await PrivatePermissionHelper.ensure(kind);
    if (!mounted) return false;
    return resolvePrivatePermissionResult(
      context: context,
      result: result,
      kind: kind,
      onRetry: () {
        if (!mounted) return;
        if (onRetry != null) {
          onRetry();
        } else {
          unawaited(_resolvePrivatePermission(kind, onRetry: onRetry));
        }
      },
    );
  }

  void _showPrivateSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.body()),
      ),
    );
  }

  Future<void> _addVoiceBlock() async {
    if ((_docController?.voiceCount ?? 0) >= _maxVoicesPerNote) {
      _showSelectionLimitReached();
      return;
    }

    final homeAudioService = ref.read(homeAudioServiceProvider);
    final wasHomePlaying = ref.read(homeMusicPlayingProvider).value ?? false;
    if (wasHomePlaying) {
      await homeAudioService.pauseByUser();
    }
    if (!mounted) return;

    final voice = await showModalBottomSheet<PrivateVoiceData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PrivateVoiceRecordSheet(),
    );

    if (wasHomePlaying) {
      await homeAudioService.resume();
    }

    if (voice == null || !mounted) return;
    _docController?.insertVoiceAtCaret(voice);
    setState(() {});
  }

  Future<void> _renameVoiceAt(int opIndex, PrivateVoiceData voice) async {
    final name = await showPrivateTextDialog(
      context: context,
      title: 'Rename Voice',
      hintText: 'Optional Title',
      initialText: voice.title ?? '',
    );
    if (name == null || !mounted) return;
    _docController?.updateVoiceAt(
      opIndex,
      PrivateVoiceData(
        id: voice.id,
        path: voice.path,
        durationMs: voice.durationMs,
        title: name.isEmpty ? null : name,
        waveform: voice.waveform,
      ),
    );
    setState(() {});
  }

  void _deleteVoiceAt(int opIndex, PrivateVoiceData voice) {
    _docController?.removeVoiceAt(opIndex);
    setState(() {});
    _showPrivateSnackBar('Voice deleted.');
  }

  String _entryPreview(PrivateEntry entry) {
    return entry.plainTextPreview;
  }

  void _createNoteFromHistory() {
    _captureHistoryListScrollOffset();
    _historyScrollOnShow = _HistoryScrollOnShow.restoreSaved;
    _resetEditor();
    _editingEntryId = null;
    setState(() => _stage = _Stage.notepad);
  }

  void _editFromHistory(PrivateEntry entry) {
    _captureHistoryListScrollOffset();
    _historyScrollOnShow = _HistoryScrollOnShow.restoreSaved;
    _resetEditor(entry);
    _editingEntryId = entry.id;
    setState(() => _stage = _Stage.notepad);
  }

  void _toggleSelect(String id, {bool forceStartSelection = false}) {
    setState(() {
      if (forceStartSelection && !_selectionMode) {
        _selectionMode = true;
        _selectedEntries
          ..clear()
          ..add(id);
        return;
      }

      if (_selectedEntries.contains(id)) {
        _selectedEntries.remove(id);
      } else {
        _selectedEntries.add(id);
      }

      if (_selectionMode && _selectedEntries.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _togglePin(String id) async {
    final entry = _entries.where((item) => item.id == id).firstOrNull;
    if (entry == null) return;

    final tags = List<String>.from(entry.tags);
    if (tags.contains('pinned')) {
      tags.remove('pinned');
    } else {
      tags.add('pinned');
    }

    // Keep updatedAt unchanged for pin/unpin so unpin can return
    // to the original non-pinned time order.
    final pinnedUpdated = PrivateEntry(
      id: entry.id,
      title: entry.title,
      document: entry.document,
      tags: tags,
      category: entry.category,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );

    await LocalStorage.saveEntry(pinnedUpdated);
    bumpEntriesRefresh(ref);
  }

  Future<bool> _confirmDeleteRecords({required bool plural}) async {
    // Yield one frame so dialogs opened from swipe actions are not dropped.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return false;
    return await showPrivateDeleteRecordDialog(
          context: context,
          plural: plural,
        ) ==
        true;
  }

  void _requestHistorySwipeClose(String id) {
    setState(() {
      _historySwipeCloseEntryId = id;
      _historySwipeCloseNonce++;
    });
  }

  Future<void> _deleteEntry(String id) async {
    final confirmed = await _confirmDeleteRecords(plural: false);
    if (!confirmed) {
      _requestHistorySwipeClose(id);
      return;
    }
    await LocalStorage.deleteEntry(id);
    if (!mounted) return;
    bumpEntriesRefresh(ref);
    if (!mounted) return;
    setState(() {
      _selectedEntries.remove(id);
      if (_selectionMode && _selectedEntries.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedEntries.clear();
    });
  }

  Future<void> _batchDeleteSelected() async {
    final ids = _selectedEntries.toList();
    if (ids.isEmpty) return;
    final confirmed = await _confirmDeleteRecords(plural: ids.length >= 2);
    if (!confirmed) return;
    for (final id in ids) {
      await LocalStorage.deleteEntry(id);
    }
    if (!mounted) return;
    bumpEntriesRefresh(ref);
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedEntries.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedEntries.length == _entries.length) {
        _selectedEntries.clear();
      } else {
        _selectedEntries
          ..clear()
          ..addAll(_entries.map((entry) => entry.id));
      }
    });
  }

  void _openMarkBoard() {
    setState(() {
      _showMarkBoard = true;
      _isAddingCategory = false;
      _showDeleteForCategoryId = null;
      _categoryController.clear();
    });
  }

  Future<void> _applyCategory(_CategoryData category) async {
    for (final entry in _entries) {
      if (!_selectedEntries.contains(entry.id)) continue;
      final nextCategory = category.name == 'Uncategorized'
          ? 'Uncategorized'
          : category.name;
      await LocalStorage.saveEntry(entry.copyWith(category: nextCategory));
    }
    bumpEntriesRefresh(ref);
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedEntries.clear();
      _showMarkBoard = false;
      _isAddingCategory = false;
      _showDeleteForCategoryId = null;
    });
  }

  void _startAddingCategory() {
    setState(() {
      _isAddingCategory = true;
      _showDeleteForCategoryId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _categoryFocusNode.requestFocus();
      if (_categoryPanelScrollController.hasClients) {
        _categoryPanelScrollController.animateTo(
          _categoryPanelScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _saveCategory() {
    final name = _categoryController.text.trim();
    if (name.isEmpty) return;
    if (_categories.any((category) => category.name == name)) return;

    final newCategory = _CategoryData(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      color: _newCategoryPalette[_random.nextInt(_newCategoryPalette.length)],
    );

    final uncategorizedIndex =
        _categories.indexWhere((category) => category.name == 'Uncategorized');
    final updated = List<_CategoryData>.from(_categories);
    if (uncategorizedIndex >= 0) {
      updated.insert(uncategorizedIndex, newCategory);
    } else {
      updated.add(newCategory);
    }

    setState(() {
      _categories = updated;
      _categoryController.clear();
      _isAddingCategory = false;
    });
  }

  void _deleteCategory(String categoryId) {
    final category =
        _categories.where((item) => item.id == categoryId).firstOrNull;
    if (category == null || category.name == 'Uncategorized') return;

    setState(() {
      _categories = _categories.where((item) => item.id != categoryId).toList();
      _showDeleteForCategoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(entriesWithRefreshProvider);
    final isHomeMusicPlaying = ref.watch(homeMusicPlayingProvider).value ?? false;
    _syncMusicRotation(isHomeMusicPlaying);
    final providerEntries = asyncEntries.value;
    if (providerEntries != null) {
      _entries = providerEntries;
    }
    final entriesLoading = asyncEntries.isLoading && providerEntries == null;
    final now = DateTime.now();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
      resizeToAvoidBottomInset: false,
      body: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'SF Pro'),
        child: Stack(
          children: [
            const Positioned.fill(child: PrivateSpaceBackground()),
            AnimatedContainer(
              duration: const Duration(milliseconds: 1450),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _stage == _Stage.idle
                      ? [
                          const Color(0x2A08111F),
                          const Color(0x44101828),
                        ]
                      : [
                          const Color(0x9E060C16),
                          const Color(0xD60A111D),
                        ],
                ),
              ),
            ),
            if (_stage == _Stage.idle)
              Positioned(
                left: MediaQuery.of(context).size.width * 0.18,
                top: MediaQuery.of(context).size.height * 0.12,
                child: _BrightStar(onTap: _openFromStar),
              ),
            if (_stage == _Stage.transitioning)
              const Positioned.fill(child: PrivateSpaceParticleOverlay()),
            AnimatedSwitcher(
              duration: _stageSwitchDuration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              child: switch (_stage) {
                _Stage.notepad => _buildNotepad(now),
                _Stage.history => _buildHistory(entriesLoading: entriesLoading),
                _ => const SizedBox.shrink(),
              },
            ),
            if (_showMarkBoard) _buildMarkBoardOverlay(),
            if (_stage == _Stage.idle)
              Positioned(
                right: 24,
                bottom: 34,
                child: TimerMusicButton(
                  rotationAnimation: _musicRotationController,
                  onTap: _toggleHomeMusicFromSubPage,
                ),
              ),
            if (_stage == _Stage.notepad)
              Positioned(
                right: 24,
                bottom: 34,
                child: TimerMusicButton(
                  rotationAnimation: _musicRotationController,
                  onTap: _toggleHomeMusicFromSubPage,
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildNotepad(DateTime now) {
    return PrivateSpaceNotepadStage(
      now: now,
      docController: _docController,
      noteScrollController: _noteScrollController,
      onBack: _handleBack,
      onUndo: _undoNoteEdit,
      onRedo: _redoNoteEdit,
      onSave: _saveNote,
      onPickImage: _pickImage,
      onAddVoiceBlock: _addVoiceBlock,
      onVoicePlayTap: _onVoicePlaybackToggle,
      onVoiceRename: _renameVoiceAt,
      onVoiceDelete: _deleteVoiceAt,
      onImageDoubleTap: _openImagePreview,
      onImageLongPress: _showImageQuickActions,
      onImageCopy: _copyImageAt,
      onImageCut: _cutImageAt,
      onImageDelete: _deleteImageAt,
      onContentChanged: () => setState(() {}),
    );
  }

  Widget _buildHistory({required bool entriesLoading}) {
    return SafeArea(
      key: const ValueKey<String>('history'),
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (!_selectionMode)
                      _CircleIconButton(
                        icon: Icons.chevron_left,
                        onTap: () => _handleBack(),
                      )
                    else
                      TextButton(
                        onPressed: _clearSelection,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFFFDE68A)),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _selectionMode
                          ? '${_selectedEntries.length} Selected'
                          : 'Entries',
                      style: const TextStyle(
                        color: Color(0xFFFEF3C7),
                        fontSize: 17,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 48,
                      child: _selectionMode
                          ? null
                          : Align(
                              alignment: Alignment.centerRight,
                              child: TimerMusicButton(
                                rotationAnimation: _musicRotationController,
                                onTap: _toggleHomeMusicFromSubPage,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: entriesLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFDE68A)),
                      )
                    : _sortedEntries.isEmpty
                        ? const Center(
                            child: Text(
                              'No entries yet. Tap the + button to start.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          )
                        : ListView.builder(
                            controller: _historyListScrollController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                            itemCount: _sortedEntries.length,
                            itemBuilder: (_, i) {
                              final entry = _sortedEntries[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: PrivateSpaceHistoryEntryCard(
                                  key: ValueKey<String>('history-${entry.id}'),
                                  entry: entry,
                                  categoryColor: _categoryForEntry(entry)?.color,
                                  selectionMode: _selectionMode,
                                  selected:
                                      _selectedEntries.contains(entry.id),
                                  onTap: () {
                                    if (_selectionMode) {
                                      _toggleSelect(entry.id);
                                    } else {
                                      _editFromHistory(entry);
                                    }
                                  },
                                  onLongPress: () => _toggleSelect(
                                    entry.id,
                                    forceStartSelection: true,
                                  ),
                                  onPin: () => _togglePin(entry.id),
                                  onDelete: () => _deleteEntry(entry.id),
                                  swipeCloseNonce:
                                      _historySwipeCloseEntryId == entry.id
                                          ? _historySwipeCloseNonce
                                          : 0,
                                  onShare: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: _entryPreview(entry)),
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Copied to clipboard.',
                                          style: AppTypography.body(),
                                        ),
                                      ),
                                    );
                                  },
                                  isPinned: _isPinned(entry),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          if (!_selectionMode)
            Positioned(
              right: 24,
              bottom: 34,
              child: FloatingActionButton(
                backgroundColor: const Color(0x33FACC15),
                foregroundColor: const Color(0xFFFFF8DB),
                onPressed: _createNoteFromHistory,
                child: const Icon(Icons.add),
              ),
            ),
          if (_selectionMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                color: const Color(0xE60A0510),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _HistoryBottomAction(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      onTap: () async {
                        final selected = _entries
                            .where((entry) => _selectedEntries.contains(entry.id))
                            .map(_entryPreview)
                            .join('\n\n----------\n\n');
                        await Clipboard.setData(ClipboardData(text: selected));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Copied to clipboard.',
                              style: AppTypography.body(),
                            ),
                          ),
                        );
                      },
                    ),
                    _HistoryBottomAction(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      onTap: _batchDeleteSelected,
                    ),
                    _HistoryBottomAction(
                      icon: Icons.folder_outlined,
                      label: 'Category',
                      onTap: _openMarkBoard,
                    ),
                    _HistoryBottomAction(
                      icon: Icons.checklist_rtl,
                      label: 'Select All',
                      onTap: _toggleSelectAll,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarkBoardOverlay() {
    return PrivateSpaceCategoriesOverlay(
      historyScrollController: _categoryPanelScrollController,
      categories: _categories.map((c) => c.toViewData()).toList(),
      isAddingCategory: _isAddingCategory,
      showDeleteForCategoryId: _showDeleteForCategoryId,
      categoryController: _categoryController,
      categoryFocusNode: _categoryFocusNode,
      onClose: () {
        setState(() {
          _showMarkBoard = false;
          _isAddingCategory = false;
          _showDeleteForCategoryId = null;
          _categoryController.clear();
        });
      },
      onCancelAddCategory: () {
        setState(() {
          _isAddingCategory = false;
          _categoryController.clear();
        });
      },
      onSaveCategory: _saveCategory,
      onStartAddCategory: _startAddingCategory,
      onDeleteCategory: _deleteCategory,
      onShowDeleteCategory: (categoryId) {
        setState(() {
          _showDeleteForCategoryId = categoryId;
        });
      },
      onDismissDeleteCategory: () {
        setState(() => _showDeleteForCategoryId = null);
      },
      onApplyCategory: (category) {
        final hit = _categories.where((c) => c.id == category.id).firstOrNull;
        if (hit == null) return;
        _applyCategory(hit);
      },
    );
  }
}


class _HistoryBottomAction extends StatelessWidget {
  const _HistoryBottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: PrivateNoteImage(path: path, fit: BoxFit.contain, brokenIconSize: 72),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted = false;
  final bool compact = false;
  final bool mini = false;
  final bool enabled = true;

  @override
  Widget build(BuildContext context) {
    final buttonSize = mini
        ? 34.0
        : (compact ? 44.0 : 46.0);
    final iconSize = mini
        ? 16.0
        : (compact ? 20.0 : 24.0);

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: highlighted
            ? const Color(0x301C2430)
            : const Color(0x2A111A24),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            border: Border.all(
              color: highlighted
                  ? const Color(0xA9E2BE57)
                  : const Color(0x82BC983A),
              width: 1,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0x669F7B24).withValues(
                  alpha: highlighted ? 0.18 : 0.10,
                ),
                blurRadius: mini ? 8 : (compact ? 10 : 12),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: iconSize,
            color:
                highlighted ? const Color(0xFFF5E8BF) : const Color(0xFFE2BE57),
          ),
        ),
      ),
    ),
    );
  }
}

class _BrightStar extends StatefulWidget {
  const _BrightStar({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BrightStar> createState() => _BrightStarState();
}

class _BrightStarState extends State<_BrightStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          final eased =
              CurvedAnimation(parent: _controller, curve: Curves.easeInOut).value;
          final pulse = Curves.easeInOutSine.transform(eased);
          final t = 0.18 + (pulse * 0.82);
          final glow = 0.30 + (pulse * 0.95);
          return SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 7.8 + 3.3 * t,
                  height: 7.8 + 3.3 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFFACC15).withValues(alpha: 0.22 * glow),
                        blurRadius: 16,
                        spreadRadius: 3.2,
                      ),
                      BoxShadow(
                        color:
                            const Color(0xFFFFF2A8).withValues(alpha: 0.34 * glow),
                        blurRadius: 7,
                        spreadRadius: 1.0,
                      ),
                    ],
                  ),
                ),
                Opacity(
                  opacity: 0.62 + (pulse * 0.30),
                  child: Container(
                    width: 20 + 8.0 * t,
                    height: 0.78 + 0.24 * t,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          const Color(0xFFFFF8DB),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.38, 1.0],
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: 0.62 + (pulse * 0.30),
                  child: Container(
                    width: 0.78 + 0.24 * t,
                    height: 20 + 8.0 * t,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          const Color(0xFFFFF8DB),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.38, 1.0],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 3.5 + 1.0 * t,
                  height: 3.5 + 1.0 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.90 + (pulse * 0.10)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.62 + (pulse * 0.18)),
                        blurRadius: 2.4,
                        spreadRadius: 0.9,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 7,
                  left: 7,
                  child: Opacity(
                    opacity: 0.52 + (pulse * 0.30),
                    child: _StarDot(t: t, size: 0.8, baseAlpha: 0.24),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 8,
                  child: Opacity(
                    opacity: 0.58 + (pulse * 0.28),
                    child: _StarDot(t: 1 - t, size: 1.1, baseAlpha: 0.36),
                  ),
                ),
                Positioned(
                  bottom: 7,
                  left: 9,
                  child: Opacity(
                    opacity: 0.50 + (pulse * 0.26),
                    child: _StarDot(t: 1 - t, size: 1.0, baseAlpha: 0.30),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 7,
                  child: Opacity(
                    opacity: 0.44 + (pulse * 0.24),
                    child: _StarDot(t: t, size: 0.75, baseAlpha: 0.18),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StarDot extends StatelessWidget {
  const _StarDot({
    required this.t,
    required this.size,
    required this.baseAlpha,
  });

  final double t;
  final double size;
  final double baseAlpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + size * t,
      height: size + size * t,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: baseAlpha + (0.4 * t)),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFACC15).withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

