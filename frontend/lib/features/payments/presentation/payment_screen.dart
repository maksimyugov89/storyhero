import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes/route_names.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/magic/glassmorphic_card.dart';
import '../../../ui/components/glowing_capsule_button.dart';
import '../../books/data/book_providers.dart';
import '../../../core/utils/text_style_helpers.dart';

class PaymentScreen extends ConsumerWidget {
  final String bookId;

  const PaymentScreen({
    super.key,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider(bookId));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/logo/storyhero_bg_generate_book.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Container(
              color: Colors.black.withOpacity(0.15),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text('Оплата'),
              ),
              body: bookAsync.when(
                data: (book) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),
                          // Обложка книги
                          GlassmorphicCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Container(
                                  width: 200,
                                  height: 300,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.secondary,
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.auto_stories,
                                    size: 100,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  book.title,
                                  style: safeCopyWith(
                                    Theme.of(context).textTheme.headlineSmall,
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Информация о стоимости
                          GlassmorphicCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Стоимость',
                                  style: safeCopyWith(
                                    Theme.of(context).textTheme.titleLarge,
                                    fontSize: 22.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Персонализированная книга',
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    Text(
                                      '499 ₽',
                                      style: safeCopyWith(
                                        Theme.of(context).textTheme.headlineSmall,
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Итого',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      '499 ₽',
                                      style: safeCopyWith(
                                        Theme.of(context).textTheme.headlineMedium,
                                        fontSize: 24.0,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Кнопка оплаты
                          GlowingCapsuleButton(
                            text: 'Купить книгу',
                            icon: Icons.payment,
                            onPressed: () async {
                              // TODO: Интеграция с платежной системой
                              // Пока что просто переходим к финальной книге
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Оплата пока не реализована. Переход к книге...'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                Future.delayed(const Duration(milliseconds: 1500), () {
                                  if (context.mounted) {
                                    context.go(RouteNames.bookView.replaceAll(':id', bookId));
                                  }
                                });
                              }
                            },
                            width: double.infinity,
                            height: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'После оплаты вы получите доступ к финальной версии книги в высоком качестве',
                            style: safeCopyWith(
                              Theme.of(context).textTheme.bodySmall,
                              fontSize: 12.0,
                              color: safeCopyWith(
                                Theme.of(context).textTheme.bodyMedium,
                                fontSize: 14.0,
                              ).color?.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const LoadingWidget(),
                error: (error, stack) => ErrorDisplayWidget(
                  error: error,
                  onRetry: () => ref.refresh(bookProvider(bookId)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

