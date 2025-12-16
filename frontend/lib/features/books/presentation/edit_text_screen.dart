import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes/route_names.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/presentation/widgets/inputs/app_text_field.dart';
import '../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../ui/components/asset_icon.dart';
import '../data/book_providers.dart';

class EditTextScreen extends HookConsumerWidget {
  final String bookId;
  final int sceneIndex;

  const EditTextScreen({
    super.key,
    required this.bookId,
    required this.sceneIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sceneAsync = ref.watch(sceneProvider((bookId: bookId, sceneIndex: sceneIndex)));
    final instructionController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);

    Future<void> handleUpdateText() async {
      if (instructionController.text.trim().isEmpty) {
        errorMessage.value = 'Введите инструкцию для изменения текста';
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      try {
        final api = ref.read(backendApiProvider);
        await api.updateText(
          bookId: bookId,
          sceneIndex: sceneIndex + 1,
          instruction: instructionController.text.trim(),
        );

        if (context.mounted) {
          ref.invalidate(sceneProvider((bookId: bookId, sceneIndex: sceneIndex)));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Текст успешно обновлён'),
              backgroundColor: AppColors.success,
            ),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              context.pop(true);
            }
          });
        }
      } catch (e) {
        errorMessage.value = 'Ошибка обновления текста: ${e.toString()}';
      } finally {
        isLoading.value = false;
      }
    }

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_generate_book.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Редактировать текст',
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
        body: sceneAsync.when(
          data: (scene) {
            return SingleChildScrollView(
              padding: AppSpacing.paddingMD,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Текущий текст
                  AppMagicCard(
                    padding: AppSpacing.paddingMD,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Текущий текст:',
                          style: safeCopyWith(
                            AppTypography.labelLarge,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          scene.shortSummary,
                          style: AppTypography.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Инструкция
                  AppTextField(
                    controller: instructionController,
                    label: 'Инструкция для изменения',
                    hint: 'Опишите, как изменить текст...',
                    prefixIcon: Icons.edit_outlined,
                    maxLines: 5,
                    enabled: !isLoading.value,
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Ошибка
                  if (errorMessage.value != null)
                    Container(
                      padding: AppSpacing.paddingMD,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(
                        children: [
                          AssetIcon(
                            assetPath: AppIcons.alert,
                            size: 20,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              errorMessage.value!,
                              style: safeCopyWith(
                                AppTypography.bodyMedium,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Кнопка обновления
                  AppMagicButton(
                    onPressed: isLoading.value ? null : handleUpdateText,
                    isLoading: isLoading.value,
                    fullWidth: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AssetIcon(
                          assetPath: AppIcons.edit,
                          size: 24,
                          color: AppColors.onPrimary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Обновить текст',
                          style: safeCopyWith(
                            AppTypography.labelLarge,
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
          loading: () => const LoadingWidget(),
          error: (error, stack) => ErrorDisplayWidget(
            error: error,
            onRetry: () => ref.invalidate(sceneProvider((bookId: bookId, sceneIndex: sceneIndex))),
          ),
        ),
      ),
    );
  }
}
