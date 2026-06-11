import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pupu/features/private_space/private_entry_sort.dart';
import 'package:pupu/features/private_space/private_note_blocks.dart';
import 'package:pupu/features/private_space/private_note_document_controller.dart';
import 'package:pupu/features/private_space/private_note_editor.dart';
import 'package:pupu/features/private_space/private_space_clipboard.dart';
import 'package:pupu/features/private_space/private_space_history.dart';
import 'package:pupu/features/private_space/private_space_ui.dart';
import 'package:pupu/features/private_space/private_voice_sheet.dart';
import 'package:pupu/features/private_space/private_space_background.dart';
import 'package:pupu/features/private_space/private_space_notepad.dart';
import 'package:pupu/features/private_space/private_space_categories.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';
import 'package:pupu/services/local_storage.dart';
import 'package:pupu/services/private_media_storage.dart';
import 'package:pupu/services/private_permission_helper.dart';
import 'package:pupu/providers/entries_provider.dart';

enum _Stage { idle, transitioning, notepad, history }

enum _ImageInsertAction { gallery, camera }

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
  static const int _maxImagesPerNote = 30;
  static const int _maxImageFileBytes = 12 * 1024 * 1024;

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
  final ScrollController _historyScrollController = ScrollController();
  final Random _random = Random();

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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    PrivateVoicePlayer.instance.stop();
    _docController?.dispose();
    _noteScrollController.dispose();
    _historyScrollController.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  List<PrivateEntry> get _sortedEntries => sortPrivateEntriesForHistory(_entries);

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
        _focusEditorAfterOpen();
      }
    });
  }

  /// Disposes the note controller. When [deferred] is true, teardown runs after
  /// the next frame so TextFields are unmounted first (avoids focus-tree asserts).
  void _disposeDocController({bool deferred = false}) {
    final controller = _docController;
    if (controller == null) return;
    controller.removeListener(_onDocControllerChanged);
    _docController = null;
    if (deferred) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.disposeController();
      });
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

  void _focusEditorAfterOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _docController?.focusFirstText();
    });
  }

  void _exitNotepad() {
    PrivateVoicePlayer.instance.stop();
    FocusManager.instance.primaryFocus?.unfocus();
    _editingEntryId = null;
    _disposeDocController(deferred: true);
    setState(() {
      _stage = _entries.isNotEmpty ? _Stage.history : _Stage.idle;
    });
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
      if (mounted) _exitNotepad();
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
    FocusManager.instance.primaryFocus?.unfocus();
    _editingEntryId = null;
    _disposeDocController(deferred: true);
    setState(() {
      _stage = _Stage.history;
    });
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
          return 'Voice note';
        case PrivateDocImageOp():
          return 'Photo note';
        case PrivateDocTextOp(:final text):
          if (text.trim().isNotEmpty) return _deriveTitle(text);
      }
    }
    return 'Untitled';
  }

  Future<void> _pickImage() async {
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
    final permission = source == ImageSource.camera
        ? PrivatePermissionKind.camera
        : PrivatePermissionKind.photoLibrary;
    if (!await PrivatePermissionHelper.ensure(context, permission)) return;

    if ((_docController?.imageCount ?? 0) >= _maxImagesPerNote) {
      _showPrivateSnackBar('Maximum $_maxImagesPerNote images per note.');
      return;
    }

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

    final id = DateTime.now().microsecondsSinceEpoch.toString();

    String path;
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _showPrivateSnackBar('Selected image is unavailable.');
        return;
      }
      if (bytes.length > _maxImageFileBytes) {
        _showPrivateSnackBar('Image is too large (max 12MB).');
        return;
      }
      final ext = _imageExtensionFromPath(picked.path);
      path = await PrivateMediaStorage.persistImageBytes(
        bytes,
        id: id,
        extension: ext,
      );
    } on FileSystemException {
      _showPrivateSnackBar('Failed to save image file.');
      return;
    } catch (_) {
      _showPrivateSnackBar('Image import failed. Please try again.');
      return;
    }

    if (!mounted) return;
    _insertImagePath(
      id: id,
      path: path,
      source: source == ImageSource.camera ? 'camera' : 'gallery',
    );
  }

  void _insertImagePath({
    required String id,
    required String path,
    required String source,
  }) {
    _docController?.insertImageAtCaret(
      PrivateImageData(
        id: 'img_$id',
        path: path,
        source: source,
      ),
    );
    setState(() {});
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
    // Return to editor context after fullscreen preview is dismissed.
    _focusEditorAfterOpen();
  }

  Future<void> _showImageQuickActions(int opIndex, PrivateImageData image) async {
    const copy = 'copy';
    const cut = 'cut';
    const delete = 'delete';

    final action = await showPrivateActionSheet<String>(
      context: context,
      actions: const [
        PrivateSpaceAction(value: copy, icon: Icons.copy_outlined, label: 'Copy image'),
        PrivateSpaceAction(value: cut, icon: Icons.content_cut_outlined, label: 'Cut image'),
        PrivateSpaceAction(value: delete, icon: Icons.delete_outline, label: 'Delete image'),
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

  void _showPrivateSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addVoiceBlock() async {
    final voice = await showModalBottomSheet<PrivateVoiceData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PrivateVoiceRecordSheet(),
    );
    if (voice == null || !mounted) return;
    _docController?.insertVoiceAtCaret(voice);
    setState(() {});
  }

  Future<void> _renameVoiceAt(int opIndex, PrivateVoiceData voice) async {
    final name = await showPrivateTextDialog(
      context: context,
      title: 'Rename voice',
      hintText: 'Optional title',
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
    _resetEditor();
    _editingEntryId = null;
    setState(() => _stage = _Stage.notepad);
    _focusEditorAfterOpen();
  }

  void _editFromHistory(PrivateEntry entry) {
    _resetEditor(entry);
    _editingEntryId = entry.id;
    setState(() => _stage = _Stage.notepad);
    _focusEditorAfterOpen();
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
      if (_historyScrollController.hasClients) {
        _historyScrollController.animateTo(
          _historyScrollController.position.maxScrollExtent,
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
    final providerEntries = asyncEntries.valueOrNull;
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
              duration: const Duration(milliseconds: 820),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              child: switch (_stage) {
                _Stage.notepad => _buildNotepad(now),
                _Stage.history => _buildHistory(entriesLoading: entriesLoading),
                _ => const SizedBox.shrink(),
              },
            ),
            if (_showMarkBoard) _buildMarkBoardOverlay(),
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
                          ? '${_selectedEntries.length} SELECTED'
                          : 'RECORDS',
                      style: const TextStyle(
                        color: Color(0xFFFEF3C7),
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
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
                                      const SnackBar(
                                        content: Text(
                                          'Copied. You can share it now.',
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
                          const SnackBar(
                            content: Text('Copied. You can share it now.'),
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
                      icon: Icons.sell_outlined,
                      label: 'Mark',
                      onTap: _openMarkBoard,
                    ),
                    _HistoryBottomAction(
                      icon: Icons.checklist_rtl,
                      label: 'All',
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
      historyScrollController: _historyScrollController,
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
    if (path.startsWith('assets/')) {
      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: Image.asset(path, fit: BoxFit.contain),
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      return const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 72);
    }
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: Image.file(file, fit: BoxFit.contain),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
    this.compact = false,
    this.mini = false,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;
  final bool compact;
  final bool mini;
  final bool enabled;

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

class _NoteBackgroundGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient1 = RadialGradient(
      center: const Alignment(0, -0.6),
      radius: 1.5,
      colors: [
        const Color(0xFFFFDC64).withValues(alpha: 0.25),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4],
    );

    final gradient2 = RadialGradient(
      center: const Alignment(0, -0.6),
      radius: 1.5,
      colors: [
        Colors.white.withValues(alpha: 0.15),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4],
    );

    final paint1 = Paint()..shader = gradient1.createShader(Offset.zero & size);
    final paint2 = Paint()..shader = gradient2.createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint1);
    canvas.drawRect(Offset.zero & size, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        builder: (_, __) {
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

