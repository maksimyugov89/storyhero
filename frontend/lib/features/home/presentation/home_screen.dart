import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../app/routes/route_names.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../features/books/data/book_providers.dart';
import '../../../core/widgets/rounded_image.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/widgets/magic/magic_text.dart';
import '../../../core/presentation/design_system/app_colors.dart';

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fadeAnimation = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );
    final booksAsync = ref.watch(booksProvider);

    useEffect(() {
      fadeAnimation.forward();
      return null;
    }, []);

    final shortcuts = [
      _HomeShortcut(
        label: 'Мои книги',
        icon: AppIcons.myBooks,
        onTap: () {
          debugPrint('[NAV] Home → /app/books');
          context.go(RouteNames.books);
        },
        gradient: AppColors.primaryGradient,
      ),
      _HomeShortcut(
        label: 'Дети',
        icon: AppIcons.childProfile,
        onTap: () {
          debugPrint('[NAV] Home → /app/children');
          context.go(RouteNames.children);
        },
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.secondaryVariant],
        ),
      ),
      _HomeShortcut(
        label: 'Настройки',
        icon: AppIcons.profile,
        onTap: () {
          debugPrint('[NAV] Home → /app/settings');
          context.go(RouteNames.settings);
        },
        gradient: LinearGradient(
          colors: [AppColors.tertiary, AppColors.primary],
        ),
      ),
    ];

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_main.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: ShaderMask(
            shaderCallback: (bounds) => AppColors.magicGradient.createShader(
              Rect.fromLTWH(0, 0, bounds.width, bounds.height),
            ),
            child: Text(
              'StoryHero',
              style: safeCopyWith(
                AppTypography.headlineSmall,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ).copyWith(
                shadows: [
                  Shadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                  Shadow(
                    color: AppColors.secondary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: FadeTransition(
          opacity: fadeAnimation,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingMD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                
                // Приветствие с градиентом
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.magicGradient.createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                  ),
                  child: Text(
                    'Добро пожаловать!',
                    style: safeCopyWith(
                      AppTypography.headlineLarge,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ).copyWith(
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withOpacity(0.6),
                          blurRadius: 16,
                          offset: const Offset(0, 3),
                        ),
                        Shadow(
                          color: AppColors.secondary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                        Shadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Главная кнопка - Создать книгу
                AppMagicCard(
                  onTap: () {
                    debugPrint('[NAV] Home → /app/generate');
                    context.go(RouteNames.generate);
                  },
                  selected: false,
                  padding: AppSpacing.paddingLG,
                  child: Row(
                    children: [
                      // Убрали Container с BoxDecoration (gradient и boxShadow) - теперь просто иконка без ореола
                      AssetIcon(
                        assetPath: AppIcons.generateStory,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AssetIcon(
                                  assetPath: AppIcons.magicStar,
                                  size: 20,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Создать книгу',
                                  style: safeCopyWith(
                                    AppTypography.headlineSmall,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Персонализированная история для вашего ребёнка',
                              style: safeCopyWith(
                                AppTypography.bodySmall,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Короткие карточки
                Row(
                  children: shortcuts.map((item) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: item != shortcuts.last ? AppSpacing.sm : 0,
                        ),
                        child: AppMagicCard(
                          onTap: item.onTap,
                          padding: AppSpacing.paddingMD,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AssetIcon(
                                assetPath: item.icon,
                                size: 48,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              SizedBox(
                                height: 40,
                                child: Text(
                                  item.label,
                                  textAlign: TextAlign.center,
                                  style: safeCopyWith(
                                    AppTypography.labelLarge,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Недавние книги
                booksAsync.when(
                  data: (books) {
                    if (books.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    final recentBooks = books.take(5).toList();
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Недавние книги',
                          style: safeCopyWith(AppTypography.headlineSmall),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: recentBooks.length,
                            itemBuilder: (context, index) {
                              final book = recentBooks[index];
                              return Container(
                                width: 140,
                                height: 200,
                                margin: EdgeInsets.only(
                                  right: index < recentBooks.length - 1
                                      ? AppSpacing.md
                                      : 0,
                                ),
                                child: AppMagicCard(
                                  onTap: () => context.go(RouteNames.bookView.replaceAll(':id', book.id)),
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Обложка с фиксированным соотношением сторон
                                      AspectRatio(
                                        aspectRatio: 140 / 120,
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                          child: _RecentBookCoverImage(
                                            coverUrl: book.coverUrl,
                                            bookId: book.id,
                                          ),
                                        ),
                                      ),
                                      // Текстовая часть с гибкой высотой
                                      Expanded(
                                        child: Padding(
                                        padding: AppSpacing.paddingSM,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  book.title,
                                                  style: safeCopyWith(AppTypography.labelLarge),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  softWrap: true,
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
                                                softWrap: false,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Виджет для отображения обложки книги в разделе "Недавние книги"
/// Использует coverUrl, если он есть, иначе пытается получить первое изображение из сцен
class _RecentBookCoverImage extends ConsumerWidget {
  final String? coverUrl;
  final String bookId;

  const _RecentBookCoverImage({
    required this.coverUrl,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Если есть coverUrl, используем его
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return RoundedImage(
        imageUrl: coverUrl,
        width: double.infinity,
        height: double.infinity,
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
            width: double.infinity,
            height: double.infinity,
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
          width: double.infinity,
          height: double.infinity,
          radius: 0,
        );
      },
      loading: () => RoundedImage(
        imageUrl: null,
        width: double.infinity,
        height: double.infinity,
        radius: 0,
      ),
      error: (_, __) => RoundedImage(
        imageUrl: null,
        width: double.infinity,
        height: double.infinity,
        radius: 0,
      ),
    );
  }
}

class _HomeShortcut {
  final String label;
  final String icon;
  final VoidCallback onTap;
  final Gradient gradient;

  _HomeShortcut({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.gradient,
  });
}
