import 'dart:ui';

import 'package:flutter/material.dart';

class PrivateSpaceCategoryData {
  const PrivateSpaceCategoryData({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;
  final Color color;
}

class PrivateSpaceCategoriesOverlay extends StatelessWidget {
  const PrivateSpaceCategoriesOverlay({
    super.key,
    required this.historyScrollController,
    required this.categories,
    required this.isAddingCategory,
    required this.showDeleteForCategoryId,
    required this.categoryController,
    required this.categoryFocusNode,
    required this.onClose,
    required this.onCancelAddCategory,
    required this.onSaveCategory,
    required this.onStartAddCategory,
    required this.onDeleteCategory,
    required this.onShowDeleteCategory,
    required this.onDismissDeleteCategory,
    required this.onApplyCategory,
  });

  final ScrollController historyScrollController;
  final List<PrivateSpaceCategoryData> categories;
  final bool isAddingCategory;
  final String? showDeleteForCategoryId;
  final TextEditingController categoryController;
  final FocusNode categoryFocusNode;
  final VoidCallback onClose;
  final VoidCallback onCancelAddCategory;
  final VoidCallback onSaveCategory;
  final VoidCallback onStartAddCategory;
  final void Function(String categoryId) onDeleteCategory;
  final void Function(String categoryId) onShowDeleteCategory;
  final VoidCallback onDismissDeleteCategory;
  final void Function(PrivateSpaceCategoryData category) onApplyCategory;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: showDeleteForCategoryId != null
                ? onDismissDeleteCategory
                : onClose,
            child: Container(color: Colors.black.withValues(alpha: 0.60)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.62,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF120F1A).withValues(alpha: 0.95),
                    border: Border.all(color: Colors.white10),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: GestureDetector(
                    onTap: showDeleteForCategoryId != null
                        ? onDismissDeleteCategory
                        : null,
                    behavior: HitTestBehavior.translucent,
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: showDeleteForCategoryId != null
                                  ? onDismissDeleteCategory
                                  : null,
                              behavior: HitTestBehavior.opaque,
                              child: const Text(
                                'Select Category',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          controller: historyScrollController,
                          itemCount: categories.length + (isAddingCategory ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            if (isAddingCategory && i == categories.length) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: onCancelAddCategory,
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white54,
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: categoryController,
                                        focusNode: categoryFocusNode,
                                        style: const TextStyle(color: Colors.white),
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration(
                                          hintText: 'Category Name',
                                          hintStyle:
                                              TextStyle(color: Colors.white54),
                                          border: InputBorder.none,
                                        ),
                                        onSubmitted: (_) => onSaveCategory(),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: onSaveCategory,
                                      icon: const Icon(
                                        Icons.check,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final category = categories[i];
                            final showDelete = showDeleteForCategoryId == category.id;
                            return Column(
                              children: [
                                if (showDelete)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: GestureDetector(
                                      onTap: () => onDeleteCategory(category.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: category.color
                                              .withValues(alpha: 0.28),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: category.color
                                                .withValues(alpha: 0.75),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              color: category.color,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: category.color,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'SF Pro',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  onLongPress: category.name == 'Uncategorized'
                                      ? null
                                      : () => onShowDeleteCategory(category.id),
                                  child: Material(
                                    color: category.color.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        if (showDeleteForCategoryId != null) {
                                          final dismissOnly =
                                              showDeleteForCategoryId ==
                                                  category.id;
                                          onDismissDeleteCategory();
                                          if (dismissOnly) return;
                                        }
                                        onApplyCategory(category);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: category.color
                                                .withValues(alpha: 0.75),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: category.color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                category.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: 'SF Pro',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (showDeleteForCategoryId != null) {
                              onDismissDeleteCategory();
                              return;
                            }
                            onStartAddCategory();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('New Category'),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
