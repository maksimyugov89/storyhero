import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes/route_names.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/buttons/app_fab.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../core/widgets/rounded_image.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../features/books/data/book_providers.dart';
import '../../../core/models/book.dart';
import 'book_view_screen.dart';

enum BookFilter { all, drafts, completed }

class BooksListScreen extends HookConsumerWidget {
  const BooksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = useState(BookFilter.all);
    final booksAsync = ref.watch(booksProvider);

    List<Book> filterBooks(List<Book> books, BookFilter filter) {
      switch (filter) {
        case BookFilter.drafts:
          return books.where((b) => b.status == 'draft' || b.status == 'editing').toList();
        case BookFilter.completed:
          return books.where((b) => b.status == 'completed' || b.status == 'finalized').toList();
        case BookFilter.all:
        default:
          return books;
      }
    }

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_books_list.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Мои книги',
          leading: IconButton(
            icon: AssetIcon(
              assetPath: AppIcons.back,
              size: 24,
              color: AppColors.onBackground,
            ),
            onPressed: () => context.go(RouteNames.home),
          ),
          actions: [
            IconButton(
              icon: AssetIcon(
                assetPath: AppIcons.myBooks,
                size: 24,
                color: AppColors.onBackground,
              ),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            // Фильтры
            Padding(
              padding: AppSpacing.paddingMD,
              child: Row(
                children: [
                  Expanded(
                    child: _FilterChip(
                      label: 'Все',
                      isSelected: selectedFilter.value == BookFilter.all,
                      onTap: () => selectedFilter.value = BookFilter.all,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _FilterChip(
                      label: 'Черновики',
                      icon: AppIcons.draftPages,
                      isSelected: selectedFilter.value == BookFilter.drafts,
                      onTap: () => selectedFilter.value = BookFilter.drafts,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _FilterChip(
                      label: 'Готовые',
                      icon: AppIcons.secureBook,
                      isSelected: selectedFilter.value == BookFilter.completed,
                      onTap: () => selectedFilter.value = BookFilter.completed,
                    ),
                  ),
                ],
              ),
            ),
            
            // Список книг
            Expanded(
              child: booksAsync.when(
                data: (books) {
                  final filteredBooks = filterBooks(books, selectedFilter.value);
                  
                  if (filteredBooks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AssetIcon(
                            assetPath: AppIcons.library,
                            size: 64,
                            color: AppColors.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            selectedFilter.value == BookFilter.all
                                ? 'Нет книг'
                                : selectedFilter.value == BookFilter.drafts
                                    ? 'Нет черновиков'
                                    : 'Нет готовых книг',
                            style: safeCopyWith(
                              AppTypography.headlineSmall,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Создайте первую книгу',
                            style: safeCopyWith(
                              AppTypography.bodyMedium,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return GridView.builder(
                    padding: AppSpacing.paddingMD,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      final isDraft = book.status == 'draft' || book.status == 'editing';
                      final isCompleted = book.status == 'completed' || book.status == 'finalized';
                      
                      return AppMagicCard(
                        onTap: () => context.go(RouteNames.bookView.replaceAll(':id', book.id)),
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Обложка
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Stack(
                                children: [
                                  RoundedImage(
                                    imageUrl: book.coverUrl,
                                    height: 180,
                                    width: double.infinity,
                                    radius: 0,
                                  ),
                                  // Статус
                                  Positioned(
                                    top: AppSpacing.sm,
                                    right: AppSpacing.sm,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCompleted
                                            ? AppColors.success
                                            : isDraft
                                                ? AppColors.warning
                                                : AppColors.info,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: AssetIcon(
                                        assetPath: isCompleted
                                            ? AppIcons.secureBook
                                            : AppIcons.draftPages,
                                        size: 16,
                                        color: AppColors.onPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Информация
                            Expanded(
                              child: Padding(
                                padding: AppSpacing.paddingSM,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        book.title,
                                        style: safeCopyWith(
                                          AppTypography.labelLarge,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Книга',
                                      style: safeCopyWith(
                                        AppTypography.bodySmall,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: AppSpacing.paddingMD,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AssetIcon(
                          assetPath: AppIcons.alert,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Ошибка загрузки книг',
                          style: safeCopyWith(
                            AppTypography.headlineSmall,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          error.toString(),
                          style: AppTypography.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: AppFAB(
          iconAsset: AppIcons.addBook,
          tooltip: 'Создать книгу',
          onPressed: () => context.go(RouteNames.generate),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.surfaceVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AssetIcon(
                assetPath: icon!,
                size: 16,
                color: isSelected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: safeCopyWith(
                  AppTypography.labelMedium,
                  color: isSelected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
