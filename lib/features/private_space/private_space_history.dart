import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pupu/features/private_space/private_note_blocks.dart';
import 'package:pupu/models/private_entry.dart';

class PrivateSpaceHistoryEntryCard extends StatelessWidget {
  const PrivateSpaceHistoryEntryCard({
    super.key,
    required this.entry,
    required this.categoryColor,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onPin,
    required this.onDelete,
    required this.onShare,
    required this.isPinned,
    this.swipeCloseNonce = 0,
  });

  final PrivateEntry entry;
  final Color? categoryColor;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final bool isPinned;
  final int swipeCloseNonce;

  @override
  Widget build(BuildContext context) {
    return _SwipeRevealCard(
      selectionMode: selectionMode,
      onTap: onTap,
      onLongPress: onLongPress,
      swipeCloseNonce: swipeCloseNonce,
      actions: [
        _SwipeAction(
          icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          onTap: onPin,
        ),
        _SwipeAction(
          icon: Icons.share_outlined,
          onTap: onShare,
        ),
        _SwipeAction(
          icon: Icons.delete_outline,
          onTap: () {
            // Defer delete until after swipe/gesture arena settles.
            WidgetsBinding.instance.addPostFrameCallback((_) => onDelete());
          },
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D0A14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: categoryColor?.withValues(alpha: 0.60) ??
                const Color(0x44FACC15),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (categoryColor != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: categoryColor!.withValues(alpha: 0.12),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isPinned)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.push_pin,
                                  size: 13,
                                  color: Color(0xFFFFF8DB),
                                ),
                              ),
                            if (entry.category.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            Text(
                              DateFormat('MMM d, yyyy').format(entry.updatedAt),
                              style: const TextStyle(
                                color: Color(0x99FEF3C7),
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('HH:mm').format(entry.updatedAt),
                              style: const TextStyle(
                                color: Color(0x99FEF3C7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        HistoryMixedContentPreview(entry: entry),
                      ],
                    ),
                  ),
                  if (selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? const Color(0xFFFACC15)
                            : Colors.white30,
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

class _SwipeAction {
  const _SwipeAction({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;
}

class _SwipeRevealCard extends StatefulWidget {
  const _SwipeRevealCard({
    required this.child,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.actions,
    this.swipeCloseNonce = 0,
  });

  final Widget child;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final List<_SwipeAction> actions;
  final int swipeCloseNonce;

  @override
  State<_SwipeRevealCard> createState() => _SwipeRevealCardState();
}

class _SwipeRevealCardState extends State<_SwipeRevealCard>
    with SingleTickerProviderStateMixin {
  static const double _actionWidth = 52;
  static const double _maxOpenWidth = _actionWidth * 3 + 16;
  static const Duration _animationDuration = Duration(milliseconds: 180);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _animationDuration,
    lowerBound: 0,
    upperBound: _maxOpenWidth,
    value: 0,
  );

  @override
  void didUpdateWidget(covariant _SwipeRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionMode && !oldWidget.selectionMode) {
      _animateTo(0);
    }
    if (widget.swipeCloseNonce != oldWidget.swipeCloseNonce &&
        widget.swipeCloseNonce > 0) {
      _animateTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _controller.animateTo(
      target.clamp(0.0, _maxOpenWidth),
      duration: _animationDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: widget.selectionMode
          ? null
          : (details) {
              final next =
                  (_controller.value - details.delta.dx).clamp(0.0, _maxOpenWidth);
              _controller.value = next;
            },
      onHorizontalDragEnd: widget.selectionMode
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -200 || _controller.value > _maxOpenWidth / 2) {
                _animateTo(_maxOpenWidth);
              } else {
                _animateTo(0);
              }
            },
      onTap: () {
        if (!widget.selectionMode && _controller.value > 8) {
          _animateTo(0);
          return;
        }
        widget.onTap();
      },
      onLongPress: widget.onLongPress,
      // Height follows card content so mixed text/image previews never overflow.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xAA3B1A13),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: widget.actions.map((action) {
                    return SizedBox(
                      width: _actionWidth,
                      child: IconButton(
                        onPressed: action.onTap,
                        icon: Icon(action.icon, color: Colors.white),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-_controller.value, 0),
                  child: child,
                );
              },
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Clamps a saved history list scroll offset when list length or order changes.
double clampHistoryScrollOffset({
  required double savedOffset,
  required double maxScrollExtent,
}) {
  if (maxScrollExtent <= 0) return 0;
  return savedOffset.clamp(0.0, maxScrollExtent);
}
