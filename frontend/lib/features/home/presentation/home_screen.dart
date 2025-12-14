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
import '../../../core/presentation/widgets/buttons/app_fab.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../features/books/data/book_providers.dart';
import '../../../core/widgets/rounded_image.dart';

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

    // Мемоизируем shortcuts, чтобы они не пересоздавались при каждом build
    // Это предотвращает постоянные пересборки AssetIcon виджетов
    final shortcuts = useMemoized(() => [
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
    ], []);

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_main.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'StoryHero',
          actions: [
            IconButton(
              icon: AssetIcon(
                assetPath: AppIcons.profile,
                size: 24,
                color: AppColors.onBackground,
              ),
              onPressed: () {
                debugPrint('[NAV] Home → /app/settings');
                context.go(RouteNames.settings);
              },
            ),
          ],
        ),
        body: FadeTransition(
          opacity: fadeAnimation,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingMD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                
                // Приветствие
                Text(
                  'Добро пожаловать!',
                  style: AppTypography.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Что хотите сделать?',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.onSurfaceVariant,
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
                                  style: AppTypography.headlineSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Персонализированная история для вашего ребёнка',
                              style: AppTypography.bodySmall.copyWith(
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
                                  style: AppTypography.labelLarge.copyWith(
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
                          style: AppTypography.headlineSmall,
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
                                margin: EdgeInsets.only(
                                  right: index < recentBooks.length - 1
                                      ? AppSpacing.md
                                      : 0,
                                ),
                                child: AppMagicCard(
                                  onTap: () => context.go(RouteNames.bookView.replaceAll(':id', book.id)),
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Обложка с фиксированным соотношением сторон
                                      AspectRatio(
                                        aspectRatio: 140 / 120,
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                          child: RoundedImage(
                                            imageUrl: book.coverUrl,
                                            width: double.infinity,
                                            height: double.infinity,
                                            radius: 0,
                                          ),
                                        ),
                                      ),
                                      // Текстовая часть с достаточной высотой для предотвращения overflow
                                      Padding(
                                        padding: AppSpacing.paddingSM,
                                        child: SizedBox(
                                          height: 70, // Увеличена высота для предотвращения overflow
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  book.title,
                                                  style: AppTypography.labelLarge,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(height: AppSpacing.xs),
                                              Text(
                                                'Книга',
                                                style: AppTypography.bodySmall.copyWith(
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
        floatingActionButton: AppFAB(
          iconAsset: AppIcons.addBook,
          tooltip: 'Создать книгу',
          onPressed: () {
            debugPrint('[NAV] Home → ${RouteNames.generate}');
            context.go(RouteNames.generate);
          },
        ),
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
