import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
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
import '../../../core/widgets/phone_input_field.dart';
import '../../../core/widgets/address_input_fields.dart';
import '../../../core/utils/phone_formatter.dart';
import '../../../ui/components/asset_icon.dart';
import '../data/book_providers.dart';
import '../../../ui/layouts/desktop_container.dart';

/// Размеры книги
enum BookSize {
  a5('A5 (Маленькая)', '148×210 мм — компактный формат'),
  b5('B5 (Средняя)', '176×250 мм — классический формат'),
  a4('A4 (Большая)', '210×297 мм — подарочный формат');

  final String name;
  final String description;

  const BookSize(this.name, this.description);
}

/// Количество страниц
enum PageCount {
  pages10('10 страниц', 10),
  pages20('20 страниц', 20);

  final String name;
  final int count;

  const PageCount(this.name, this.count);
}

/// Тип переплёта
enum BindingType {
  soft('Мягкий переплёт', 'Гибкая обложка, лёгкая книга'),
  hard('Твёрдый переплёт', 'Прочная обложка, премиум качество');

  final String name;
  final String description;

  const BindingType(this.name, this.description);
}

/// Тип упаковки
enum PackagingType {
  simple('Простая упаковка', 'Защитная плёнка и картонная коробка', 0),
  gift('Подарочная упаковка', 'Красивая коробка с лентой и открыткой', 250);

  final String name;
  final String description;
  final int additionalPrice;

  const PackagingType(this.name, this.description, this.additionalPrice);
}

/// Таблица цен: [Формат][Страницы][Переплет] = Цена
const Map<BookSize, Map<PageCount, Map<BindingType, int>>> _priceTable = {
  BookSize.a5: {
    PageCount.pages10: {BindingType.soft: 950, BindingType.hard: 1900},
    PageCount.pages20: {BindingType.soft: 1350, BindingType.hard: 2300},
  },
  BookSize.b5: {
    PageCount.pages10: {BindingType.soft: 1200, BindingType.hard: 2400},
    PageCount.pages20: {BindingType.soft: 1700, BindingType.hard: 2900},
  },
  BookSize.a4: {
    PageCount.pages10: {BindingType.soft: 1600, BindingType.hard: 3100},
    PageCount.pages20: {BindingType.soft: 2200, BindingType.hard: 3800},
  },
};

/// Получить базовую цену из таблицы
int getBasePrice(BookSize size, PageCount pages, BindingType binding) {
  return _priceTable[size]?[pages]?[binding] ?? 0;
}

class BookOrderScreen extends HookConsumerWidget {
  final String bookId;

  const BookOrderScreen({
    super.key,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider(bookId));
    final scenesAsync = ref.watch(bookScenesProvider(bookId));
    
    // Состояние выбора
    final selectedSize = useState<BookSize>(BookSize.a5);
    final selectedPages = useState<PageCount>(PageCount.pages20);
    final selectedBinding = useState<BindingType>(BindingType.soft);
    final selectedPackaging = useState<PackagingType>(PackagingType.simple);
    
    // Данные доставки
    final nameController = useTextEditingController();
    final phoneController = useTextEditingController();
    // Поля адреса
    final cityController = useTextEditingController();
    final streetController = useTextEditingController();
    final houseController = useTextEditingController();
    final apartmentController = useTextEditingController();
    final postalCodeController = useTextEditingController();
    final commentController = useTextEditingController();
    
    final isProcessing = useState(false);
    final orderError = useState<String?>(null);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // Расчёт итоговой стоимости
    int calculateTotal() {
      final basePrice = getBasePrice(
        selectedSize.value,
        selectedPages.value,
        selectedBinding.value,
      );
      return basePrice + selectedPackaging.value.additionalPrice;
    }

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_final_story.png',
      overlayOpacity: 0.3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Заказать книгу',
          leading: IconButton(
            icon: AssetIcon(
              assetPath: AppIcons.back,
              size: 24,
              color: AppColors.onBackground,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: bookAsync.when(
          data: (book) {
            // Получаем обложку: сначала из book.coverUrl, если нет - из первой сцены
            String? coverUrl = book.coverUrl;
            if ((coverUrl == null || coverUrl.isEmpty)) {
              final scenes = scenesAsync.valueOrNull;
              if (scenes != null && scenes.isNotEmpty) {
                final firstScene = scenes.firstWhere(
                  (s) => s.order == 0,
                  orElse: () => scenes.first,
                );
                coverUrl = firstScene.finalUrl ?? firstScene.draftUrl;
              }
            }
            
            return DesktopContainer(
              maxWidth: 1100,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Form(
                    key: formKey,
                    child: ListView(
                      padding: AppSpacing.paddingMD,
                      children: [
                  // Заголовок
                  _buildHeader(context, book.title, coverUrl),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Выбор размера
                  _buildSizeSelector(context, selectedSize),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Выбор количества страниц
                  _buildPagesSelector(context, selectedPages),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Выбор переплёта
                  _buildBindingSelector(context, selectedBinding, selectedSize.value, selectedPages.value),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Выбор упаковки
                  _buildPackagingSelector(context, selectedPackaging),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Данные для доставки
                  _buildDeliveryForm(
                    context,
                    nameController,
                    phoneController,
                    cityController,
                    streetController,
                    houseController,
                    apartmentController,
                    postalCodeController,
                    commentController,
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Итоговая стоимость
                  _buildPriceSummary(
                    context,
                    selectedSize.value,
                    selectedPages.value,
                    selectedBinding.value,
                    selectedPackaging.value,
                    calculateTotal(),
                  ),
                  
                  if (orderError.value != null) ...[
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
                              orderError.value!,
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
                    onPressed: isProcessing.value
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            
                            isProcessing.value = true;
                            orderError.value = null;
                            
                            try {
                              final api = ref.read(backendApiProvider);
                              
                              // ШАГ 1: Сначала создаём платёж для заказа на печать
                              final totalPrice = calculateTotal();
                              
                              // Формируем адрес из отдельных полей
                              final addressParts = <String>[];
                              if (cityController.text.trim().isNotEmpty) {
                                addressParts.add(cityController.text.trim());
                              }
                              if (streetController.text.trim().isNotEmpty) {
                                addressParts.add(streetController.text.trim());
                              }
                              if (houseController.text.trim().isNotEmpty) {
                                addressParts.add(houseController.text.trim());
                              }
                              if (apartmentController.text.trim().isNotEmpty) {
                                addressParts.add('кв. ${apartmentController.text.trim()}');
                              }
                              if (postalCodeController.text.trim().isNotEmpty) {
                                addressParts.add(postalCodeController.text.trim());
                              }
                              final fullAddress = addressParts.join(', ');
                              
                              // Извлекаем только цифры из телефона
                              final phoneDigits = PhoneInputFormatter.extractDigits(phoneController.text);
                              
                              final orderData = {
                                'book_title': book.title,
                                'size': selectedSize.value.name,
                                'pages': selectedPages.value.count,
                                'binding': selectedBinding.value.name,
                                'packaging': selectedPackaging.value.name,
                                'total_price': totalPrice, // Добавляем total_price в order_data
                                'customer_name': nameController.text.trim(),
                                'customer_phone': phoneDigits.isNotEmpty ? phoneDigits : phoneController.text.trim(),
                                'customer_address': fullAddress,
                                'comment': commentController.text.trim(),
                              };
                              final paymentUrl = await api.createPaymentForPrintOrder(
                                bookId: bookId,
                                amount: totalPrice,
                                orderData: orderData,
                              );
                              
                              // ШАГ 2: Если есть URL для оплаты, открываем его
                              if (paymentUrl != null && paymentUrl.isNotEmpty) {
                                final uri = Uri.parse(paymentUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  // После оплаты бэкенд должен отправить уведомления
                                  // и создать заказ автоматически через webhook
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Переход к оплате... После оплаты заказ будет оформлен автоматически.'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                    context.pop();
                                    return;
                                  }
                                }
                              }
                              
                              // ШАГ 3: Если оплата в демо-режиме или уже подтверждена, создаём заказ
                              // В демо-режиме подтверждаем оплату и создаём заказ
                              // Передаем orderData для подтверждения оплаты
                              await api.confirmPaymentForPrintOrder(
                                bookId: bookId,
                                orderData: orderData,
                              );
                              
                              // Создаём заказ (после оплаты)
                              // Используем уже сформированные fullAddress и phoneDigits
                              await api.createPrintOrder(
                                bookId: bookId,
                                bookTitle: book.title,
                                size: selectedSize.value.name,
                                pages: selectedPages.value.count,
                                binding: selectedBinding.value.name,
                                packaging: selectedPackaging.value.name,
                                totalPrice: totalPrice,
                                customerName: nameController.text.trim(),
                                customerPhone: phoneDigits.isNotEmpty ? phoneDigits : phoneController.text.trim(),
                                customerAddress: fullAddress,
                                comment: commentController.text.trim(),
                              );
                              
                              if (context.mounted) {
                                // Показываем успешное сообщение
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => AlertDialog(
                                    title: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 28),
                                        const SizedBox(width: 8),
                                        const Text('Заказ оформлен!'),
                                      ],
                                    ),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Спасибо за заказ!',
                                            style: AppTypography.headlineSmall,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Мы свяжемся с вами в ближайшее время для подтверждения заказа и уточнения деталей доставки.',
                                            style: AppTypography.bodyMedium,
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('📏 ${selectedSize.value.name}'),
                                                Text('📄 ${selectedPages.value.count} страниц'),
                                                Text('📚 ${selectedBinding.value.name}'),
                                                Text('🎁 ${selectedPackaging.value.name}'),
                                                const Divider(),
                                                Text(
                                                  'Итого: ${calculateTotal()} ₽',
                                                  style: safeCopyWith(
                                                    AppTypography.headlineSmall,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          context.go(RouteNames.books);
                                        },
                                        child: const Text('К моим книгам'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              orderError.value = 'Ошибка оформления заказа: ${e.toString().replaceAll('Exception: ', '')}';
                            } finally {
                              isProcessing.value = false;
                            }
                          },
                    isLoading: isProcessing.value,
                    fullWidth: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Оформить заказ за ${calculateTotal()} ₽',
                          style: safeCopyWith(
                            AppTypography.labelLarge,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Подсказка
                  Container(
                    padding: AppSpacing.paddingSM,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'После оформления мы свяжемся с вами для подтверждения',
                            style: safeCopyWith(
                              AppTypography.bodySmall,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                    ),
                  ),
                ),
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

  Widget _buildHeader(BuildContext context, String title, String? coverUrl) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Row(
        children: [
          // Обложка книги
          Container(
            width: 100,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? RoundedImage(
                      imageUrl: coverUrl,
                      width: 100,
                      height: 140,
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
                      child: const Icon(Icons.book, color: Colors.white, size: 48),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Печатная книга',
                      style: safeCopyWith(
                        AppTypography.labelLarge,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: safeCopyWith(
                    AppTypography.headlineSmall,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSelector(BuildContext context, ValueNotifier<BookSize> selected) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Формат книги',
                style: safeCopyWith(
                  AppTypography.headlineSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...BookSize.values.map((size) => _buildOptionTileSimple(
            title: size.name,
            subtitle: size.description,
            isSelected: selected.value == size,
            onTap: () => selected.value = size,
            icon: size == BookSize.a5
                ? Icons.photo_size_select_small
                : size == BookSize.b5
                    ? Icons.photo_size_select_large
                    : Icons.photo_size_select_actual,
          )),
        ],
      ),
    );
  }

  Widget _buildPagesSelector(BuildContext context, ValueNotifier<PageCount> selected) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Количество страниц',
                style: safeCopyWith(
                  AppTypography.headlineSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: PageCount.values.map((pages) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: pages == PageCount.pages10 ? 8 : 0,
                  left: pages == PageCount.pages20 ? 8 : 0,
                ),
                child: InkWell(
                  onTap: () => selected.value = pages,
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected.value == pages
                          ? AppColors.primary.withOpacity(0.15)
                          : AppColors.surface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected.value == pages
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${pages.count}',
                          style: safeCopyWith(
                            AppTypography.headlineMedium,
                            fontWeight: FontWeight.bold,
                            color: selected.value == pages
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'страниц',
                          style: safeCopyWith(
                            AppTypography.bodySmall,
                            color: selected.value == pages
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBindingSelector(
    BuildContext context,
    ValueNotifier<BindingType> selected,
    BookSize size,
    PageCount pages,
  ) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Тип переплёта',
                style: safeCopyWith(
                  AppTypography.headlineSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...BindingType.values.map((binding) {
            final price = getBasePrice(size, pages, binding);
            return _buildOptionTile(
              title: binding.name,
              subtitle: binding.description,
              price: '$price ₽',
              isSelected: selected.value == binding,
              onTap: () => selected.value = binding,
              icon: binding == BindingType.soft ? Icons.library_books : Icons.book,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPackagingSelector(BuildContext context, ValueNotifier<PackagingType> selected) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Упаковка',
                style: safeCopyWith(
                  AppTypography.headlineSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...PackagingType.values.map((packaging) => _buildOptionTile(
            title: packaging.name,
            subtitle: packaging.description,
            price: packaging.additionalPrice > 0 ? '+${packaging.additionalPrice} ₽' : 'Бесплатно',
            isSelected: selected.value == packaging,
            onTap: () => selected.value = packaging,
            icon: packaging == PackagingType.simple ? Icons.inventory_2 : Icons.card_giftcard,
          )),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required String price,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.15)
                : AppColors.surface.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.2)
                      : AppColors.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: safeCopyWith(
                        AppTypography.bodyLarge,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: safeCopyWith(
                        AppTypography.bodySmall,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.2)
                      : AppColors.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  price,
                  style: safeCopyWith(
                    AppTypography.labelMedium,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryForm(
    BuildContext context,
    TextEditingController nameController,
    TextEditingController phoneController,
    TextEditingController cityController,
    TextEditingController streetController,
    TextEditingController houseController,
    TextEditingController apartmentController,
    TextEditingController postalCodeController,
    TextEditingController commentController,
  ) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Данные для доставки',
                style: safeCopyWith(
                  AppTypography.headlineSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Имя
          TextFormField(
            controller: nameController,
            decoration: _inputDecoration('Ваше имя', Icons.person_outline),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите ваше имя';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Телефон с форматированием
          PhoneInputField(
            controller: phoneController,
            label: 'Телефон',
            hint: '+7 (XXX) XXX-XX-XX',
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Адрес с отдельными полями
          AddressInputFields(
            cityController: cityController,
            streetController: streetController,
            houseController: houseController,
            apartmentController: apartmentController,
            postalCodeController: postalCodeController,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Комментарий
          TextFormField(
            controller: commentController,
            maxLines: 2,
            decoration: _inputDecoration('Комментарий к заказу (необязательно)', Icons.comment_outlined),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.surface.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error),
      ),
    );
  }

  Widget _buildPriceSummary(
    BuildContext context,
    BookSize size,
    PageCount pages,
    BindingType binding,
    PackagingType packaging,
    int total,
  ) {
    final basePrice = getBasePrice(size, pages, binding);
    
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Итого',
                style: safeCopyWith(
                  AppTypography.headlineSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          _buildPriceRow('Формат: ${size.name}', ''),
          _buildPriceRow('Страниц: ${pages.count}', ''),
          _buildPriceRow('Переплёт: ${binding.name}', '$basePrice ₽'),
          if (packaging.additionalPrice > 0)
            _buildPriceRow('Упаковка: ${packaging.name}', '+${packaging.additionalPrice} ₽'),
          
          const Divider(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'К оплате:',
                style: safeCopyWith(
                  AppTypography.headlineMedium,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$total ₽',
                style: safeCopyWith(
                  AppTypography.headlineMedium,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTileSimple({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.15)
                : AppColors.surface.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.2)
                      : AppColors.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: safeCopyWith(
                        AppTypography.bodyLarge,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: safeCopyWith(
                        AppTypography.bodySmall,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: safeCopyWith(
              AppTypography.bodyMedium,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            price,
            style: safeCopyWith(
              AppTypography.bodyMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

