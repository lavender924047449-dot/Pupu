import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pupu/features/private_space/private_space_clipboard.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';

/// Caret position within the linearized document stream.
class PrivateDocCaret {
  const PrivateDocCaret({required this.opIndex, required this.textOffset});

  final int opIndex;
  final int textOffset;
}

/// Minimal linear selection snapshot (anchor/focus) for semantic bridge.
class PrivateDocSelectionState {
  const PrivateDocSelectionState({
    required this.anchorOffset,
    required this.focusOffset,
  });

  final int anchorOffset;
  final int focusOffset;

  bool get isCollapsed => anchorOffset == focusOffset;

  int get startOffset => math.min(anchorOffset, focusOffset);
  int get endOffset => math.max(anchorOffset, focusOffset);
}

/// Mutable v2 document with caret-aware inline inserts (segment-based, no Quill).
class PrivateNoteDocumentController extends ChangeNotifier {
  PrivateNoteDocumentController({
    PrivateNoteDocument? initial,
    bool showEntryPlaceholder = false,
  })  : _showEntryPlaceholderEnabled = showEntryPlaceholder,
        _document = initial ?? PrivateNoteDocument.empty {
    _document = _document.copyWith(ops: _normalizeOps(_document.ops));
    _ensureEditingSurface();
    _bindTextControllers();
    _clampCaretToDocument();
  }

  /// True only for brand-new blank notes; cleared permanently after first edit.
  final bool _showEntryPlaceholderEnabled;
  bool _entryPlaceholderDismissed = false;

  /// Whether the first-line entry placeholder should render in the editor.
  bool get showEntryPlaceholder =>
      _showEntryPlaceholderEnabled && !_entryPlaceholderDismissed;

  /// Hides the entry placeholder for the rest of this editing session.
  void dismissEntryPlaceholder() {
    if (!_showEntryPlaceholderEnabled || _entryPlaceholderDismissed) return;
    _entryPlaceholderDismissed = true;
    notifyListeners();
  }

  PrivateNoteDocument _document;
  PrivateDocCaret _caret = const PrivateDocCaret(opIndex: 0, textOffset: 0);
  PrivateDocSelectionState _selectionState =
      const PrivateDocSelectionState(anchorOffset: 0, focusOffset: 0);
  int _focusedTextIndex = 0;
  int _editGeneration = 0;
  static const int _maxUndoSteps = 20;
  final List<_HistoryEntry> _undoStack = [];
  final List<_HistoryEntry> _redoStack = [];
  final List<TextEditingController> _textControllers = [];
  final List<FocusNode> _textFocusNodes = [];
  /// Invisible field used only to keep the soft keyboard open on embed carets.
  final FocusNode _embedKeyboardFocusNode = FocusNode();
  final TextEditingController _embedKeyboardController = TextEditingController();

  PrivateNoteDocument get document => _document;
  PrivateDocCaret get caret => _caret;
  PrivateDocSelectionState get selectionState => _selectionState;
  List<PrivateDocOp> get ops => _document.ops;

  List<TextEditingController> get textControllers =>
      List.unmodifiable(_textControllers);
  /// True when the document has no text segments (embed-only note).
  bool get hasTextSegments =>
      _document.ops.any((op) => op is PrivateDocTextOp);

  /// Map a list op index to the text-field index used by the editor, or null.
  int? textFieldIndexForOp(int opIndex) {
    if (opIndex < 0 || opIndex >= _document.ops.length) return null;
    if (_document.ops[opIndex] is! PrivateDocTextOp) return null;
    var textCount = 0;
    for (var i = 0; i < opIndex; i++) {
      if (_document.ops[i] is PrivateDocTextOp) textCount++;
    }
    return textCount;
  }

  TextEditingController? textControllerAt(int textFieldIndex) {
    if (textFieldIndex < 0 || textFieldIndex >= _textControllers.length) {
      return null;
    }
    return _textControllers[textFieldIndex];
  }

  FocusNode? textFocusNodeAt(int textFieldIndex) {
    if (textFieldIndex < 0 || textFieldIndex >= _textFocusNodes.length) {
      return null;
    }
    return _textFocusNodes[textFieldIndex];
  }

  FocusNode get embedKeyboardFocusNode => _embedKeyboardFocusNode;
  TextEditingController get embedKeyboardController => _embedKeyboardController;

  /// Index of the text field that currently owns keyboard focus.
  int get focusedTextFieldIndex => _focusedTextIndex;

  bool get isCaretOnEmbed {
    if (_caret.opIndex < 0 || _caret.opIndex >= _document.ops.length) {
      return false;
    }
    return _document.ops[_caret.opIndex].isEmbed;
  }

  /// Semantic length of the current document view used for linear caret logic.
  int get semanticLength => _document.semanticLength;

  String opKeyAt(int opIndex) {
    if (opIndex < 0 || opIndex >= _document.ops.length) return 'op_invalid';
    final op = _document.ops[opIndex];
    return switch (op) {
      PrivateDocTextOp() => 'text_$opIndex',
      PrivateDocImageOp(:final image) => 'image_${image.id}_$opIndex',
      PrivateDocVoiceOp(:final voice) => 'voice_${voice.id}_$opIndex',
    };
  }

  void disposeController() {
    for (final c in _textControllers) {
      c.dispose();
    }
    for (final f in _textFocusNodes) {
      f.dispose();
    }
    _embedKeyboardFocusNode.dispose();
    _embedKeyboardController.dispose();
    _textControllers.clear();
    _textFocusNodes.clear();
    clearHistory();
    dispose();
  }

  /// Rebuild from saved entry document.
  void load(PrivateNoteDocument doc) {
    _bumpEditGeneration();
    _disposeTextBindings();
    clearHistory();
    _document = doc.ops.isEmpty ? PrivateNoteDocument.empty : doc;
    _document = _document.copyWith(ops: _normalizeOps(_document.ops));
    _ensureEditingSurface();
    _caret = _document.lastCursorAnchor == null
        ? const PrivateDocCaret(opIndex: 0, textOffset: 0)
        : PrivateDocCaret(
            opIndex: _document.lastCursorAnchor!.opIndex,
            textOffset: _document.lastCursorAnchor!.textOffset,
          );
    _bindTextControllers();
    _clampCaretToDocument();
    notifyListeners();
  }

  PrivateNoteDocument buildDocument() {
    final rebuilt = <PrivateDocOp>[];
    var textIndex = 0;
    for (final op in _document.ops) {
      if (op is PrivateDocTextOp) {
        if (textIndex < _textControllers.length) {
          rebuilt.add(PrivateDocTextOp(_textControllers[textIndex].text));
        } else {
          rebuilt.add(op);
        }
        textIndex++;
      } else {
        rebuilt.add(op);
      }
    }
    final merged = _normalizeOps(rebuilt);
    final safeCaret = _clampedCaretForOps(_caret, merged);
    return PrivateNoteDocument(
      ops: merged,
      lastCursorAnchor: _caretToAnchor(safeCaret),
    );
  }

  bool get isEmpty {
    final doc = buildDocument();
    if (doc.ops.isEmpty) return true;
    if (doc.ops.every((op) => op is PrivateDocTextOp && op.text.trim().isEmpty)) {
      return !doc.ops.any((op) => op is! PrivateDocTextOp);
    }
    return false;
  }

  String plainTextPreview() {
    final buffer = StringBuffer();
    for (final op in buildDocument().ops) {
      switch (op) {
        case PrivateDocTextOp(:final text):
          if (text.trim().isNotEmpty) buffer.writeln(text.trim());
        case PrivateDocImageOp():
          buffer.writeln('[Image]');
        case PrivateDocVoiceOp(:final voice):
          final s = (voice.durationMs / 1000).round();
          buffer.writeln(
            voice.title?.trim().isNotEmpty == true
                ? voice.title!
                : '[Voice ${s}s]',
          );
      }
    }
    return buffer.toString().trim();
  }

  int get imageCount => buildDocument().imageCount;

  int get voiceCount => buildDocument().voiceCount;

  /// JSON snapshot of ops at last load/save — cursor moves do not affect this.
  String? _savedOpsJson;

  /// Record current document ops as the saved baseline (after open or persist).
  void captureSavedBaseline() {
    _savedOpsJson = _opsJson(buildDocument());
  }

  /// True when ops differ from the baseline captured on open.
  bool get hasUnsavedEdits =>
      _savedOpsJson != null && _opsJson(buildDocument()) != _savedOpsJson;

  static String _opsJson(PrivateNoteDocument doc) =>
      jsonEncode(doc.ops.map((e) => e.toJson()).toList());

  void focusFirstText({bool requestKeyboard = true}) {
    if (_textFocusNodes.isEmpty) return;
    final firstTextOpIndex =
        _document.ops.indexWhere((op) => op is PrivateDocTextOp);
    if (firstTextOpIndex >= 0) {
      _focusedTextIndex = textFieldIndexForOp(firstTextOpIndex) ?? 0;
      _caret = PrivateDocCaret(opIndex: firstTextOpIndex, textOffset: 0);
    } else {
      _focusedTextIndex = 0;
      _caret = const PrivateDocCaret(opIndex: 0, textOffset: 0);
    }
    if (requestKeyboard) {
      _textFocusNodes[_focusedTextIndex].requestFocus();
    }
    notifyListeners();
  }

  /// Lazily creates a text segment at [opIndex] when the user taps between embeds.
  void ensureTextOpAt(int opIndex) {
    _syncTextFromControllers();
    final ops = List<PrivateDocOp>.from(_document.ops);
    if (opIndex < 0 || opIndex > ops.length) return;
    if (opIndex < ops.length && ops[opIndex] is PrivateDocTextOp) {
      final textIndex = textFieldIndexForOp(opIndex);
      if (textIndex != null) {
        _focusedTextIndex = textIndex;
        _caret = PrivateDocCaret(opIndex: opIndex, textOffset: 0);
        _textFocusNodes[textIndex].requestFocus();
        notifyListeners();
      }
      return;
    }
    _recordHistorySnapshot();
    _bumpEditGeneration();
    ops.insert(opIndex, const PrivateDocTextOp(''));
    _document = _document.copyWith(ops: ops);
    _bindTextControllers();
    final textIndex = textFieldIndexForOp(opIndex);
    if (textIndex != null) {
      _focusedTextIndex = textIndex;
      _caret = PrivateDocCaret(opIndex: opIndex, textOffset: 0);
      _textFocusNodes[textIndex].requestFocus();
    }
    notifyListeners();
  }

  void onTextFocus(int textFieldIndex) {
    final safeIndex = _clampTextFieldIndex(textFieldIndex);
    if (_textFocusNodes.isEmpty || safeIndex >= _textFocusNodes.length) {
      return;
    }
    _focusedTextIndex = safeIndex;
    _caret = _caretForTextField(_focusedTextIndex);
    notifyListeners();
  }

  /// Sets semantic selection directly in linear document offsets.
  void setSelectionBySemanticOffsets({
    required int anchorOffset,
    required int focusOffset,
  }) {
    final max = _document.semanticLength;
    final clampedAnchor = anchorOffset.clamp(0, max);
    final clampedFocus = focusOffset.clamp(0, max);
    _selectionState = PrivateDocSelectionState(
      anchorOffset: clampedAnchor,
      focusOffset: clampedFocus,
    );

    _caret = _caretForLinearOffset(clampedFocus);
    notifyListeners();
  }

  /// Move the logical caret and sync focus to the matching text field or embed.
  void setCaret(PrivateDocCaret caret, {bool requestFocus = true}) {
    _syncTextFromControllers();
    _caret = _clampedCaretForOps(caret, _document.ops);
    final linear = _linearOffsetForCaret(_caret);
    _selectionState =
        PrivateDocSelectionState(anchorOffset: linear, focusOffset: linear);
    if (requestFocus) {
      _focusForCaret(_caret, generation: _editGeneration);
    }
    notifyListeners();
  }

  void placeCaretBeforeEmbed(int opIndex) {
    setCaret(PrivateDocCaret(opIndex: opIndex, textOffset: 0));
  }

  void placeCaretAfterEmbed(int opIndex) {
    setCaret(PrivateDocCaret(opIndex: opIndex, textOffset: 1));
  }

  void moveCaretLeft() {
    final offset = _linearOffsetForCaret(_caret);
    if (offset <= 0) return;
    setCaret(_caretForLinearOffset(offset - 1));
  }

  void moveCaretRight() {
    final offset = _linearOffsetForCaret(_caret);
    if (offset >= _document.semanticLength) return;
    setCaret(_caretForLinearOffset(offset + 1));
  }

  bool handleArrowLeftFromTextField(int textFieldIndex) {
    _syncTextFromControllers();
    final field = _textControllers[textFieldIndex];
    if (!field.selection.isCollapsed || field.selection.baseOffset > 0) {
      return false;
    }
    final caret = _caretForTextField(textFieldIndex);
    final offset = _linearOffsetForCaret(caret);
    if (offset <= 0) return false;
    setCaret(_caretForLinearOffset(offset - 1));
    return true;
  }

  bool handleArrowRightFromTextField(int textFieldIndex) {
    _syncTextFromControllers();
    final field = _textControllers[textFieldIndex];
    if (!field.selection.isCollapsed ||
        field.selection.baseOffset < field.text.length) {
      return false;
    }
    final caret = _caretForTextField(textFieldIndex);
    final offset = _linearOffsetForCaret(caret);
    if (offset >= _document.semanticLength) return false;
    setCaret(_caretForLinearOffset(offset + 1));
    return true;
  }

  bool handleArrowUpFromTextField(int textFieldIndex) {
    if (textFieldIndex <= 0) return false;
    _syncTextFromControllers();
    final offset = _textControllers[textFieldIndex].selection.baseOffset;
    final prevOpIndex = _opIndexForTextField(textFieldIndex - 1);
    final prevText = _document.ops[prevOpIndex] as PrivateDocTextOp;
    setCaret(
      PrivateDocCaret(
        opIndex: prevOpIndex,
        textOffset: offset.clamp(0, prevText.text.length),
      ),
    );
    return true;
  }

  bool handleArrowDownFromTextField(int textFieldIndex) {
    if (textFieldIndex >= _textControllers.length - 1) return false;
    _syncTextFromControllers();
    final offset = _textControllers[textFieldIndex].selection.baseOffset;
    final nextOpIndex = _opIndexForTextField(textFieldIndex + 1);
    final nextText = _document.ops[nextOpIndex] as PrivateDocTextOp;
    setCaret(
      PrivateDocCaret(
        opIndex: nextOpIndex,
        textOffset: offset.clamp(0, nextText.text.length),
      ),
    );
    return true;
  }

  bool handleDeleteBackwardFromTextField(int textFieldIndex) {
    _syncTextFromControllers();
    if (!_selectionState.isCollapsed) {
      return deleteSelectionBySemanticRange();
    }
    final field = _textControllers[textFieldIndex];
    if (!field.selection.isCollapsed) {
      return _deleteSelectionInTextField(textFieldIndex);
    }
    if (field.selection.baseOffset > 0) {
      return false;
    }
    return _deleteBackwardFromCaret(_caretForTextField(textFieldIndex));
  }

  bool handleDeleteForwardFromTextField(int textFieldIndex) {
    _syncTextFromControllers();
    if (!_selectionState.isCollapsed) {
      return deleteSelectionBySemanticRange();
    }
    final field = _textControllers[textFieldIndex];
    if (!field.selection.isCollapsed) {
      return _deleteSelectionInTextField(textFieldIndex);
    }
    if (field.selection.baseOffset < field.text.length) {
      return false;
    }
    return _deleteForwardFromCaret(_caretForTextField(textFieldIndex));
  }

  bool handleNewlineFromTextField(int textFieldIndex) {
    _syncTextFromControllers();
    final field = _textControllers[textFieldIndex];
    if (!field.selection.isCollapsed) return false;
    final caret = _caretForTextField(textFieldIndex);
    final op = _document.ops[caret.opIndex];
    if (op is! PrivateDocTextOp) return false;
    if (caret.textOffset > 0 && caret.textOffset < op.text.length) {
      return false;
    }
    return insertNewlineAtCaret(caret);
  }

  bool insertNewlineAtCaret([PrivateDocCaret? fromCaret]) {
    _syncTextFromControllers();
    final caret = _clampedCaretForOps(fromCaret ?? _caret, _document.ops);
    final ops = _document.ops;
    if (caret.opIndex >= ops.length) return false;
    final op = ops[caret.opIndex];

    if (op is PrivateDocTextOp) {
      if (caret.textOffset == op.text.length &&
          caret.opIndex + 1 < ops.length &&
          ops[caret.opIndex + 1].isEmbed) {
        _insertCharInTextOp(caret.opIndex, '\n', at: caret.textOffset);
        return true;
      }
      if (caret.textOffset == 0 &&
          caret.opIndex > 0 &&
          ops[caret.opIndex - 1].isEmbed) {
        if (_isEmbedBoundaryTextSlot(op.text)) return false;
        return _insertEmptyTextOpAt(caret.opIndex);
      }
      return false;
    }

    if (op.isEmbed) {
      if (caret.textOffset == 1) {
        final nextIndex = caret.opIndex + 1;
        if (nextIndex < ops.length && ops[nextIndex] is PrivateDocTextOp) {
          final nextText = (ops[nextIndex] as PrivateDocTextOp).text;
          if (_isEmbedBoundaryTextSlot(nextText)) {
            setCaret(PrivateDocCaret(opIndex: nextIndex, textOffset: 0));
            return true;
          }
        }
        return _insertEmptyTextOpAt(nextIndex);
      }
      if (caret.textOffset == 0) {
        if (caret.opIndex > 0 && ops[caret.opIndex - 1] is PrivateDocTextOp) {
          final prevIndex = caret.opIndex - 1;
          final prevText = (ops[prevIndex] as PrivateDocTextOp).text;
          if (_isEmbedBoundaryTextSlot(prevText)) return false;
          _insertCharInTextOp(prevIndex, '\n', at: prevText.length);
          return true;
        }
        return _insertEmptyTextOpAt(caret.opIndex);
      }
    }
    return false;
  }

  bool _deleteSelectionInTextField(int textFieldIndex) {
    _recordHistorySnapshot();
    final safeIndex = _clampTextFieldIndex(textFieldIndex);
    final controller = _textControllers[safeIndex];
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return false;

    final text = controller.text;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    if (start >= end) return false;

    final next = text.replaceRange(start, end, '');
    controller.text = next;
    controller.selection = TextSelection.collapsed(offset: start);

    _focusedTextIndex = safeIndex;
    final opIndex = _opIndexForTextField(safeIndex);
    _caret = PrivateDocCaret(opIndex: opIndex, textOffset: start);
    final linear = _linearOffsetForCaret(_caret);
    _selectionState =
        PrivateDocSelectionState(anchorOffset: linear, focusOffset: linear);

    _syncTextFromControllers();
    notifyListeners();
    return true;
  }

  /// Returns plain-text representation of semantic range
  /// [selectionState.startOffset, selectionState.endOffset).
  ///
  /// Embed ops are represented as placeholders in plain-text output:
  /// image -> [Image], voice -> [Voice].
  String? extractSelectionTextBySemanticRange() {
    _syncTextFromControllers();
    if (_selectionState.isCollapsed) return null;

    final start = _selectionState.startOffset;
    final end = _selectionState.endOffset;
    if (end <= start) return null;

    var cursor = 0;
    final buffer = StringBuffer();

    for (final op in _document.ops) {
      final len = op.semanticLength;
      final opStart = cursor;
      final opEnd = cursor + len;
      cursor = opEnd;

      if (len == 0 || end <= opStart || start >= opEnd) {
        continue;
      }

      if (op is PrivateDocTextOp) {
        final localStart = math.max(0, start - opStart);
        final localEnd = math.min(op.text.length, end - opStart);
        if (localStart < localEnd) {
          buffer.write(op.text.substring(localStart, localEnd));
        }
        continue;
      }

      if (op is PrivateDocImageOp) {
        buffer.write('[Image]');
        continue;
      }
      if (op is PrivateDocVoiceOp) {
        buffer.write('[Voice]');
      }
    }

    final text = buffer.toString();
    return text.isEmpty ? null : text;
  }

  /// Copy semantic selection via unified path.
  ///
  /// Returns false when there is no non-collapsed semantic selection.
  bool copySelectionBySemanticRangeToClipboard() {
    final copied = extractSelectionTextBySemanticRange();
    if (copied == null) return false;

    PrivateSpaceClipboard.copyText(copied);
    Clipboard.setData(ClipboardData(text: copied));
    return true;
  }

  /// Cut semantic selection via unified path: copy text snapshot, then delete.
  bool cutSelectionBySemanticRangeToClipboard() {
    final copied = extractSelectionTextBySemanticRange();
    if (copied == null) return false;

    PrivateSpaceClipboard.copyText(copied);
    Clipboard.setData(ClipboardData(text: copied));
    return deleteSelectionBySemanticRange();
  }

  /// Convenience entry for UI selection controls.
  bool handleCopy() => copySelectionBySemanticRangeToClipboard();

  /// Convenience entry for UI selection controls.
  bool handleCut() => cutSelectionBySemanticRangeToClipboard();

  /// Deletes semantic range [selectionState.startOffset, selectionState.endOffset).
  ///
  /// Text ranges are removed as substrings; embed ranges remove whole embed ops.
  bool deleteSelectionBySemanticRange({bool recordHistory = true}) {
    if (recordHistory) _recordHistorySnapshot();
    _syncTextFromControllers();
    if (_selectionState.isCollapsed) return false;

    final start = _selectionState.startOffset;
    final end = _selectionState.endOffset;
    if (end <= start) return false;

    final ops = List<PrivateDocOp>.from(_document.ops);
    if (ops.isEmpty) return false;

    var cursor = 0;
    final nextOps = <PrivateDocOp>[];

    for (final op in ops) {
      final len = op.semanticLength;
      final opStart = cursor;
      final opEnd = cursor + len;
      cursor = opEnd;

      if (len == 0 || end <= opStart || start >= opEnd) {
        nextOps.add(op);
        continue;
      }

      if (op is PrivateDocTextOp) {
        final localStart = math.max(0, start - opStart);
        final localEnd = math.min(op.text.length, end - opStart);
        if (localStart >= localEnd) {
          nextOps.add(op);
          continue;
        }
        final updated = op.text.replaceRange(localStart, localEnd, '');
        nextOps.add(PrivateDocTextOp(updated));
        continue;
      }

      // Embed selected by semantic range => remove whole op.
    }

    _document = _document.copyWith(ops: _normalizeOps(nextOps));
    _ensureEditingSurface();
    _bindTextControllers();

    final target = start.clamp(0, _document.semanticLength);
    _caret = _caretForLinearOffset(target);
    final collapsed = _linearOffsetForCaret(_caret);
    _selectionState = PrivateDocSelectionState(
      anchorOffset: collapsed,
      focusOffset: collapsed,
    );

    _focusForCaret(_caret, generation: _editGeneration);
    notifyListeners();
    return true;
  }

  void _insertTextAtCaret(String text, PrivateDocCaret insertCaret) {
    if (text.isEmpty) return;
    _syncTextFromControllers();

    final caret = _clampedCaretForOps(insertCaret, _document.ops);
    if (caret.opIndex >= _document.ops.length) return;
    final op = _document.ops[caret.opIndex];
    if (op is! PrivateDocTextOp) return;

    final at = caret.textOffset.clamp(0, op.text.length);
    final next = op.text.replaceRange(at, at, text);

    final ops = List<PrivateDocOp>.from(_document.ops);
    ops[caret.opIndex] = PrivateDocTextOp(next);
    _document = _document.copyWith(ops: _normalizeOps(ops));
    _ensureEditingSurface();
    _bindTextControllers();

    _caret = PrivateDocCaret(opIndex: caret.opIndex, textOffset: at + text.length);
    final linear = _linearOffsetForCaret(_caret);
    _selectionState =
        PrivateDocSelectionState(anchorOffset: linear, focusOffset: linear);

    _focusForCaret(_caret, generation: _editGeneration);
    notifyListeners();
  }

  /// Inserts [PrivateDocTextOp('')] at [opIndex] and focuses it.
  bool _insertEmptyTextOpAt(int opIndex) {
    _recordHistorySnapshot();
    final nextOps = List<PrivateDocOp>.from(_document.ops)
      ..insert(opIndex, const PrivateDocTextOp(''));
    _document = _document.copyWith(ops: _normalizeOps(nextOps));
    _bindTextControllers();
    setCaret(PrivateDocCaret(opIndex: opIndex, textOffset: 0));
    return true;
  }

  bool _isEmbedBoundaryTextSlot(String text) => text.isEmpty || text == '\n';

  bool handleDeleteBackwardOnEmbed() {
    if (!isCaretOnEmbed || _caret.textOffset != 1) return false;
    return _deleteBackwardFromCaret(_caret);
  }

  bool handleDeleteForwardOnEmbed() {
    if (!isCaretOnEmbed || _caret.textOffset != 0) return false;
    return _deleteForwardFromCaret(_caret);
  }

  bool handleNewlineOnEmbed() => insertNewlineAtCaret(_caret);

  bool handleArrowUpFromEmbed() {
    final opIndex = _caret.opIndex;
    for (var i = opIndex - 1; i >= 0; i--) {
      if (_document.ops[i] is PrivateDocTextOp) {
        final text = (_document.ops[i] as PrivateDocTextOp).text;
        setCaret(PrivateDocCaret(opIndex: i, textOffset: text.length));
        return true;
      }
    }
    return false;
  }

  bool handleArrowDownFromEmbed() {
    final opIndex = _caret.opIndex;
    for (var i = opIndex + 1; i < _document.ops.length; i++) {
      if (_document.ops[i] is PrivateDocTextOp) {
        setCaret(PrivateDocCaret(opIndex: i, textOffset: 0));
        return true;
      }
    }
    return false;
  }

  void onTextSelectionChanged(
    int textFieldIndex, {
    TextSelection? selection,
  }) {
    final safeIndex = _clampTextFieldIndex(textFieldIndex);
    // Ignore selection callbacks from non-focused/disposing text fields.
    // During embed deletion, these callbacks can race with embed-focus restore
    // and incorrectly pull caret back to the first text field.
    if (_textFocusNodes.isEmpty ||
        safeIndex >= _textFocusNodes.length ||
        !_textFocusNodes[safeIndex].hasFocus) {
      return;
    }
    _focusedTextIndex = safeIndex;

    final controller = _textControllers[safeIndex];
    final effectiveSelection = selection ?? controller.selection;

    final anchorOffsetInText = effectiveSelection.isValid
        ? effectiveSelection.baseOffset.clamp(0, controller.text.length)
        : controller.text.length;
    final focusOffsetInText = effectiveSelection.isValid
        ? effectiveSelection.extentOffset.clamp(0, controller.text.length)
        : controller.text.length;

    final opIndex = _opIndexForTextField(_focusedTextIndex);
    final opStartLinear = _linearOffsetForCaret(
      PrivateDocCaret(opIndex: opIndex, textOffset: 0),
    );
    _selectionState = PrivateDocSelectionState(
      anchorOffset: opStartLinear + anchorOffsetInText,
      focusOffset: opStartLinear + focusOffsetInText,
    );

    // Keep existing behavior: caret tracks focus/extent.
    _caret = PrivateDocCaret(opIndex: opIndex, textOffset: focusOffsetInText);
  }

  /// Sync controller state when a text segment changes (including virtual leading text).
  void onTextEdited(int textFieldIndex, String value) {
    dismissEntryPlaceholder();
    _recordHistorySnapshot();
    onTextSelectionChanged(textFieldIndex);
    if (!hasTextSegments && value.isNotEmpty) {
      _document = _document.copyWith(
        ops: [PrivateDocTextOp(value), ..._document.ops],
      );
      _bindTextControllers();
      _focusedTextIndex = 0;
      _caret = PrivateDocCaret(opIndex: 0, textOffset: value.length);
      if (_textControllers.isNotEmpty) {
        _textControllers.first.text = value;
        _textControllers.first.selection =
            TextSelection.collapsed(offset: value.length);
      }
    } else {
      _syncTextFromControllers();
    }
    notifyListeners();
  }

  PrivateDocCaret _caretForTextField(int textFieldIndex) {
    final safeTextIndex = _clampTextFieldIndex(textFieldIndex);
    if (_textControllers.isEmpty) {
      return const PrivateDocCaret(opIndex: 0, textOffset: 0);
    }
    final controller = _textControllers[safeTextIndex];
    final selectionOffset = controller.selection.isValid
        ? controller.selection.baseOffset
        : controller.text.length;
    return PrivateDocCaret(
      opIndex: _opIndexForTextField(safeTextIndex),
      textOffset: selectionOffset.clamp(0, controller.text.length),
    );
  }

  void insertImageAtCaret(PrivateImageData image) {
    insertImagesAtCaret([image]);
  }

  /// Inserts [images] at the current caret in order, as a single undo step.
  void insertImagesAtCaret(List<PrivateImageData> images) {
    if (images.isEmpty) return;
    dismissEntryPlaceholder();
    _recordHistorySnapshot();
    _syncTextFromControllers();

    var insertCaret = _caretForInsert();
    if (!_selectionState.isCollapsed) {
      final start = _selectionState.startOffset;
      if (!deleteSelectionBySemanticRange(recordHistory: false)) return;
      insertCaret = _caretForLinearOffset(start);
    }

    for (final image in images) {
      _insertOpAtCaret(PrivateDocImageOp(image), insertCaret);
      _document = _document.copyWith(ops: _normalizeOps(_document.ops));
      final onEmbed = _caretAfterEmbedInsert(insertCaret, image.id);
      insertCaret = PrivateDocCaret(
        opIndex: onEmbed.opIndex + 1,
        textOffset: 0,
      );
    }

    _ensureEditingSurface();
    _bindTextControllers();
    _caret = _caretAfterEmbedInsert(
      const PrivateDocCaret(opIndex: 0, textOffset: 0),
      images.last.id,
    );
    final linear = _linearOffsetForCaret(_caret);
    _selectionState =
        PrivateDocSelectionState(anchorOffset: linear, focusOffset: linear);
    _focusForCaret(_caret);
    notifyListeners();
  }

  /// Insert plain text at caret, replacing semantic selection when present.
  void pasteTextAtCaret(String text) {
    if (text.isEmpty) return;
    dismissEntryPlaceholder();
    _recordHistorySnapshot();
    _syncTextFromControllers();

    if (!_selectionState.isCollapsed) {
      final start = _selectionState.startOffset;
      if (!deleteSelectionBySemanticRange(recordHistory: false)) return;

      final insertCaret = _caretForLinearOffset(start);
      _insertTextAtCaret(text, insertCaret);
      return;
    }

    final textIndex = _clampTextFieldIndex(_focusedTextIndex);
    final controller = _textControllers[textIndex];
    final selection = controller.selection;
    final value = controller.text;
    final start = selection.start.clamp(0, value.length);
    final end = selection.end.clamp(0, value.length);
    final next = value.replaceRange(start, end, text);
    controller.text = next;
    controller.selection = TextSelection.collapsed(offset: start + text.length);
    _caret = _caretForTextField(textIndex);
    final linear = _linearOffsetForCaret(_caret);
    _selectionState =
        PrivateDocSelectionState(anchorOffset: linear, focusOffset: linear);
    notifyListeners();
  }

  /// Paste an in-app copied payload at the focused caret.
  ///
  /// Priority: image embed payload > internal text payload.
  bool tryPasteInternalImage() {
    final image = PrivateSpaceClipboard.takeCopiedImage();
    if (image != null) {
      insertImageAtCaret(
        PrivateImageData(
          id: 'img_${DateTime.now().microsecondsSinceEpoch}',
          path: image.path,
          source: image.source,
        ),
      );
      return true;
    }

    final text = PrivateSpaceClipboard.takeCopiedText();
    if (text == null || text.isEmpty) return false;
    pasteTextAtCaret(text);
    return true;
  }

  /// Handles system-clipboard JSON image payloads for compatibility with
  /// previously written clipboard data.
  ///
  /// Returns `true` when the clipboard was consumed (image inserted or silently
  /// ignored). Returns `false` when the caller should fall back to plain-text paste.
  bool tryPasteImageFromClipboardText(String? raw) {
    final payload = PrivateSpaceClipboard.decode(raw);
    if (payload == null) return false;
    if (payload is! PrivateClipImagePayload) return true;

    final image = payload.image;
    insertImageAtCaret(
      PrivateImageData(
        id: 'img_${DateTime.now().microsecondsSinceEpoch}',
        path: image.path,
        source: image.source,
      ),
    );
    return true;
  }

  /// Returns `true` when [raw] is a known non-plain payload that should not
  /// reach the TextField default paste path.
  bool shouldSilenceClipboardText(String? raw) {
    if (raw == null || raw.isEmpty) return true;
    if (raw.startsWith(kPrivateClipPrefix)) {
      return PrivateSpaceClipboard.decode(raw) == null;
    }
    if (raw.startsWith(kLegacyImageBase64Prefix)) return true;
    return false;
  }

  void insertVoiceAtCaret(PrivateVoiceData voice) {
    dismissEntryPlaceholder();
    _recordHistorySnapshot();
    _syncTextFromControllers();
    final caret = _caretForInsert();
    _insertOpAtCaret(PrivateDocVoiceOp(voice), caret);
    _document = _document.copyWith(ops: _normalizeOps(_document.ops));
    _ensureEditingSurface();
    _bindTextControllers();
    _caret = _caretAfterEmbedInsert(caret, voice.id);
    _focusForCaret(_caret);
    notifyListeners();
  }

  void removeImageAt(int opIndex) {
    _recordHistorySnapshot();
    _removeOpAt(
      opIndex,
      (op) => op is PrivateDocImageOp,
      preferAdjacentAfter: false,
    );
  }

  void removeVoiceAt(int opIndex) {
    _recordHistorySnapshot();
    _removeOpAt(
      opIndex,
      (op) => op is PrivateDocVoiceOp,
      preferAdjacentAfter: false,
    );
  }

  void moveOp(int oldIndex, int newIndex) {
    _recordHistorySnapshot();
    _syncTextFromControllers();
    _moveOpInternal(oldIndex, newIndex, allowText: false);
  }

  void updateVoiceAt(int opIndex, PrivateVoiceData voice) {
    _recordHistorySnapshot();
    _syncTextFromControllers();
    final ops = List<PrivateDocOp>.from(_document.ops);
    if (opIndex < 0 || opIndex >= ops.length) return;
    if (ops[opIndex] is! PrivateDocVoiceOp) return;
    ops[opIndex] = PrivateDocVoiceOp(voice);
    _document = _document.copyWith(ops: ops);
    _bindTextControllers();
    _clampCaretToDocument();
    notifyListeners();
  }

  // --- internals ---

  PrivateDocAnchor? _caretToAnchor([PrivateDocCaret? caret]) {
    final safeCaret = caret ?? _caret;
    return PrivateDocAnchor(
      opIndex: safeCaret.opIndex,
      textOffset: safeCaret.textOffset,
    );
  }

  void _disposeTextBindings() {
    for (final c in _textControllers) {
      c.dispose();
    }
    for (final f in _textFocusNodes) {
      f.dispose();
    }
    _textControllers.clear();
    _textFocusNodes.clear();
  }

  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  void _recordHistorySnapshot() {
    _undoStack.add(_HistoryEntry(
      document: _document.copyWith(ops: List<PrivateDocOp>.from(_document.ops)),
      caret: _caret,
      selectionState: _selectionState,
    ));
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _restoreHistoryEntry(_HistoryEntry entry) {
    _bumpEditGeneration();
    _document = entry.document.copyWith(ops: _normalizeOps(entry.document.ops));
    _ensureEditingSurface();
    _caret = entry.caret;
    _selectionState = entry.selectionState;
    _bindTextControllers();
    _clampCaretToDocument();
    _focusForCaret(_caret, generation: _editGeneration);
    notifyListeners();
  }

  int _bumpEditGeneration() => ++_editGeneration;

  bool _isCurrentGeneration(int generation) => generation == _editGeneration;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    final current = _HistoryEntry(
      document: _document.copyWith(ops: List<PrivateDocOp>.from(_document.ops)),
      caret: _caret,
      selectionState: _selectionState,
    );
    _redoStack.add(current);
    final entry = _undoStack.removeLast();
    _restoreHistoryEntry(entry);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final current = _HistoryEntry(
      document: _document.copyWith(ops: List<PrivateDocOp>.from(_document.ops)),
      caret: _caret,
      selectionState: _selectionState,
    );
    _undoStack.add(current);
    final entry = _redoStack.removeLast();
    _restoreHistoryEntry(entry);
  }

  void _bindTextControllers() {
    _disposeTextBindings();
    for (final op in _document.ops) {
      if (op is PrivateDocTextOp) {
        final textFieldIndex = _textControllers.length;
        final controller = TextEditingController(text: op.text);
        final focus = FocusNode();
        controller.addListener(() {
          onTextSelectionChanged(textFieldIndex);
          notifyListeners();
        });
        _textControllers.add(controller);
        _textFocusNodes.add(focus);
      }
    }
    if (_textControllers.isEmpty) {
      final controller = TextEditingController();
      controller.addListener(() {
        onTextSelectionChanged(0);
        notifyListeners();
      });
      _textControllers.add(controller);
      _textFocusNodes.add(FocusNode());
    }
    _focusedTextIndex = _clampTextFieldIndex(_focusedTextIndex);
  }

  void _syncTextFromControllers() {
    final rebuilt = <PrivateDocOp>[];
    var textIndex = 0;
    for (final op in _document.ops) {
      if (op is PrivateDocTextOp) {
        if (textIndex < _textControllers.length) {
          rebuilt.add(PrivateDocTextOp(_textControllers[textIndex].text));
        } else {
          rebuilt.add(op);
        }
        textIndex++;
      } else {
        rebuilt.add(op);
      }
    }
    _document = _document.copyWith(ops: rebuilt);
    _clampCaretToDocument();
  }

  void _ensureEditingSurface() {
    if (_document.ops.isEmpty) {
      _document = _document.copyWith(ops: [const PrivateDocTextOp('')]);
    }
  }

  /// Caret used for toolbar embed inserts (after last embed when applicable).
  PrivateDocCaret _caretForInsert() {
    if (isCaretOnEmbed && _caret.textOffset == 1) {
      return PrivateDocCaret(opIndex: _caret.opIndex + 1, textOffset: 0);
    }

    final textCaret = _caretForTextField(_focusedTextIndex);
    final ops = _document.ops;
    if (textCaret.opIndex >= ops.length) return textCaret;

    final target = ops[textCaret.opIndex];
    if (target is PrivateDocTextOp && target.text.isEmpty) {
      final prevIsEmbed =
          textCaret.opIndex > 0 && ops[textCaret.opIndex - 1].isEmbed;
      if (prevIsEmbed) {
        return PrivateDocCaret(opIndex: textCaret.opIndex, textOffset: 0);
      }
    }
    if (target is PrivateDocTextOp &&
        textCaret.textOffset == target.text.length &&
        textCaret.opIndex + 1 < ops.length &&
        ops[textCaret.opIndex + 1].isEmbed) {
      return PrivateDocCaret(opIndex: textCaret.opIndex + 1, textOffset: 0);
    }
    if (target.isEmbed) {
      return PrivateDocCaret(opIndex: textCaret.opIndex + 1, textOffset: 0);
    }
    return textCaret;
  }

  PrivateDocCaret _caretAfterEmbedInsert(
    PrivateDocCaret insertCaret,
    String embedId,
  ) {
    for (var i = 0; i < _document.ops.length; i++) {
      final op = _document.ops[i];
      final matches = switch (op) {
        PrivateDocImageOp(:final image) => image.id == embedId,
        PrivateDocVoiceOp(:final voice) => voice.id == embedId,
        _ => false,
      };
      if (matches) {
        return PrivateDocCaret(opIndex: i, textOffset: 1);
      }
    }
    return insertCaret;
  }

  void _insertOpAtCaret(PrivateDocOp embed, PrivateDocCaret caret) {
    final ops = List<PrivateDocOp>.from(_document.ops);
    final safeCaret = _clampedCaretForOps(caret, ops);
    if (safeCaret.opIndex >= ops.length) {
      ops.add(embed);
      _document = _document.copyWith(ops: ops);
      _caret = PrivateDocCaret(opIndex: ops.length - 1, textOffset: 0);
      return;
    }

    final target = ops[safeCaret.opIndex];
    if (target is PrivateDocTextOp) {
      if (target.text.isEmpty) {
        ops[safeCaret.opIndex] = embed;
        _caret = PrivateDocCaret(opIndex: safeCaret.opIndex, textOffset: 0);
      } else {
        final safeOffset = safeCaret.textOffset.clamp(0, target.text.length);
        final before = target.text.substring(0, safeOffset);
        final after = target.text.substring(safeOffset);
        final replacement = <PrivateDocOp>[];
        if (before.isNotEmpty) replacement.add(PrivateDocTextOp(before));
        replacement.add(embed);
        if (after.isNotEmpty) replacement.add(PrivateDocTextOp(after));
        ops.removeAt(safeCaret.opIndex);
        ops.insertAll(safeCaret.opIndex, replacement);
        _caret = PrivateDocCaret(
          opIndex: safeCaret.opIndex + (before.isNotEmpty ? 1 : 0),
          textOffset: 0,
        );
      }
    } else {
      ops.insert(safeCaret.opIndex, embed);
      _caret = PrivateDocCaret(opIndex: safeCaret.opIndex, textOffset: 0);
    }
    _document = _document.copyWith(ops: ops);
    _clampCaretToDocument();
  }

  /// Refreshes [_caret] from the focused text field before structural edits.
  void _syncCaretFromFocusedTextField() {
    if (isCaretOnEmbed || _textControllers.isEmpty) return;
    for (var i = 0; i < _textFocusNodes.length; i++) {
      if (_textFocusNodes[i].hasFocus) {
        _focusedTextIndex = i;
        break;
      }
    }
    _caret = _caretForTextField(_focusedTextIndex);
  }

  void _removeOpAt(
    int opIndex,
    bool Function(PrivateDocOp op) predicate, {
    bool preferAdjacentAfter = false,
  }) {
    _syncCaretFromFocusedTextField();
    _syncTextFromControllers();
    final ops = List<PrivateDocOp>.from(_document.ops);
    if (opIndex < 0 || opIndex >= ops.length) return;
    if (!predicate(ops[opIndex])) return;
    final removed = ops[opIndex];
    final opsBeforeRemoval = List<PrivateDocOp>.from(ops);
    _bumpEditGeneration();
    ops.removeAt(opIndex);
    _document = _document.copyWith(ops: _normalizeOps(ops));
    _ensureEditingSurface();
    _bindTextControllers();
    if (removed.isEmbed) {
      _scheduleFocusForCaret(
        _resolveCaretAfterSegmentRemoval(
          opsBeforeRemoval,
          opIndex,
          preferAdjacentAfter: preferAdjacentAfter,
        ),
        generation: _editGeneration,
      );
    } else {
      _caret = _clampedCaretForOps(
        PrivateDocCaret(
          opIndex: math.min(opIndex, _document.ops.length - 1),
          textOffset: 0,
        ),
        _document.ops,
      );
    }
    notifyListeners();
  }

  void _moveOpInternal(int oldIndex, int newIndex, {required bool allowText}) {
    _syncTextFromControllers();
    final ops = List<PrivateDocOp>.from(_document.ops);
    if (oldIndex < 0 || oldIndex >= ops.length) return;
    if (newIndex < 0 || newIndex > ops.length) return;
    if (!allowText && ops[oldIndex] is PrivateDocTextOp) return;
    if (oldIndex == newIndex) return;

    _bumpEditGeneration();
    final item = ops.removeAt(oldIndex);
    var insertionIndex = newIndex;
    if (insertionIndex > oldIndex) insertionIndex -= 1;
    insertionIndex = insertionIndex.clamp(0, ops.length);
    ops.insert(insertionIndex, item);

    _document = _document.copyWith(ops: _normalizeOps(ops));
    _ensureEditingSurface();
    _bindTextControllers();
    _caret = _clampedCaretForOps(
      PrivateDocCaret(opIndex: insertionIndex, textOffset: 0),
      _document.ops,
    );
    notifyListeners();
  }

  /// Normalizes adjacent text ops while preserving the minimal compatibility
  /// layer needed for empty text slots around embeds.
  ///
  /// Empty text slots are retained only when they anchor an embed boundary or
  /// represent the last editable text surface. They are compatibility slots,
  /// not core document semantics.
  List<PrivateDocOp> _normalizeOps(List<PrivateDocOp> ops) {
    final merged = _mergeAdjacentText(ops);
    final stripped = <PrivateDocOp>[];
    for (var i = 0; i < merged.length; i++) {
      final op = merged[i];
      if (op is! PrivateDocTextOp) {
        stripped.add(op);
        continue;
      }

      final prevIsEmbed = i > 0 && merged[i - 1].isEmbed;
      final nextIsEmbed =
          i + 1 < merged.length && merged[i + 1].isEmbed;

      if (op.text.isEmpty) {
        final isLastOp = i == merged.length - 1;
        if (prevIsEmbed || nextIsEmbed || isLastOp) {
          stripped.add(op);
        }
        continue;
      }

      if (op.text == '\n' && (prevIsEmbed || nextIsEmbed)) {
        stripped.add(const PrivateDocTextOp(''));
        continue;
      }

      stripped.add(op);
    }
    return stripped;
  }

  List<PrivateDocOp> _mergeAdjacentText(List<PrivateDocOp> ops) {
    final merged = <PrivateDocOp>[];
    for (final op in ops) {
      if (op is PrivateDocTextOp &&
          merged.isNotEmpty &&
          merged.last is PrivateDocTextOp) {
        final prev = merged.last as PrivateDocTextOp;
        if (prev.text.isEmpty || op.text.isEmpty) {
          merged.add(op);
        } else {
          merged[merged.length - 1] =
              PrivateDocTextOp('${prev.text}${op.text}');
        }
      } else {
        merged.add(op);
      }
    }
    return merged;
  }

  int _opIndexForTextField(int textFieldIndex) {
    final safeTextIndex = _clampTextFieldIndex(textFieldIndex);
    var textCount = 0;
    for (var i = 0; i < _document.ops.length; i++) {
      if (_document.ops[i] is PrivateDocTextOp) {
        if (textCount == safeTextIndex) return i;
        textCount++;
      }
    }
    return _document.ops.isEmpty ? 0 : _document.ops.length - 1;
  }

  int _clampTextFieldIndex(int textFieldIndex) {
    if (_textControllers.isEmpty) return 0;
    return textFieldIndex.clamp(0, _textControllers.length - 1);
  }

  PrivateDocCaret _clampedCaretForOps(
    PrivateDocCaret caret,
    List<PrivateDocOp> ops,
  ) {
    if (ops.isEmpty) return const PrivateDocCaret(opIndex: 0, textOffset: 0);
    final opIndex = caret.opIndex.clamp(0, ops.length - 1);
    final op = ops[opIndex];
    return PrivateDocCaret(
      opIndex: opIndex,
      textOffset: caret.textOffset.clamp(0, op.semanticLength),
    );
  }

  /// Returns true when the current semantic selection covers [opIndex].
  bool selectionCoversOp(int opIndex) {
    if (opIndex < 0 || opIndex >= _document.ops.length) return false;
    if (_selectionState.isCollapsed) return false;
    final start = _selectionState.startOffset;
    final end = _selectionState.endOffset;
    final opStart = _linearOffsetBeforeOp(_document.ops, opIndex);
    final opEnd = opStart + _document.ops[opIndex].semanticLength;
    return start < opEnd && end > opStart;
  }

  /// Maps a caret from the current document to a unified linear segment offset.
  /// Text contributes its character length; each embed contributes length 1.
  int _linearOffsetForCaret(PrivateDocCaret caret) {
    final ops = _document.ops;
    if (ops.isEmpty) return 0;
    final c = _clampedCaretForOps(caret, ops);
    var offset = 0;
    for (var i = 0; i < c.opIndex; i++) {
      offset += ops[i].semanticLength;
    }
    return offset + c.textOffset;
  }

  /// Maps a unified linear segment offset back to the nearest concrete caret.
  PrivateDocCaret _caretForLinearOffset(int linearOffset) {
    final ops = _document.ops;
    if (ops.isEmpty) return const PrivateDocCaret(opIndex: 0, textOffset: 0);
    final safeOffset = linearOffset.clamp(0, _document.semanticLength);
    var consumed = 0;
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final length = op.semanticLength;
      if (length == 0) {
        if (safeOffset == consumed) {
          return PrivateDocCaret(opIndex: i, textOffset: 0);
        }
        continue;
      }
      if (safeOffset <= consumed + length) {
        return PrivateDocCaret(
          opIndex: i,
          textOffset: (safeOffset - consumed).clamp(0, length),
        );
      }
      consumed += length;
    }
    final lastIndex = ops.length - 1;
    return PrivateDocCaret(
      opIndex: lastIndex,
      textOffset: ops[lastIndex].semanticLength,
    );
  }

  void _focusForCaret(
    PrivateDocCaret caret, {
    int? generation,
  }) {
    if (generation != null && !_isCurrentGeneration(generation)) return;
    final ops = _document.ops;
    if (caret.opIndex >= ops.length) return;
    final op = ops[caret.opIndex];
    if (op is PrivateDocTextOp) {
      final textIdx = textFieldIndexForOp(caret.opIndex);
      if (textIdx == null) return;
      if (generation != null && !_isCurrentGeneration(generation)) return;
      _focusedTextIndex = textIdx;
      _textControllers[textIdx].selection =
          TextSelection.collapsed(offset: caret.textOffset);
      _textFocusNodes[textIdx].requestFocus();
      return;
    }
    if (op.isEmbed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (generation != null && !_isCurrentGeneration(generation)) return;
        if (_embedKeyboardFocusNode.canRequestFocus) {
          _embedKeyboardFocusNode.requestFocus();
        }
      });
    }
  }

  /// Applies caret focus immediately and again after rebuild (new TextFields).
  void _scheduleFocusForCaret(
    PrivateDocCaret caret, {
    required int generation,
  }) {
    _caret = caret;
    _focusForCaret(caret, generation: generation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isCurrentGeneration(generation)) return;
      _focusForCaret(_caret, generation: generation);
    });
  }

  bool _deleteBackwardFromCaret(PrivateDocCaret caret) {
    final ops = _document.ops;
    if (caret.opIndex >= ops.length) return false;
    final op = ops[caret.opIndex];

    if (op is PrivateDocTextOp && caret.textOffset == 0) {
      if (caret.opIndex > 0 && ops[caret.opIndex - 1].isEmbed) {
        if (_isEmbedBoundaryTextSlot(op.text)) {
          _removeTextOpAt(caret.opIndex, preferEmbedRightAfter: true);
          return true;
        }
        // Step 1 of 2: land on the embed's right edge; do not delete yet.
        setCaret(
          PrivateDocCaret(opIndex: caret.opIndex - 1, textOffset: 1),
        );
        return true;
      }
      return false;
    }

    // Step 2 of 2: backspace on embed right removes the embed.
    if (op.isEmbed && caret.textOffset == 1) {
      _removeEmbedAt(caret.opIndex, preferAdjacentAfter: false);
      return true;
    }
    return false;
  }

  bool _deleteForwardFromCaret(PrivateDocCaret caret) {
    final ops = _document.ops;
    if (caret.opIndex >= ops.length) return false;
    final op = ops[caret.opIndex];

    if (op is PrivateDocTextOp && caret.textOffset == op.text.length) {
      if (caret.opIndex + 1 < ops.length && ops[caret.opIndex + 1].isEmbed) {
        // Step 1 of 2: land on the embed's left edge; do not delete yet.
        setCaret(
          PrivateDocCaret(opIndex: caret.opIndex + 1, textOffset: 0),
        );
        return true;
      }
      return false;
    }

    // Step 2 of 2: delete key on embed left removes the embed.
    if (op.isEmbed && caret.textOffset == 0) {
      _removeEmbedAt(caret.opIndex, preferAdjacentAfter: false);
      return true;
    }
    return false;
  }

  void _removeTextOpAt(int opIndex, {bool preferEmbedRightAfter = false}) {
    _recordHistorySnapshot();
    _syncTextFromControllers();
    final ops = List<PrivateDocOp>.from(_document.ops);
    if (opIndex < 0 || opIndex >= ops.length) return;
    if (ops[opIndex] is! PrivateDocTextOp) return;
    final hadEmbedBefore = opIndex > 0 && ops[opIndex - 1].isEmbed;
    ops.removeAt(opIndex);
    _document = _document.copyWith(ops: _normalizeOps(ops));
    _ensureEditingSurface();
    _bindTextControllers();
    if (preferEmbedRightAfter && hadEmbedBefore) {
      final embedIndex = opIndex - 1;
      if (embedIndex >= 0 &&
          embedIndex < _document.ops.length &&
          _document.ops[embedIndex].isEmbed) {
        setCaret(PrivateDocCaret(opIndex: embedIndex, textOffset: 1));
        return;
      }
    }
    _caret = _clampedCaretForOps(
      PrivateDocCaret(
        opIndex: math.min(opIndex, _document.ops.length - 1),
        textOffset: 0,
      ),
      _document.ops,
    );
    _focusForCaret(_caret);
    notifyListeners();
  }

  void _removeEmbedAt(int opIndex, {bool preferAdjacentAfter = false}) {
    _recordHistorySnapshot();
    _syncCaretFromFocusedTextField();
    _syncTextFromControllers();
    final ops = List<PrivateDocOp>.from(_document.ops);
    if (opIndex < 0 || opIndex >= ops.length) return;
    if (!ops[opIndex].isEmbed) return;
    final opsBeforeRemoval = List<PrivateDocOp>.from(ops);
    _bumpEditGeneration();
    ops.removeAt(opIndex);
    _document = _document.copyWith(ops: _normalizeOps(ops));
    _ensureEditingSurface();
    _bindTextControllers();
    _scheduleFocusForCaret(
      _resolveCaretAfterSegmentRemoval(
        opsBeforeRemoval,
        opIndex,
        preferAdjacentAfter: preferAdjacentAfter,
      ),
      generation: _editGeneration,
    );
    notifyListeners();
  }

  /// Stage 2 unified deletion recovery.
  ///
  /// After removing a segment, prefer the nearest valid boundary according to a
  /// single rule: current removal boundary, left boundary, right boundary, then
  /// document start.
  ///
  /// Unified deletion recovery used by embed/text structural removals in this
  /// controller.
  PrivateDocCaret _resolveCaretAfterSegmentRemoval(
    List<PrivateDocOp> opsBeforeRemoval,
    int removedIndex, {
    required bool preferAdjacentAfter,
  }) {
    if (_document.ops.isEmpty) {
      return const PrivateDocCaret(opIndex: 0, textOffset: 0);
    }

    final removalOffset = _linearOffsetBeforeOp(opsBeforeRemoval, removedIndex);
    if (preferAdjacentAfter) {
      return _caretForNearestSegmentBoundary(removalOffset, preferRight: true);
    }
    return _caretForNearestSegmentBoundary(removalOffset, preferRight: false);
  }

  PrivateDocCaret _caretForNearestSegmentBoundary(
    int linearOffset, {
    required bool preferRight,
  }) {
    if (_document.ops.isEmpty) {
      return const PrivateDocCaret(opIndex: 0, textOffset: 0);
    }
    final docLength = _document.semanticLength;
    final safeOffset = linearOffset.clamp(0, docLength);
    if (preferRight && safeOffset < docLength) {
      return _caretForLinearOffset(safeOffset);
    }
    if (!preferRight && safeOffset > 0) {
      return _caretForLinearOffset(safeOffset);
    }
    if (safeOffset < docLength) {
      return _caretForLinearOffset(safeOffset);
    }
    if (safeOffset > 0) {
      return _caretForLinearOffset(safeOffset);
    }
    return _caretForLinearOffset(0);
  }

  /// Unified logical length immediately before [opIndex].
  int _linearOffsetBeforeOp(List<PrivateDocOp> ops, int opIndex) {
    var offset = 0;
    for (var i = 0; i < opIndex && i < ops.length; i++) {
      offset += ops[i].semanticLength;
    }
    return offset;
  }

  void _insertCharInTextOp(int opIndex, String char, {required int at}) {
    _recordHistorySnapshot();
    _syncTextFromControllers();
    final ops = List<PrivateDocOp>.from(_document.ops);
    final text = (ops[opIndex] as PrivateDocTextOp).text;
    final next = text.replaceRange(at, at, char);
    ops[opIndex] = PrivateDocTextOp(next);
    _document = _document.copyWith(ops: ops);
    _bindTextControllers();
    setCaret(PrivateDocCaret(opIndex: opIndex, textOffset: at + char.length));
  }

  void _clampCaretToDocument() {
    _caret = _clampedCaretForOps(_caret, _document.ops);
    _focusedTextIndex = _clampTextFieldIndex(_focusedTextIndex);
  }

}

/// Snapshot of editable document state for undo/redo stacks.
class _HistoryEntry {
  const _HistoryEntry({
    required this.document,
    required this.caret,
    required this.selectionState,
  });

  final PrivateNoteDocument document;
  final PrivateDocCaret caret;
  final PrivateDocSelectionState selectionState;
}
