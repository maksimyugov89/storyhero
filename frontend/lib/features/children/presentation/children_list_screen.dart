import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes/route_names.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/models/child.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/buttons/app_fab.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/rounded_image.dart';
import '../../../ui/components/asset_icon.dart';
import 'child_edit_screen.dart';

final childrenProvider = FutureProvider<List<Child>>((ref) async {
  final api = ref.watch(backendApiProvider);
  return await api.getChildren();
});

class ChildrenListScreen extends HookConsumerWidget {
  const ChildrenListScreen({super.key});

  Future<void> _handleDeleteChild(BuildContext context, WidgetRef ref, Child child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить ребёнка?'),
        content: Text('Вы уверены, что хотите удалить ${child.name}? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final api = ref.read(backendApiProvider);
        await api.deleteChild(child.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${child.name} удалён'),
              backgroundColor: AppColors.success,
            ),
          );
          ref.invalidate(childrenProvider);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fadeAnimation = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );
    final childrenAsync = ref.watch(childrenProvider);

    useEffect(() {
      fadeAnimation.forward();
      return null;
    }, []);

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_main.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Дети',
          leading: IconButton(
            icon: AssetIcon(
              assetPath: AppIcons.back,
              size: 24,
              color: AppColors.onBackground,
            ),
            onPressed: () => context.go(RouteNames.home),
          ),
        ),
        body: FadeTransition(
          opacity: fadeAnimation,
          child: childrenAsync.when(
            data: (children) {
              if (children.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AssetIcon(
                        assetPath: AppIcons.childProfile,
                        size: 80,
                        color: AppColors.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Нет детей',
                        style: AppTypography.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Добавьте первого ребёнка',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: AppSpacing.paddingMD,
                itemCount: children.length,
                itemBuilder: (context, index) {
                  final child = children[index];
                  
                  return Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppMagicCard(
                      onTap: () => context.push(RouteNames.childProfile.replaceAll(':id', child.id)),
                      padding: AppSpacing.paddingMD,
                      child: Row(
                        children: [
                          // Фото
                          if (child.faceUrl != null && child.faceUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: RoundedImage(
                                imageUrl: child.faceUrl,
                                width: 60,
                                height: 60,
                                radius: 12,
                              ),
                            )
                          else
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  child.name[0].toUpperCase(),
                                  style: AppTypography.headlineSmall.copyWith(
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          
                          const SizedBox(width: AppSpacing.md),
                          
                          // Информация
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  child.name,
                                  style: AppTypography.headlineSmall,
                                ),
                                Text(
                                  '${child.age} лет',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Quick actions
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: AssetIcon(
                                  assetPath: AppIcons.edit,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                onPressed: () {
                                  context.push(
                                    '/app/children/${child.id}/edit',
                                    extra: child,
                                  );
                                },
                              ),
                              IconButton(
                                icon: AssetIcon(
                                  assetPath: AppIcons.delete,
                                  size: 20,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _handleDeleteChild(context, ref, child),
                              ),
                              IconButton(
                                icon: AssetIcon(
                                  assetPath: AppIcons.myBooks,
                                  size: 20,
                                  color: AppColors.secondary,
                                ),
                                onPressed: () {
                                  context.push(RouteNames.childBooks.replaceAll(':id', child.id));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const LoadingWidget(),
            error: (error, stack) => ErrorDisplayWidget(
              error: error,
              onRetry: () => ref.refresh(childrenProvider),
            ),
          ),
        ),
        floatingActionButton: AppFAB(
          iconAsset: AppIcons.addBook,
          tooltip: 'Добавить ребёнка',
          onPressed: () => context.push(RouteNames.childrenNew),
        ),
      ),
    );
  }
}
