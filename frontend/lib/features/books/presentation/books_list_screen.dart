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
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../core/widgets/rounded_image.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../features/books/data/book_providers.dart';
import '../../../core/models/book.dart';
import 'book_view_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum BookFilter { all, drafts, completed }

class BooksListScreen extends HookConsumerWidget {
  const BooksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Читаем фильтр из query параметров URL
    final uri = GoRouterState.of(context).uri;
    final filterParam = uri.queryParameters['filter'];
    final initialFilter = filterParam == 'drafts'
        ? BookFilter.drafts
        : filterParam == 'completed'
            ? BookFilter.completed
            : BookFilter.all;
    
    final selectedFilter = useState(initialFilter);
    final booksAsync = ref.watch(booksProvider);
    
    // Обновляем фильтр при изменении query параметров
    useEffect(() {
      final currentFilter = filterParam == 'drafts'
          ? BookFilter.drafts
          : filterParam == 'completed'
              ? BookFilter.completed
              : BookFilter.all;
      if (selectedFilter.value != currentFilter) {
        selectedFilter.value = currentFilter;
      }
      return null;
    }, [uri.toString()]);

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
                      onTap: () {
                        selectedFilter.value = BookFilter.all;
                        context.go(RouteNames.books);
                      },
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _FilterChip(
                      label: 'Черновики',
                      icon: AppIcons.draftPages,
                      isSelected: selectedFilter.value == BookFilter.drafts,
                      onTap: () {
                        selectedFilter.value = BookFilter.drafts;
                        context.go('${RouteNames.books}?filter=drafts');
                      },
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _FilterChip(
                      label: 'Готовые',
                      icon: AppIcons.secureBook,
                      isSelected: selectedFilter.value == BookFilter.completed,
                      onTap: () {
                        selectedFilter.value = BookFilter.completed;
                        context.go('${RouteNames.books}?filter=completed');
                      },
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
                                  // Используем coverUrl, если он есть, иначе пытаемся получить из первой сцены
                                  _BookCoverImage(
                                    coverUrl: book.coverUrl,
                                    bookId: book.id,
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
      ),
    );
  }
}

/// Виджет для отображения обложки книги
/// Использует coverUrl, если он есть, иначе пытается получить первое изображение из сцен
class _BookCoverImage extends ConsumerWidget {
  final String? coverUrl;
  final String bookId;

  const _BookCoverImage({
    required this.coverUrl,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Если есть coverUrl, используем его
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return RoundedImage(
        imageUrl: coverUrl,
        height: 180,
        width: double.infinity,
        radius: 0,
      );
    }

    // Если coverUrl отсутствует, пытаемся получить первое изображение из сцен
    final scenesAsync = ref.watch(bookScenesProvider(bookId));
    
    return scenesAsync.when(
      data: (scenes) {
        if (scenes.isEmpty) {
          // Нет сцен - показываем placeholder
          return RoundedImage(
            imageUrl: null,
            height: 180,
            width: double.infinity,
            radius: 0,
          );
        }

        // Сортируем сцены по order и берем первую
        final sortedScenes = [...scenes]..sort((a, b) => a.order.compareTo(b.order));
        final firstScene = sortedScenes.first;
        
        // Используем finalUrl (готовое изображение) или draftUrl (черновик)
        final imageUrl = firstScene.finalUrl ?? firstScene.draftUrl;
        
        return RoundedImage(
          imageUrl: imageUrl,
          height: 180,
          width: double.infinity,
          radius: 0,
        );
      },
      loading: () => RoundedImage(
        imageUrl: null,
        height: 180,
        width: double.infinity,
        radius: 0,
      ),
      error: (_, __) => RoundedImage(
        imageUrl: null,
        height: 180,
        width: double.infinity,
        radius: 0,
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
