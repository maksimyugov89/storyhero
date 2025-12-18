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
import '../../../core/models/scene_variant.dart';
import '../data/book_providers.dart';
import '../data/scene_variants_provider.dart';

class EditTextWithVariantsScreen extends HookConsumerWidget {
  final String bookId;
  final int sceneIndex;

  const EditTextWithVariantsScreen({
    super.key,
    required this.bookId,
    required this.sceneIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sceneAsync = ref.watch(sceneProvider((bookId: bookId, sceneIndex: sceneIndex)));
    final variantsNotifier = ref.watch(sceneVariantsProvider.notifier);
    final variants = ref.watch(sceneVariantsProvider);
    
    final instructionController = useTextEditingController();
    final selectedTextController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final showCustomInput = useState(false);

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
            // Инициализируем варианты если их нет
            final sceneVariants = variantsNotifier.getVariants(
              scene.id,
              originalText: scene.shortSummary,
            );
            final remainingEdits = variantsNotifier.remainingTextEdits(scene.id);
            final canEdit = variantsNotifier.canEditText(scene.id);

            Future<void> handleGenerateVariant() async {
              if (!canEdit) {
                errorMessage.value = 'Достигнут лимит редактирования (${EditLimits.maxTextEdits} вариантов)';
                return;
              }

              final instruction = instructionController.text.trim();
              final customText = selectedTextController.text.trim();
              
              if (instruction.isEmpty && customText.isEmpty) {
                errorMessage.value = 'Введите инструкцию или свой текст';
                return;
              }

              isLoading.value = true;
              errorMessage.value = null;

              try {
                if (customText.isNotEmpty) {
                  // Если пользователь ввел свой текст напрямую
                  variantsNotifier.addTextVariant(
                    scene.id,
                    customText,
                    'Пользовательский текст',
                  );
                  selectedTextController.clear();
                  showCustomInput.value = false;
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Вариант добавлен'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } else {
                  // Генерируем через API
                  final api = ref.read(backendApiProvider);
                  final updatedScene = await api.updateText(
                    bookId: bookId,
                    sceneIndex: sceneIndex + 1,
                    instruction: instruction,
                  );

                  variantsNotifier.addTextVariant(
                    scene.id,
                    updatedScene.shortSummary,
                    instruction,
                  );
                  instructionController.clear();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Новый вариант создан. Осталось: ${remainingEdits - 1}'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              } catch (e) {
                errorMessage.value = 'Ошибка: ${e.toString().replaceAll('Exception: ', '')}';
              } finally {
                isLoading.value = false;
              }
            }

            return SingleChildScrollView(
              padding: AppSpacing.paddingMD,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Счетчик попыток
                  _buildAttemptsCounter(remainingEdits, canEdit),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Варианты текста
                  Text(
                    'Варианты текста',
                    style: safeCopyWith(
                      AppTypography.headlineMedium,
                      color: AppColors.onBackground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Выберите понравившийся вариант',
                    style: safeCopyWith(
                      AppTypography.bodyMedium,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Список вариантов
                  ...sceneVariants.textVariants.asMap().entries.map((entry) {
                    final index = entry.key;
                    final variant = entry.value;
                    return _buildVariantCard(
                      context,
                      variant,
                      index,
                      () => variantsNotifier.selectTextVariant(scene.id, variant.id),
                    );
                  }),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Секция создания нового варианта
                  if (canEdit) ...[
                    AppMagicCard(
                      padding: AppSpacing.paddingMD,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AssetIcon(
                                assetPath: AppIcons.edit,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Создать новый вариант',
                                style: safeCopyWith(
                                  AppTypography.headlineSmall,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: AppSpacing.md),
                          
                          // Переключатель режима
                          Row(
                            children: [
                              Expanded(
                                child: _buildModeButton(
                                  'AI генерация',
                                  Icons.auto_awesome,
                                  !showCustomInput.value,
                                  () => showCustomInput.value = false,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _buildModeButton(
                                  'Свой текст',
                                  Icons.edit_note,
                                  showCustomInput.value,
                                  () => showCustomInput.value = true,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: AppSpacing.md),
                          
                          if (showCustomInput.value)
                            // Ввод своего текста
                            AppTextField(
                              controller: selectedTextController,
                              label: 'Ваш текст',
                              hint: 'Введите свой вариант текста...',
                              prefixIcon: Icons.text_fields,
                              maxLines: 5,
                              enabled: !isLoading.value,
                            )
                          else
                            // Инструкция для AI
                            AppTextField(
                              controller: instructionController,
                              label: 'Инструкция для изменения',
                              hint: 'Например: сделай текст более весёлым...',
                              prefixIcon: Icons.auto_awesome,
                              maxLines: 3,
                              enabled: !isLoading.value,
                            ),
                        ],
                      ),
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
                    
                    const SizedBox(height: AppSpacing.md),
                    
                    // Кнопка создания
                    AppMagicButton(
                      onPressed: isLoading.value ? null : handleGenerateVariant,
                      isLoading: isLoading.value,
                      fullWidth: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            showCustomInput.value ? Icons.add : Icons.auto_awesome,
                            color: AppColors.onPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            showCustomInput.value ? 'Добавить вариант' : 'Сгенерировать',
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
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Кнопка подтверждения выбора
                  AppMagicButton(
                    onPressed: () {
                      // Возвращаем выбранный текст
                      final selectedText = variantsNotifier.getSelectedText(scene.id);
                      context.pop(selectedText);
                    },
                    fullWidth: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AssetIcon(
                          assetPath: AppIcons.success,
                          size: 24,
                          color: AppColors.onPrimary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Подтвердить выбор',
                          style: safeCopyWith(
                            AppTypography.labelLarge,
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
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

  Widget _buildAttemptsCounter(int remaining, bool canEdit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canEdit
              ? [AppColors.primary.withOpacity(0.2), AppColors.secondary.withOpacity(0.2)]
              : [Colors.orange.withOpacity(0.2), Colors.red.withOpacity(0.2)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canEdit ? AppColors.primary.withOpacity(0.3) : Colors.orange.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            canEdit ? Icons.edit_note : Icons.block,
            color: canEdit ? AppColors.primary : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canEdit ? 'Осталось попыток: $remaining' : 'Лимит исчерпан',
                  style: safeCopyWith(
                    AppTypography.labelLarge,
                    fontWeight: FontWeight.bold,
                    color: canEdit ? AppColors.onSurface : Colors.orange,
                  ),
                ),
                Text(
                  canEdit
                      ? 'Выберите лучший вариант из созданных'
                      : 'Выберите один из ${EditLimits.maxTextEdits} вариантов',
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
    );
  }

  Widget _buildVariantCard(
    BuildContext context,
    TextVariant variant,
    int index,
    VoidCallback onSelect,
  ) {
    final isSelected = variant.isSelected;
    final isOriginal = index == 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: AppSpacing.paddingMD,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.secondary.withOpacity(0.15),
                    ],
                  )
                : null,
            color: isSelected ? null : AppColors.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOriginal
                          ? Colors.blue.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOriginal ? 'Оригинал' : 'Вариант ${index}',
                      style: safeCopyWith(
                        AppTypography.labelSmall,
                        color: isOriginal ? Colors.blue : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                variant.text,
                style: AppTypography.bodyMedium,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
              if (variant.instruction != null && !isOriginal) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '💡 ${variant.instruction}',
                  style: safeCopyWith(
                    AppTypography.bodySmall,
                    color: AppColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.surfaceVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: safeCopyWith(
                AppTypography.labelMedium,
                color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

