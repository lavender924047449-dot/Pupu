import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pupu/features/private_space/private_note_blocks.dart';
import 'package:pupu/features/private_space/private_note_image.dart';
import 'package:pupu/features/private_space/private_note_document_controller.dart';
import 'package:pupu/features/private_space/private_space_clipboard.dart';
import 'package:pupu/features/private_space/private_space_text_selection.dart';
import 'package:pupu/features/private_space/private_space_ui.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';

/// Word-like continuous editor: seamless text + inline embeds on one paper background.
class PrivateNoteEditor extends StatefulWidget {
  const PrivateNoteEditor({
    super.key,
    required this.controller,
    required this.scrollController,
    this.enabled = true,
    this.onVoiceRename,
    this.onVoiceDelete,
    this.onVoicePlayTap,
    this.onImageDoubleTap,
    this.onImageLongPress,
    this.onImageCopy,
    this.onImageCut,
    this.onImageDelete,
    this.onContentChanged,
  });

  final PrivateNoteDocumentController controller;
  final ScrollController scrollController;
  final bool enabled;
  final void Function(int opIndex, PrivateVoiceData voice)? onVoiceRename;
  final void Function(int opIndex, PrivateVoiceData voice)? onVoiceDelete;
  final Future<void> Function(String path)? onVoicePlayTap;
  final void Function(int opIndex, PrivateImageData image)? onImageDoubleTap;
  final void Function(int opIndex, PrivateImageData image)? onImageLongPress;
  final void Function(int opIndex, PrivateImageData image)? onImageCopy;
  final void Function(int opIndex, PrivateImageData image)? onImageCut;
  final void Function(int opIndex, PrivateImageData image)? onImageDelete;
  final VoidCallback? onContentChanged;

  @override
  State<PrivateNoteEditor> createState() => _PrivateNoteEditorState();
}

class _PrivateNoteEditorState extends State<PrivateNoteEditor> {
  static const _viewportPadding = 15.0;
  static const _entryPlaceholderText = 'Speak to the galaxy...';
  static const _listPaddingTop = 10.0;
  static const _textFieldPaddingVertical = 2.0;

  static final _entryPlaceholderStyle = TextStyle(
    color: PrivateSpaceColors.accent.withValues(alpha: 0.70),
    fontSize: 18,
    fontStyle: FontStyle.italic,
    fontFamily: 'Josefin Sans',
    fontWeight: FontWeight.w200,
    height: 1.78,
    decoration: TextDecoration.none,
  );

  /// Coalesces multiple scroll requests within the same frame.
  bool _scrollScheduled = false;
  int? _pendingScrollTextIndex;

  /// Local callback generation to ignore stale post-frame work.
  int _uiGeneration = 0;

  /// Prevents embed Enter from firing twice (KeyEvent + soft-keyboard `\n`).
  bool _embedEnterHandledThisFrame = false;
  int _lastEmbedNewlineMs = 0;

  static const _textStyle = TextStyle(
    color: Color(0xFFF0F3F7),
    fontSize: 17,
    height: 1.78,
    fontWeight: FontWeight.w300,
    fontFamily: 'Segoe UI',
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  /// System-default Material toolbar; only copy/cut/paste routing is customized.
  late final PrivateSpaceTextSelectionControls _textSelectionControls;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _textSelectionControls = PrivateSpaceTextSelectionControls(
      onPaste: _handlePasteFromSelectionToolbar,
      onSemanticCopy: () => widget.controller.handleCopy(),
      onSemanticCut: () {
        final handled = widget.controller.handleCut();
        if (handled) {
          widget.onContentChanged?.call();
          setState(() {});
        }
        return handled;
      },
      onCopiedText: (_) => widget.onContentChanged?.call(),
      onCutText: (_) {
        widget.onContentChanged?.call();
        setState(() {});
      },
    );
  }

  @override
  void didUpdateWidget(covariant PrivateNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _uiGeneration++;
    if (widget.controller.isCaretOnEmbed && widget.enabled) {
      _requestEmbedKeyboardFocus(generation: _uiGeneration);
    }
    setState(() {});
  }

  /// Ensures the embed keyboard proxy is mounted before requesting focus.
  void _requestEmbedKeyboardFocus({required int generation}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _uiGeneration) return;
      if (!widget.controller.isCaretOnEmbed || !widget.enabled) {
        return;
      }
      final embedFocus = widget.controller.embedKeyboardFocusNode;
      if (!embedFocus.canRequestFocus) return;

      final primary = FocusManager.instance.primaryFocus;
      if (primary != null && primary != embedFocus) {
        primary.unfocus();
      }
      embedFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ops = widget.controller.ops;
    var textIndex = 0;
    final items = <Widget>[];

    if (!widget.controller.hasTextSegments && widget.enabled) {
      items.add(_buildVirtualTextField());
    }

    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final child = switch (op) {
        PrivateDocTextOp() => _buildTextField(textIndex++, i),
        PrivateDocImageOp(:final image) =>
          _wrapEmbedWithTrailingTextSlot(i, _buildImage(i, image)),
        PrivateDocVoiceOp(:final voice) =>
          _wrapEmbedWithTrailingTextSlot(i, _buildVoice(i, voice)),
      };
      final highlighted = widget.controller.selectionCoversOp(i);
      final wrappedChild = highlighted && op is! PrivateDocTextOp
          ? DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x66E2BE57), width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: child,
            )
          : child;
      items.add(
        KeyedSubtree(
          key: ValueKey(widget.controller.opKeyAt(i)),
          child: wrappedChild,
        ),
      );
    }

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _handlePaperTap,
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(top: _listPaddingTop, bottom: 10),
            physics: const ClampingScrollPhysics(),
            children: items,
          ),
        ),
        if (widget.controller.showEntryPlaceholder)
          Positioned(
            left: 0,
            right: 0,
            top: _listPaddingTop + _textFieldPaddingVertical,
            child: IgnorePointer(
              child: Text(
                _entryPlaceholderText,
                style: _entryPlaceholderStyle,
              ),
            ),
          ),
        // Always mounted so [embedKeyboardFocusNode] stays attached for reliable focus.
        Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: IgnorePointer(
            ignoring: !widget.controller.isCaretOnEmbed || !widget.enabled,
            child: _buildEmbedKeyboardProxy(),
          ),
        ),
      ],
    );
  }

  /// Focuses the first text field when the user taps empty paper (not an embed).
  void _handlePaperTap() {
    if (!widget.enabled) return;
    widget.controller.focusFirstText(requestKeyboard: true);
  }

  KeyEventResult _handleEmbedKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !widget.enabled) {
      return KeyEventResult.ignored;
    }
    final c = widget.controller;
    if (!c.isCaretOnEmbed) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      c.moveCaretLeft();
      setState(() {});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      c.moveCaretRight();
      setState(() {});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && c.handleArrowUpFromEmbed()) {
      setState(() {});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && c.handleArrowDownFromEmbed()) {
      setState(() {});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace && c.handleDeleteBackwardOnEmbed()) {
      widget.onContentChanged?.call();
      setState(() {});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete && c.handleDeleteForwardOnEmbed()) {
      widget.onContentChanged?.call();
      setState(() {});
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) &&
        _dispatchEmbedNewline()) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isEmbedOp(PrivateDocOp op) =>
      op is PrivateDocImageOp || op is PrivateDocVoiceOp;

  /// When true, show a tap strip after this embed so the user can start typing.
  bool _shouldOfferTextAfterEmbed(int embedOpIndex) {
    if (!widget.enabled) return false;
    final ops = widget.controller.ops;
    final nextIndex = embedOpIndex + 1;
    if (nextIndex >= ops.length) return true;
    return _isEmbedOp(ops[nextIndex]);
  }

  Widget _wrapEmbedWithTrailingTextSlot(int embedOpIndex, Widget embed) {
    if (!_shouldOfferTextAfterEmbed(embedOpIndex)) {
      return embed;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        embed,
        _buildEmbedTextGap(opIndex: embedOpIndex + 1),
      ],
    );
  }

  /// Horizontal gutter outside the embed block; caret renders in this space.
  static const _embedGutterWidth = 20.0;

  Widget _wrapEmbedInteractive(int opIndex, Widget embedContent) {
    if (!widget.enabled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _embedGutterWidth),
        child: embedContent,
      );
    }

    final c = widget.controller;
    final showCaret = c.isCaretOnEmbed && c.caret.opIndex == opIndex;
    final beforeCaret = showCaret && c.caret.textOffset == 0;
    final afterCaret = showCaret && c.caret.textOffset == 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _embedGutterWidth,
            child: _embedEdgeTapZone(
              showCaret: beforeCaret,
              alignRight: false,
              onTap: () {
                c.placeCaretBeforeEmbed(opIndex);
                _uiGeneration++;
                _requestEmbedKeyboardFocus(generation: _uiGeneration);
                setState(() {});
              },
            ),
          ),
          Expanded(child: embedContent),
          SizedBox(
            width: _embedGutterWidth,
            child: _embedEdgeTapZone(
              showCaret: afterCaret,
              alignRight: true,
              onTap: () {
                c.placeCaretAfterEmbed(opIndex);
                _uiGeneration++;
                _requestEmbedKeyboardFocus(generation: _uiGeneration);
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Keeps the soft keyboard available while the logical caret sits on an embed.
  Widget _buildEmbedKeyboardProxy() {
    return Opacity(
      opacity: 0,
      child: SizedBox(
        height: 1,
        child: Focus(
          onKeyEvent: _handleEmbedKey,
          child: TextField(
            controller: widget.controller.embedKeyboardController,
            focusNode: widget.controller.embedKeyboardFocusNode,
            maxLines: 1,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            scrollPadding: EdgeInsets.zero,
            style: _textStyle.copyWith(fontSize: 1, height: 1),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
            ),
            // Soft keyboard Enter inserts '\n' instead of firing [KeyEvent].
            onChanged: _handleEmbedKeyboardTextChanged,
          ),
        ),
      ),
    );
  }

  void _handleEmbedKeyboardTextChanged(String value) {
    if (!value.contains('\n')) return;
    widget.controller.embedKeyboardController.clear();
    _dispatchEmbedNewline();
  }

  /// Routes embed Enter once per frame to [PrivateNoteDocumentController.handleNewlineOnEmbed].
  bool _dispatchEmbedNewline() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_embedEnterHandledThisFrame || now - _lastEmbedNewlineMs < 120) {
      return true;
    }
    _embedEnterHandledThisFrame = true;
    _lastEmbedNewlineMs = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _embedEnterHandledThisFrame = false;
    });
    if (!widget.controller.handleNewlineOnEmbed()) return false;
    widget.onContentChanged?.call();
    setState(() {});
    return true;
  }

  Widget _embedEdgeTapZone({
    required bool showCaret,
    required VoidCallback onTap,
    bool alignRight = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: alignRight ? 0 : 4,
            right: alignRight ? 4 : 0,
          ),
          child: showCaret ? const _InlineCaret() : null,
        ),
      ),
    );
  }

  /// Tap target to spawn a text segment after/between embeds.
  Widget _buildEmbedTextGap({required int opIndex}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => widget.controller.ensureTextOpAt(opIndex),
      child: const SizedBox(
        height: 22,
        width: double.infinity,
      ),
    );
  }

  /// Invisible entry point for typing on embed-only notes.
  Widget _buildVirtualTextField() {
    final controller = widget.controller.textControllerAt(0);
    final focusNode = widget.controller.textFocusNodeAt(0);
    if (controller == null || focusNode == null) {
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: 0,
      child: SizedBox(
        height: 1,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          maxLines: 1,
          style: _textStyle,
          selectionControls: _textSelectionControls,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            if (!widget.controller.hasTextSegments) {
              widget.controller.ensureTextOpAt(widget.controller.ops.length);
            } else {
              widget.controller.onTextFocus(0);
            }
            setState(() {});
          },
          onChanged: (value) {
            widget.controller.onTextEdited(0, value);
            _ensureTextFieldVisibleIfNeeded(0);
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildTextField(int textIndex, int opIndex) {
    final controller = widget.controller.textControllerAt(textIndex);
    final focusNode = widget.controller.textFocusNodeAt(textIndex);
    if (controller == null || focusNode == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Actions(
        actions: <Type, Action<Intent>>{
          PasteTextIntent: CallbackAction<PasteTextIntent>(
            onInvoke: (intent) {
              _handlePaste(textIndex);
              return null;
            },
          ),
        },
        child: Focus(
          onKeyEvent: (node, event) => _handleTextFieldKey(textIndex, event),
          child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          maxLines: null,
          minLines: 1,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: _textStyle,
          cursorColor: const Color(0xFFE2BE57),
          cursorWidth: 1.4,
          selectionControls: _textSelectionControls,
          decoration: const InputDecoration(
            filled: false,
            fillColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () => widget.controller.onTextFocus(textIndex),
          onChanged: (value) {
            widget.controller.onTextEdited(textIndex, value);
            _ensureTextFieldVisibleIfNeeded(textIndex);
            setState(() {});
          },
        ),
        ),
      ),
    );
  }

  KeyEventResult _handleTextFieldKey(int textIndex, KeyEvent event) {
    if (event is! KeyDownEvent || !widget.enabled) {
      return KeyEventResult.ignored;
    }
    final c = widget.controller;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.backspace &&
        c.handleDeleteBackwardFromTextField(textIndex)) {
      _afterControllerEdit(textIndex);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete &&
        c.handleDeleteForwardFromTextField(textIndex)) {
      _afterControllerEdit(textIndex);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft &&
        c.handleArrowLeftFromTextField(textIndex)) {
      setState(() {});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight &&
        c.handleArrowRightFromTextField(textIndex)) {
      setState(() {});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp &&
        c.handleArrowUpFromTextField(textIndex)) {
      setState(() {});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown &&
        c.handleArrowDownFromTextField(textIndex)) {
      setState(() {});
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        c.handleNewlineFromTextField(textIndex)) {
      _afterControllerEdit(textIndex);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _afterControllerEdit(int textIndex) {
    widget.onContentChanged?.call();
    setState(() {});
    _ensureTextFieldVisibleIfNeeded(textIndex);
  }

  Future<void> _handlePasteFromSelectionToolbar() async {
    final c = widget.controller;
    for (var i = 0; i < c.textControllers.length; i++) {
      if (c.textFocusNodeAt(i)?.hasFocus == true) {
        await _handlePaste(i);
        return;
      }
    }
    await _handlePaste(c.focusedTextFieldIndex);
  }

  Future<void> _handlePaste(int textIndex) async {
    if (!widget.enabled) return;

    widget.controller.onTextFocus(textIndex);

    if (widget.controller.tryPasteInternalImage()) {
      widget.onContentChanged?.call();
      setState(() {});
      return;
    }

    final raw = await PrivateSpaceClipboard.readClipboardText();

    if (widget.controller.tryPasteImageFromClipboardText(raw)) {
      widget.onContentChanged?.call();
      setState(() {});
      return;
    }

    if (widget.controller.shouldSilenceClipboardText(raw)) {
      return;
    }

    final plain = PrivateSpaceClipboard.tryReadPlainText(raw);
    if (plain != null) {
      widget.controller.pasteTextAtCaret(plain);
      widget.onContentChanged?.call();
      setState(() {});
    }
  }

  /// Scrolls only when the caret (not the whole TextField) leaves the viewport.
  void _ensureTextFieldVisibleIfNeeded(int textIndex) {
    _pendingScrollTextIndex = textIndex;
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      final index = _pendingScrollTextIndex;
      _pendingScrollTextIndex = null;
      if (!mounted || index == null) return;
      _scrollCaretIntoViewIfNeeded(index);
    });
  }

  void _scrollCaretIntoViewIfNeeded(int textIndex) {
    final focusNode = widget.controller.textFocusNodeAt(textIndex);
    final textController = widget.controller.textControllerAt(textIndex);
    final fieldContext = focusNode?.context;
    if (fieldContext == null || textController == null) return;

    final caretRect = _caretGlobalRect(fieldContext, textController);
    if (caretRect == null) return;

    final renderObject = fieldContext.findRenderObject();
    if (renderObject == null) return;

    final viewportRect = _visibleViewportRect(fieldContext, renderObject);
    if (!_caretNeedsScrollIntoView(caretRect, viewportRect)) return;

    final delta = _minimalScrollDelta(caretRect, viewportRect);
    if (delta == 0 || !widget.scrollController.hasClients) return;

    final position = widget.scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return;

    widget.scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  /// Locates the [RenderEditable] under a TextField focus subtree.
  RenderEditable? _findRenderEditable(RenderObject? root) {
    RenderEditable? found;
    void visit(RenderObject node) {
      if (found != null) return;
      if (node is RenderEditable) {
        found = node;
        return;
      }
      node.visitChildren(visit);
    }

    if (root != null) visit(root);
    return found;
  }

  /// Caret bounds in global coordinates — used instead of the full TextField box.
  Rect? _caretGlobalRect(
    BuildContext fieldContext,
    TextEditingController controller,
  ) {
    final renderEditable = _findRenderEditable(fieldContext.findRenderObject());
    if (renderEditable == null) return null;

    final offset = controller.selection.isValid
        ? controller.selection.extentOffset
        : controller.text.length;
    final clamped = offset.clamp(0, controller.text.length);

    final localRect = renderEditable.getLocalRectForCaret(
      TextPosition(offset: clamped),
    );
    return MatrixUtils.transformRect(
      renderEditable.getTransformTo(null),
      localRect,
    );
  }

  /// Visible scroll viewport, accounting for keyboard inset and edge padding.
  Rect _visibleViewportRect(BuildContext context, RenderObject anchor) {
    final viewport = RenderAbstractViewport.maybeOf(anchor);
    if (viewport == null) return Rect.zero;

    final viewportBox = viewport as RenderBox;
    final viewportTopLeft = viewportBox.localToGlobal(Offset.zero);
    var viewportRect = viewportTopLeft & viewportBox.size;

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInset > 0) {
      viewportRect = Rect.fromLTRB(
        viewportRect.left,
        viewportRect.top,
        viewportRect.right,
        viewportRect.bottom - keyboardInset,
      );
    }

    return viewportRect.deflate(_viewportPadding);
  }

  /// True when the caret top/bottom fall outside the padded viewport.
  bool _caretNeedsScrollIntoView(Rect caretRect, Rect viewportRect) {
    if (viewportRect.isEmpty) return false;
    return !viewportRect.contains(caretRect.topCenter) ||
        !viewportRect.contains(caretRect.bottomCenter);
  }

  /// Smallest scroll delta to bring [caretRect] back into [viewportRect].
  double _minimalScrollDelta(Rect caretRect, Rect viewportRect) {
    if (!_caretNeedsScrollIntoView(caretRect, viewportRect)) return 0;
    if (caretRect.bottom > viewportRect.bottom) {
      return caretRect.bottom - viewportRect.bottom;
    }
    if (caretRect.top < viewportRect.top) {
      return caretRect.top - viewportRect.top;
    }
    return 0;
  }

  Widget _buildVoice(int opIndex, PrivateVoiceData voice) {
    return _wrapEmbedInteractive(
      opIndex,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: InlineVoiceBubble(
          voice: voice,
          onRename: () => widget.onVoiceRename?.call(opIndex, voice),
          onPlayTap: widget.onVoicePlayTap,
        ),
      ),
    );
  }

  Widget _buildImage(int opIndex, PrivateImageData image) {
    return _wrapEmbedInteractive(
      opIndex,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: GestureDetector(
          onDoubleTap: widget.enabled
              ? () => widget.onImageDoubleTap?.call(opIndex, image)
              : null,
          onLongPress: widget.enabled
              ? () => widget.onImageLongPress?.call(opIndex, image)
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 1.55,
              child: PrivateNoteImage(path: image.path),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineCaret extends StatefulWidget {
  const _InlineCaret();

  @override
  State<_InlineCaret> createState() => _InlineCaretState();
}

class _InlineCaretState extends State<_InlineCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 1.4,
        height: 22,
        color: const Color(0xFFE2BE57),
      ),
    );
  }
}
