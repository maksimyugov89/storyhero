import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes/route_names.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/presentation/widgets/feedback/app_loader.dart';
import '../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/rounded_image.dart';
import '../../../ui/components/asset_icon.dart';
import '../data/book_providers.dart';

class FinalizationScreen extends ConsumerStatefulWidget {
  final String bookId;

  const FinalizationScreen({
    super.key,
    required this.bookId,
  });

  @override
  ConsumerState<FinalizationScreen> createState() => _FinalizationScreenState();
}

class _FinalizationScreenState extends ConsumerState<FinalizationScreen> {
  Timer? _pollingTimer;
  bool _isFinalizing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startFinalization();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _startFinalization() async {
    setState(() {
      _isFinalizing = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(backendApiProvider);
      await api.finalizeBook(widget.bookId);
      _startPolling();
    } catch (e) {
      setState(() {
        _isFinalizing = false;
        _errorMessage = 'Ошибка начала финализации: ${e.toString()}';
      });
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;

      try {
        final bookAsync = ref.read(bookProvider(widget.bookId).future);
        final book = await bookAsync;

        if (book.status == 'final') {
          _pollingTimer?.cancel();
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                context.go(RouteNames.bookView.replaceAll(':id', widget.bookId));
              }
            });
          }
        } else {
          ref.invalidate(bookProvider(widget.bookId));
        }
      } catch (e) {
        print('[FinalizationScreen] Polling error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookProvider(widget.bookId));

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_task_status.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Финализация',
          leading: IconButton(
            icon: AssetIcon(
              assetPath: AppIcons.back,
              size: 24,
              color: AppColors.onBackground,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.home);
              }
            },
          ),
        ),
        body: bookAsync.when(
          data: (book) {
            if (book.status == 'final') {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: AssetIcon(
                        assetPath: AppIcons.success,
                        size: 60,
                        color: AppColors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Книга готова!',
                      style: AppTypography.headlineLarge.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Переходим к просмотру...',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: AppSpacing.paddingMD,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  
                  // Анимация
                  AppMagicLoader(
                    size: 80,
                    glowColor: AppColors.primary,
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  Text(
                    'Финализация книги',
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Превью книги
                  if (book.coverUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: RoundedImage(
                        imageUrl: book.coverUrl,
                        height: 200,
                        width: 150,
                        radius: 16,
                      ),
                    ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Кнопка подтверждения
                  AppMagicButton(
                    onPressed: () {
                      context.go(RouteNames.bookView.replaceAll(':id', widget.bookId));
                    },
                    fullWidth: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AssetIcon(
                          assetPath: AppIcons.secureBook,
                          size: 24,
                          color: AppColors.onPrimary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Подтвердить',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppMagicLoader(size: 80),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Загрузка...',
                  style: AppTypography.bodyLarge,
                ),
              ],
            ),
          ),
          error: (error, stack) => ErrorDisplayWidget(
            error: error,
            onRetry: () => ref.invalidate(bookProvider(widget.bookId)),
          ),
        ),
      ),
    );
  }
}
