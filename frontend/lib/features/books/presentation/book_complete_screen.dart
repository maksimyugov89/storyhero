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
    final paymentCheckTimer = useState<Timer?>(null);
    final actualIsPaid = useState<bool?>(null); // Локальное состояние для статуса оплаты
    
    // Функция для однократной проверки статуса оплаты
    Future<void> checkPaymentStatusOnce(WidgetRef ref) async {
      try {
        final api = ref.read(backendApiProvider);
        final paidStatus = await api.checkPaymentStatus(bookId);
        actualIsPaid.value = paidStatus;
      } catch (e) {
        print('[BookCompleteScreen] Ошибка проверки статуса оплаты при загрузке: $e');
        actualIsPaid.value = false;
      }
    }
    
    // Проверяем статус оплаты при загрузке экрана
    useEffect(() {
      if (actualIsPaid.value == null) {
        checkPaymentStatusOnce(ref);
      }
      return null;
    }, []);
    
    // Очищаем таймер при размонтировании виджета
    useEffect(() {
      return () {
        paymentCheckTimer.value?.cancel();
        paymentCheckTimer.value = null;
      };
    }, []);

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
            // Используем book.isPaid из ответа бэкенда (теперь он должен приходить)
            // actualIsPaid используется только как fallback при первой загрузке, пока проверяется
            final isPaid = actualIsPaid.value ?? book.isPaid;
            final pdfUrl = book.finalPdfUrl;
            
            // Отладочное логирование
            print('[BookCompleteScreen] isPaid from book.isPaid: ${book.isPaid}');
            print('[BookCompleteScreen] isPaid from actualIsPaid: ${actualIsPaid.value}');
            print('[BookCompleteScreen] final isPaid: $isPaid');
            print('[BookCompleteScreen] pdfUrl: $pdfUrl');

            return SingleChildScrollView(
              padding: AppSpacing.paddingMD,
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.lg),

                  // Успешное завершение
                  _buildSuccessHeader(context),

                  const SizedBox(height: AppSpacing.xl),

                  // Превью книги
                  _buildBookPreview(context, ref, book.title, book.coverUrl, book.id),

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
                            
                            // После открытия платежной страницы запускаем проверку статуса оплаты
                            _startPaymentStatusCheck(context, ref, paymentCheckTimer, bookId, actualIsPaid);
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.white),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text('После оплаты статус обновится автоматически'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.blue,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        } else {
                          // Демо-режим: имитируем успешную оплату
                          await Future.delayed(const Duration(seconds: 2));
                          final confirmed = await api.confirmPayment(bookId);
                          
                          if (confirmed) {
                            // Обновляем данные книги - используем refresh для немедленного обновления
                            ref.refresh(bookProvider(bookId));
                            
                            // Ждем обновления данных
                            await Future.delayed(const Duration(milliseconds: 500));
                            final updatedBook = await ref.read(bookProvider(bookId).future);
                            
                            // Обновляем локальное состояние из обновленной книги (теперь бэкенд возвращает is_paid)
                            actualIsPaid.value = updatedBook.isPaid;
                            
                            print('[BookCompleteScreen] После подтверждения оплаты:');
                            print('[BookCompleteScreen] updatedBook.isPaid: ${updatedBook.isPaid}');
                            print('[BookCompleteScreen] updatedBook.finalPdfUrl: ${updatedBook.finalPdfUrl}');

                          if (context.mounted) {
                              if (updatedBook.isPaid && updatedBook.finalPdfUrl != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                content: Row(
                                  children: [
                                        Icon(Icons.check_circle, color: Colors.white),
                                        SizedBox(width: 8),
                                        Expanded(child: Text('Оплата успешно подтверждена! PDF доступен для скачивания.')),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                    duration: Duration(seconds: 3),
                              ),
                            );
                              } else if (updatedBook.isPaid && updatedBook.finalPdfUrl == null) {
                                // Оплата подтверждена, но PDF еще не готов
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.white),
                                        SizedBox(width: 8),
                                        Expanded(child: Text('Оплата подтверждена. PDF будет доступен через несколько секунд.')),
                                      ],
                                    ),
                                    backgroundColor: Colors.blue,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              } else {
                                // Если статус не обновился, запускаем проверку
                                _startPaymentStatusCheck(context, ref, paymentCheckTimer, bookId, actualIsPaid);
                              }
                            }
                          } else {
                            if (context.mounted) {
                              paymentError.value = 'Не удалось подтвердить оплату. Попробуйте позже.';
                            }
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

                  // Кнопка скачивания PDF (показывается всегда, активна только если оплачено)
                  _buildDownloadSection(
                    context,
                    ref,
                    isPaid: isPaid,
                    pdfUrl: pdfUrl,
                    isDownloading: isDownloading.value,
                    onDownloadPressed: () async {
                      // Используем actualIsPaid для определения статуса оплаты
                      final currentIsPaid = actualIsPaid.value ?? false;
                      
                      // Получаем актуальные данные книги для pdfUrl
                      final currentBook = await ref.read(bookProvider(bookId).future);
                      final currentPdfUrl = currentBook.finalPdfUrl;
                      
                      if (!currentIsPaid || currentPdfUrl == null) {
                        // Если еще не оплачено, пытаемся проверить статус
                        if (!currentIsPaid) {
                          isDownloading.value = true;
                          try {
                            final api = ref.read(backendApiProvider);
                            final paidStatus = await api.checkPaymentStatus(bookId);
                            actualIsPaid.value = paidStatus; // Обновляем локальное состояние
                            
                            if (paidStatus) {
                              // Обновляем данные книги
                              ref.refresh(bookProvider(bookId));
                              await Future.delayed(const Duration(milliseconds: 500));
                              final updatedBook = await ref.read(bookProvider(bookId).future);
                              if (updatedBook.finalPdfUrl != null) {
                                // Теперь можно скачать
                                final uri = Uri.parse(updatedBook.finalPdfUrl!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Начинаем загрузку PDF...'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  }
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('PDF пока не готов. Попробуйте через минуту.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Книга не оплачена. Пожалуйста, оплатите сначала.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Ошибка проверки оплаты: ${e.toString().replaceAll('Exception: ', '')}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            isDownloading.value = false;
                          }
                        } else {
                          // currentIsPaid == true, но currentPdfUrl == null
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PDF файл еще не готов. Пожалуйста, попробуйте позже.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                        return;
                      }

                      isDownloading.value = true;

                      try {
                        final uri = Uri.parse(currentPdfUrl);
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

  Widget _buildBookPreview(BuildContext context, WidgetRef ref, String title, String? coverUrl, String bookId) {
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
              child: _CompleteBookCoverImage(
                coverUrl: coverUrl,
                bookId: bookId,
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
    BuildContext context,
    WidgetRef ref, {
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
                          : isPaid
                              ? 'PDF готовится, попробуйте позже'
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

          // Кнопка скачивания PDF
          AppMagicButton(
              onPressed: canDownload && !isDownloading ? onDownloadPressed : null,
            isLoading: isDownloading,
            fullWidth: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  canDownload ? Icons.download : Icons.lock,
                        color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                isDownloading
                    ? 'Скачивание...'
                    : canDownload
                            ? 'Скачать PDF'
                            : isPaid
                                ? 'PDF готовится'
                                : 'Оплатить для скачивания',
                    style: safeCopyWith(
                      AppTypography.labelLarge,
                      color: Colors.white,
                  fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                ),
              ),
              ],
            ),
          ),

          if (!isPaid) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '↑ Сначала оплатите книгу выше',
              style: safeCopyWith(
                AppTypography.bodySmall,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ] else if (!canDownload) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'PDF файл готовится, попробуйте через минуту',
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

          // Кнопка заказа печатной книги
          AppMagicButton(
              onPressed: () {
                context.push(RouteNames.bookOrder.replaceAll(':id', bookId));
              },
            fullWidth: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                '📦 Заказать печатную книгу',
                  style: safeCopyWith(
                    AppTypography.labelLarge,
                  color: Colors.white,
                    fontWeight: FontWeight.bold,
                ),
              ),
              ],
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

/// Виджет для отображения обложки книги на экране завершения
/// Использует coverUrl, если он есть, иначе пытается получить первое изображение из сцен
class _CompleteBookCoverImage extends ConsumerWidget {
  final String? coverUrl;
  final String bookId;

  const _CompleteBookCoverImage({
    required this.coverUrl,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Если есть coverUrl, используем его
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return RoundedImage(
        imageUrl: coverUrl,
        width: 160,
        height: 220,
        radius: 12,
      );
    }

    // Если coverUrl отсутствует, пытаемся получить первое изображение из сцен
    final scenesAsync = ref.watch(bookScenesProvider(bookId));

    return scenesAsync.when(
      data: (scenes) {
        if (scenes.isEmpty) {
          // Нет сцен - показываем placeholder
          return Container(
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
          );
        }

        // Сортируем сцены по order и берем первую
        final sortedScenes = [...scenes]..sort((a, b) => a.order.compareTo(b.order));
        final firstScene = sortedScenes.first;

        // Используем finalUrl (готовое изображение) или draftUrl (черновик)
        final imageUrl = firstScene.finalUrl ?? firstScene.draftUrl;

        if (imageUrl != null && imageUrl.isNotEmpty) {
          return RoundedImage(
            imageUrl: imageUrl,
            width: 160,
            height: 220,
            radius: 12,
          );
        }

        // Если изображение отсутствует, показываем placeholder
        return Container(
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
        );
      },
      loading: () => Container(
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
      error: (_, __) => Container(
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
    );
  }
}

/// Запускает периодическую проверку статуса оплаты
void _startPaymentStatusCheck(
  BuildContext context,
  WidgetRef ref,
  ValueNotifier<Timer?> timerNotifier,
  String bookId,
  ValueNotifier<bool?> actualIsPaid,
) {
    // Останавливаем предыдущий таймер, если он есть
    timerNotifier.value?.cancel();
    
    int attempts = 0;
    const maxAttempts = 30; // Проверяем 30 раз (5 минут при интервале 10 секунд)
    
    timerNotifier.value = Timer.periodic(const Duration(seconds: 10), (timer) async {
      attempts++;
      
      try {
        final api = ref.read(backendApiProvider);
        final isPaid = await api.checkPaymentStatus(bookId);
        
        if (isPaid) {
          // Оплата подтверждена, обновляем локальное состояние
          actualIsPaid.value = true;
          
          // Оплата подтверждена, обновляем данные книги
          timer.cancel();
          timerNotifier.value = null;
          
          // Обновляем данные книги - используем refresh для немедленного обновления
          ref.refresh(bookProvider(bookId));
          
          // Ждем обновления данных
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Проверяем, что книга обновилась
          final updatedBook = await ref.read(bookProvider(bookId).future);
          
          if (context.mounted) {
            if (updatedBook.finalPdfUrl != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Оплата подтверждена! PDF доступен для скачивания.'),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            } else {
              // Если PDF еще не готов, показываем сообщение
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Оплата подтверждена. PDF будет доступен через несколько секунд.'),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } else if (attempts >= maxAttempts) {
          // Превышено максимальное количество попыток
          timer.cancel();
          timerNotifier.value = null;
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Проверка оплаты завершена. Обновите страницу вручную.'),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('[BookCompleteScreen] Ошибка проверки статуса оплаты: $e');
        // Продолжаем проверку при ошибке
      }
    });
}

