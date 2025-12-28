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
import '../../../core/widgets/rounded_image.dart';
import '../../../core/services/screenshot_protection_service.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../core/models/scene_variant.dart';
import '../data/book_providers.dart';
import '../data/scene_variants_provider.dart';

class EditImageWithVariantsScreen extends HookConsumerWidget {
  final String bookId;
  final int sceneIndex;

  const EditImageWithVariantsScreen({
    super.key,
    required this.bookId,
    required this.sceneIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sceneAsync = ref.watch(sceneProvider((bookId: bookId, sceneIndex: sceneIndex)));
    final variantsNotifier = ref.read(sceneVariantsProvider.notifier);
    final variants = ref.watch(sceneVariantsProvider);
    
    final instructionController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final selectedVariantIndex = useState<int?>(null);
    
    // Инициализируем варианты отложенно, если их еще нет
    useEffect(() {
      sceneAsync.whenData((scene) {
        // Отложенная инициализация после построения виджета
        Future.microtask(() {
          if (!variants.containsKey(scene.id)) {
            variantsNotifier.getVariants(
              scene.id,
              originalImageUrl: scene.finalUrl ?? scene.draftUrl,
            );
          }
        });
      });
      return null;
    }, [sceneAsync]);

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_generate_book.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Редактировать изображение',
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
            // Получаем варианты (уже инициализированы через useEffect)
            final sceneVariants = variants[scene.id] ?? SceneVariants(
              sceneId: scene.id,
              textVariants: [],
              imageVariants: scene.finalUrl != null || scene.draftUrl != null
                  ? [
                      ImageVariant(
                        id: '${scene.id}_image_0',
                        imageUrl: scene.finalUrl ?? scene.draftUrl ?? '',
                        variantNumber: 0,
                        isSelected: true,
                      ),
                    ]
                  : [],
              selectedImageVariantId: scene.finalUrl != null || scene.draftUrl != null
                  ? '${scene.id}_image_0'
                  : null,
            );
            final remainingEdits = variantsNotifier.remainingImageEdits(scene.id);
            final canEdit = variantsNotifier.canEditImage(scene.id);

            Future<void> handleGenerateVariant() async {
              if (!canEdit) {
                errorMessage.value = 'Достигнут лимит редактирования (${EditLimits.maxImageEdits} варианта)';
                return;
              }

              final instruction = instructionController.text.trim();
              
              if (instruction.isEmpty) {
                errorMessage.value = 'Опишите, что нужно изменить на изображении';
                return;
              }

              isLoading.value = true;
              errorMessage.value = null;

              try {
                final api = ref.read(backendApiProvider);
                final updatedScene = await api.regenerateScene(
                  bookId: bookId,
                  sceneOrder: sceneIndex, // Индексация начинается с 0 (обложка)
                  instruction: instruction,
                );

                if (updatedScene.finalUrl != null || updatedScene.draftUrl != null) {
                  variantsNotifier.addImageVariant(
                    scene.id,
                    updatedScene.finalUrl ?? updatedScene.draftUrl!,
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
                  
                  // Галерея вариантов
                  Text(
                    'Варианты изображения',
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
                  
                  // Сетка вариантов изображений
                  _buildImageVariantsGrid(
                    context,
                    sceneVariants.imageVariants,
                    variantsNotifier,
                    scene.id,
                  ),
                  
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
                                assetPath: AppIcons.generateStory,
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
                          
                          // Примеры инструкций
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildSuggestionChip('Сделай ярче', instructionController),
                              _buildSuggestionChip('Добавь улыбку', instructionController),
                              _buildSuggestionChip('Измени фон', instructionController),
                              _buildSuggestionChip('Добавь волшебства', instructionController),
                            ],
                          ),
                          
                          const SizedBox(height: AppSpacing.md),
                          
                          // Инструкция
                          AppTextField(
                            controller: instructionController,
                            label: 'Что изменить на изображении',
                            hint: 'Например: измени цвет платья на красный...',
                            prefixIcon: Icons.brush_outlined,
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
                    
                    // Кнопка генерации
                    AppMagicButton(
                      onPressed: isLoading.value ? null : handleGenerateVariant,
                      isLoading: isLoading.value,
                      fullWidth: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AssetIcon(
                            assetPath: AppIcons.generateStory,
                            size: 24,
                            color: AppColors.onPrimary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Сгенерировать новый вариант',
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
                      final selectedUrl = variantsNotifier.getSelectedImageUrl(scene.id);
                      context.pop(selectedUrl);
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
            canEdit ? Icons.image_outlined : Icons.block,
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
                      : 'Выберите один из ${EditLimits.maxImageEdits} вариантов',
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

  Widget _buildImageVariantsGrid(
    BuildContext context,
    List<ImageVariant> variants,
    SceneVariantsNotifier notifier,
    String sceneId,
  ) {
    if (variants.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 48,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Нет вариантов',
                style: safeCopyWith(
                  AppTypography.bodyMedium,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: variants.length,
      itemBuilder: (context, index) {
        final variant = variants[index];
        final isSelected = variant.isSelected;
        final isOriginal = index == 0;

        return GestureDetector(
          onTap: () => notifier.selectImageVariant(sceneId, variant.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: isSelected ? 3 : 0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isSelected ? 13 : 16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Изображение с водяным знаком
                  WatermarkOverlay(
                    showWatermark: true,
                    opacity: 0.1,
                    child: RoundedImage(
                      imageUrl: variant.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      radius: 0,
                    ),
                  ),
                  
                  // Метка
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOriginal
                            ? Colors.blue.withOpacity(0.9)
                            : AppColors.primary.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOriginal ? 'Оригинал' : '#${index}',
                        style: safeCopyWith(
                          AppTypography.labelSmall,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Галочка выбора
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  
                  // Инструкция внизу
                  if (variant.instruction != null && !isOriginal)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: Text(
                          variant.instruction!,
                          style: safeCopyWith(
                            AppTypography.bodySmall,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionChip(String text, TextEditingController controller) {
    return GestureDetector(
      onTap: () {
        controller.text = text;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Text(
          text,
          style: safeCopyWith(
            AppTypography.bodySmall,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

