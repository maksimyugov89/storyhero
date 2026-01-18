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
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/rounded_image.dart';
import '../../../ui/components/asset_icon.dart';
import 'child_edit_screen.dart';
import '../../../ui/layouts/desktop_container.dart';

final childrenProvider = FutureProvider<List<Child>>((ref) async {
  final api = ref.watch(backendApiProvider);
  return await api.getChildren();
});

class AnimatedAddButton extends HookWidget {
  final Color primaryColor;
  final VoidCallback onTap;

  const AnimatedAddButton({
    super.key,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final animationController = useAnimationController(
        duration: const Duration(seconds: 2),
    );

    useEffect(() {
      animationController.repeat(reverse: true);
      // useAnimationController автоматически освобождает контроллер при размонтировании
      // Не нужно вызывать dispose() вручную
      return () {
        animationController.stop();
      };
    }, []);

    final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeInOut,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: scaleAnimation.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3 * scaleAnimation.value),
                    blurRadius: 12 * scaleAnimation.value,
                    spreadRadius: 2 * scaleAnimation.value,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.1),
                      primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: AssetIcon(
                  assetPath: AppIcons.add,
                  size: 32,
                  color: primaryColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    final slideAnimation = useMemoized(
      () => Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: fadeAnimation,
          curve: Curves.easeOutCubic,
        ),
      ),
      [fadeAnimation],
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
          child: SlideTransition(
            position: slideAnimation,
            child: DesktopContainer(
              maxWidth: 1100,
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
                            style: safeCopyWith(
                              AppTypography.bodyMedium,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AnimatedAddButton(
                            primaryColor: AppColors.primary,
                            onTap: () => context.push(RouteNames.childrenNew),
                          ),
                        ],
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final isDesktop = screenWidth >= 900;
                      final crossAxisCount = screenWidth >= 1200 ? 3 : screenWidth >= 900 ? 2 : 1;
                      const gap = 20.0;
                      const cardWidth = 320.0;
                      final gridWidth = cardWidth * crossAxisCount + gap * (crossAxisCount - 1);

                      if (!isDesktop) {
                        return ListView.builder(
                          padding: AppSpacing.paddingMD,
                          itemCount: children.length + 1,
                          itemBuilder: (context, index) {
                            if (index == children.length) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  top: AppSpacing.md,
                                  bottom: AppSpacing.lg,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedAddButton(
                                    primaryColor: AppColors.primary,
                                    onTap: () => context.push(RouteNames.childrenNew),
                                  ),
                                ),
                              );
                            }

                            final child = children[index];
                            return _AppearSlideFade(
                              delay: Duration(milliseconds: 40 * index),
                              child: _HoverLift(
                                child: Padding(
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
                                                style: safeCopyWith(
                                                  AppTypography.headlineSmall,
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
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                child.name,
                                                style: AppTypography.headlineSmall,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                              ),
                                              Text(
                                                '${child.age} лет',
                                                style: safeCopyWith(
                                                  AppTypography.bodyMedium,
                                                  color: AppColors.onSurfaceVariant,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
                                ),
                              ),
                            );
                          },
                        );
                      }

                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: gridWidth),
                          child: GridView.builder(
                            padding: AppSpacing.paddingMD,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: gap,
                              mainAxisSpacing: gap,
                              childAspectRatio: 2.6,
                            ),
                            itemCount: children.length + 1,
                            itemBuilder: (context, index) {
                              if (index == children.length) {
                                return _AppearSlideFade(
                                  delay: Duration(milliseconds: 40 * index),
                                  child: _HoverLift(
                                    child: AppMagicCard(
                                      onTap: () => context.push(RouteNames.childrenNew),
                                      padding: AppSpacing.paddingMD,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          AssetIcon(
                                            assetPath: AppIcons.add,
                                            size: 28,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            'Добавить ребёнка',
                                            style: safeCopyWith(
                                              AppTypography.labelLarge,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final child = children[index];
                              return _AppearSlideFade(
                                delay: Duration(milliseconds: 40 * index),
                                child: _HoverLift(
                                  child: AppMagicCard(
                                    onTap: () => context.push(RouteNames.childProfile.replaceAll(':id', child.id)),
                                    padding: AppSpacing.paddingMD,
                                    child: Row(
                                      children: [
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
                                                style: safeCopyWith(
                                                  AppTypography.headlineSmall,
                                                  color: AppColors.onPrimary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                child.name,
                                                style: AppTypography.headlineSmall,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                              ),
                                              Text(
                                                '${child.age} лет',
                                                style: safeCopyWith(
                                                  AppTypography.bodyMedium,
                                                  color: AppColors.onSurfaceVariant,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
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
                                ),
                              );
                            },
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
          ),
        ),
      ),
    );
  }
}

class _AppearSlideFade extends StatefulWidget {
  const _AppearSlideFade({
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<_AppearSlideFade> createState() => _AppearSlideFadeState();
}

class _AppearSlideFadeState extends State<_AppearSlideFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = curve;
    _offset = Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curve);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

class _HoverLift extends StatefulWidget {
  const _HoverLift({required this.child});

  final Widget child;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: widget.child,
      ),
    );
  }
}
