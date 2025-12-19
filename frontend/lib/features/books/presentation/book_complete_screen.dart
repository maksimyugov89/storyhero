import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import '../../../app/routes/route_names.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/rounded_image.dart';
import '../../../ui/components/asset_icon.dart';
import '../data/book_providers.dart';

class BookCompleteScreen extends HookConsumerWidget {
  final String bookId;

  const BookCompleteScreen({
    super.key,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider(bookId));
    final isProcessingPayment = useState(false);
    final isDownloading = useState(false);
    final paymentError = useState<String?>(null);

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_final_story.png',
      overlayOpacity: 0.3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Книга готова!',
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
            final isPaid = book.isPaid;
            final pdfUrl = book.finalPdfUrl;

            return SingleChildScrollView(
              padding: AppSpacing.paddingMD,
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.lg),

                  // Успешное завершение
                  _buildSuccessHeader(context),

                  const SizedBox(height: AppSpacing.xl),

                  // Превью книги
                  _buildBookPreview(context, book.title, book.coverUrl),

                  const SizedBox(height: AppSpacing.xl),

                  // Карточка с ценой и оплатой
                  _buildPaymentCard(
                    context,
                    ref,
                    isPaid: isPaid,
                    isProcessing: isProcessingPayment.value,
                    error: paymentError.value,
                    onPayPressed: () async {
                      isProcessingPayment.value = true;
                      paymentError.value = null;

                      try {
                        final api = ref.read(backendApiProvider);
                        // Вызываем API для создания платежа
                        final paymentUrl = await api.createPayment(bookId);

                        if (paymentUrl != null) {
                          // Открываем страницу оплаты
                          final uri = Uri.parse(paymentUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        } else {
                          // Демо-режим: имитируем успешную оплату
                          await Future.delayed(const Duration(seconds: 2));
                          await api.confirmPayment(bookId);
                          ref.invalidate(bookProvider(bookId));

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Text('Оплата успешно подтверждена!')),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        paymentError.value = 'Ошибка оплаты: ${e.toString().replaceAll('Exception: ', '')}';
                      } finally {
                        isProcessingPayment.value = false;
                      }
                    },
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Кнопка скачивания PDF
                  _buildDownloadSection(
                    context,
                    isPaid: isPaid,
                    pdfUrl: pdfUrl,
                    isDownloading: isDownloading.value,
                    onDownloadPressed: () async {
                      if (!isPaid || pdfUrl == null) return;

                      isDownloading.value = true;

                      try {
                        final uri = Uri.parse(pdfUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Не удалось открыть ссылку для скачивания'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Ошибка скачивания: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        isDownloading.value = false;
                      }
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Секция заказа печатной книги
                  _buildPrintOrderSection(context, bookId),

                  const SizedBox(height: AppSpacing.lg),

                  // Кнопка "Вернуться к книгам"
                  OutlinedButton.icon(
                    onPressed: () => context.go(RouteNames.books),
                    icon: const Icon(Icons.library_books),
                    label: const Text('Мои книги'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            );
          },
          loading: () => const LoadingWidget(),
          error: (error, stack) => ErrorDisplayWidget(
            error: error,
            onRetry: () => ref.invalidate(bookProvider(bookId)),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader(BuildContext context) {
    return Column(
      children: [
        // Lottie анимация успеха
        SizedBox(
          width: 120,
          height: 120,
          child: Lottie.asset(
            'assets/animations/login_magic_swirl.json',
            fit: BoxFit.contain,
            repeat: true,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '🎉 Книга создана!',
          style: safeCopyWith(
            AppTypography.headlineLarge,
            color: AppColors.success,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Ваша персональная книга готова к скачиванию',
          style: safeCopyWith(
            AppTypography.bodyLarge,
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBookPreview(BuildContext context, String title, String? coverUrl) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        children: [
          // Обложка
          Container(
            width: 160,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: coverUrl != null
                  ? RoundedImage(
                      imageUrl: coverUrl,
                      width: 160,
                      height: 220,
                      radius: 12,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: AssetIcon(
                          assetPath: AppIcons.library,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.headlineSmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    WidgetRef ref, {
    required bool isPaid,
    required bool isProcessing,
    required String? error,
    required VoidCallback onPayPressed,
  }) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        children: [
          // Заголовок
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPaid ? Colors.green.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPaid ? Icons.check_circle : Icons.payment,
                  color: isPaid ? Colors.green : AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaid ? 'Оплачено' : 'Стоимость книги',
                      style: safeCopyWith(
                        AppTypography.headlineSmall,
                        fontWeight: FontWeight.bold,
                        color: isPaid ? Colors.green : null,
                      ),
                    ),
                    if (!isPaid)
                      Text(
                        'Получите PDF в высоком качестве',
                        style: safeCopyWith(
                          AppTypography.bodySmall,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isPaid)
                Text(
                  '499 ₽',
                  style: safeCopyWith(
                    AppTypography.headlineMedium,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),

          if (!isPaid) ...[
            const SizedBox(height: AppSpacing.lg),

            // Что входит в покупку
            Container(
              padding: AppSpacing.paddingSM,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildFeatureRow(Icons.picture_as_pdf, 'PDF файл в высоком качестве'),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.hd, 'Изображения без водяных знаков'),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.print, 'Готов к печати'),
                ],
              ),
            ),

            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: AppSpacing.paddingSM,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: safeCopyWith(
                          AppTypography.bodySmall,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Кнопка оплаты
            AppMagicButton(
              onPressed: isProcessing ? null : onPayPressed,
              isLoading: isProcessing,
              fullWidth: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.credit_card, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    isProcessing ? 'Обработка...' : 'Оплатить 499 ₽',
                    style: safeCopyWith(
                      AppTypography.labelLarge,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isPaid) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: AppSpacing.paddingSM,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Спасибо за покупку! Теперь вы можете скачать PDF.',
                      style: safeCopyWith(
                        AppTypography.bodySmall,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: safeCopyWith(
              AppTypography.bodySmall,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadSection(
    BuildContext context, {
    required bool isPaid,
    required String? pdfUrl,
    required bool isDownloading,
    required VoidCallback onDownloadPressed,
  }) {
    final canDownload = isPaid && pdfUrl != null;

    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: canDownload
                      ? AppColors.primary.withOpacity(0.2)
                      : AppColors.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.picture_as_pdf,
                  color: canDownload ? AppColors.primary : AppColors.onSurfaceVariant,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Скачать PDF',
                      style: safeCopyWith(
                        AppTypography.headlineSmall,
                        fontWeight: FontWeight.bold,
                        color: canDownload ? null : AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      canDownload
                          ? 'Высокое качество, готов к печати'
                          : 'Доступно после оплаты',
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

          const SizedBox(height: AppSpacing.lg),

          // Кнопка скачивания
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canDownload && !isDownloading ? onDownloadPressed : null,
              icon: isDownloading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      canDownload ? Icons.download : Icons.lock,
                      color: canDownload ? Colors.white : AppColors.onSurfaceVariant,
                    ),
              label: Text(
                isDownloading
                    ? 'Скачивание...'
                    : canDownload
                        ? '📥 Скачать PDF'
                        : '🔒 Оплатите для скачивания',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: canDownload ? Colors.white : AppColors.onSurfaceVariant,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canDownload ? Colors.green : AppColors.surfaceVariant,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (!canDownload) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '↑ Сначала оплатите книгу выше',
              style: safeCopyWith(
                AppTypography.bodySmall,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrintOrderSection(BuildContext context, String bookId) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade400,
                      Colors.deepOrange.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_printshop,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📚 Печатная книга',
                      style: safeCopyWith(
                        AppTypography.headlineSmall,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Закажите книгу в печатном формате',
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

          const SizedBox(height: AppSpacing.md),

          // Описание
          Container(
            padding: AppSpacing.paddingSM,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _buildPrintFeature(Icons.straighten, 'Формат: A5, B5, A4'),
                const SizedBox(height: 6),
                _buildPrintFeature(Icons.auto_stories, '10 или 20 страниц'),
                const SizedBox(height: 6),
                _buildPrintFeature(Icons.menu_book, 'Мягкий или твёрдый переплёт'),
                const SizedBox(height: 6),
                _buildPrintFeature(Icons.card_giftcard, 'Подарочная упаковка'),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Кнопка заказа
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push(RouteNames.bookOrder.replaceAll(':id', bookId));
              },
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: const Text(
                '📦 Заказать печатную книгу',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          
          Text(
            'от 950 ₽ • Доставка по всей России',
            style: safeCopyWith(
              AppTypography.bodySmall,
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPrintFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.orange.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: safeCopyWith(
              AppTypography.bodySmall,
              color: Colors.orange.shade800,
            ),
          ),
        ),
      ],
    );
  }
}

