import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/route_names.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api/backend_api.dart';
import '../../../../core/models/child.dart';
import '../../../../core/presentation/layouts/app_page.dart';
import '../../../../core/presentation/design_system/app_colors.dart';
import '../../../../core/presentation/design_system/app_typography.dart';
import '../../../../core/presentation/design_system/app_spacing.dart';
import '../../../../core/utils/text_style_helpers.dart';
import '../../../../core/presentation/widgets/inputs/app_text_field.dart';
import '../../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../../core/presentation/widgets/buttons/app_button.dart';
import '../../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../../ui/components/photo_preview_grid.dart';
import '../../../../ui/components/asset_icon.dart';
import '../presentation/children_list_screen.dart';
import '../state/child_photos_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;

class ChildCreateScreen extends HookConsumerWidget {
  const ChildCreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final ageController = useTextEditingController();
    final selectedGender = useState<ChildGender?>(null);
    final interestsController = useTextEditingController();
    final fearsController = useTextEditingController();
    final characterController = useTextEditingController();
    final moralController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final selectedPhotos = useState<List<io.File>>([]);
    final fadeAnimation = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );

    useEffect(() {
      fadeAnimation.forward();
      return null;
    }, []);

    Future<void> handleCreate() async {
      if (nameController.text.isEmpty || ageController.text.isEmpty || selectedGender.value == null) {
        errorMessage.value = 'Заполните обязательные поля';
        return;
      }

      final age = int.tryParse(ageController.text);
      if (age == null || age < 1 || age > 18) {
        errorMessage.value = 'Введите корректный возраст (1-18)';
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      try {
        final api = ref.read(backendApiProvider);
        
        final createdChild = await api.createChild(
          name: nameController.text.trim(),
          age: age,
          gender: selectedGender.value!,
          interests: interestsController.text.trim(),
          fears: fearsController.text.trim(),
          character: characterController.text.trim(),
          moral: moralController.text.trim(),
          photos: selectedPhotos.value.isNotEmpty ? selectedPhotos.value : null,
        );

        if (createdChild.faceUrl != null && createdChild.faceUrl!.isNotEmpty) {
          final photosNotifier = ref.read(childPhotosProvider(createdChild.id).notifier);
          photosNotifier.addPhoto(createdChild.faceUrl!);
        }

        if (context.mounted) {
          ref.invalidate(childrenProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ребёнок добавлен'),
              backgroundColor: AppColors.success,
            ),
          );
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RouteNames.home);
          }
        }
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr.contains('Ошибка загрузки фотографии') || 
            errorStr.contains('uploadPhoto')) {
          errorMessage.value = 'Ошибка загрузки фотографии. Попробуйте другую.';
        } else {
          errorMessage.value = 'Ошибка создания: ${e.toString()}';
        }
      } finally {
        isLoading.value = false;
      }
    }

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_create_child.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Добавить ребёнка',
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
        body: FadeTransition(
          opacity: fadeAnimation,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingMD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                
                // Фото
                AppMagicCard(
                  padding: AppSpacing.paddingLG,
                  child: Column(
                    children: [
                      if (selectedPhotos.value.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            selectedPhotos.value.first,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.add_photo_alternate,
                            size: 48,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        text: 'Добавить фото',
                        icon: Icons.add_photo_alternate,
                        onPressed: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null && image.path.isNotEmpty) {
                            selectedPhotos.value = [io.File(image.path)];
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'Для лучшего сходства лица ребенка в будущей книге нужно четкое отображение лица ребенка на фото',
                          style: safeCopyWith(
                            AppTypography.bodySmall,
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Поля ввода
                AppTextField(
                  controller: nameController,
                  label: 'Имя *',
                  hint: 'Введите имя',
                  prefixIcon: Icons.person_outline,
                  enabled: !isLoading.value,
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                AppTextField(
                  controller: ageController,
                  label: 'Возраст *',
                  hint: 'Введите возраст (1-18)',
                  prefixIcon: Icons.cake,
                  keyboardType: TextInputType.number,
                  enabled: !isLoading.value,
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // Выбор пола
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Пол *',
                        style: safeCopyWith(
                          AppTypography.labelMedium,
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _GenderSelector(
                            gender: ChildGender.male,
                            selected: selectedGender.value,
                            onSelected: (gender) => selectedGender.value = gender,
                            enabled: !isLoading.value,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _GenderSelector(
                            gender: ChildGender.female,
                            selected: selectedGender.value,
                            onSelected: (gender) => selectedGender.value = gender,
                            enabled: !isLoading.value,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                AppTextField(
                  controller: interestsController,
                  label: 'Интересы',
                  hint: 'Например: рисование, танцы',
                  prefixIcon: Icons.star_outline,
                  maxLines: 2,
                  enabled: !isLoading.value,
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                AppTextField(
                  controller: fearsController,
                  label: 'Страхи',
                  hint: 'Например: темнота',
                  prefixIcon: Icons.warning_amber_outlined,
                  maxLines: 2,
                  enabled: !isLoading.value,
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                AppTextField(
                  controller: characterController,
                  label: 'Характер',
                  hint: 'Например: активная, позитивная',
                  prefixIcon: Icons.psychology_outlined,
                  maxLines: 3,
                  enabled: !isLoading.value,
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                AppTextField(
                  controller: moralController,
                  label: 'Мораль истории',
                  hint: 'Например: хорошо учиться',
                  prefixIconAsset: AppIcons.book,
                  maxLines: 3,
                  enabled: !isLoading.value,
                ),
                
                // Ошибка
                if (errorMessage.value != null) ...[
                  const SizedBox(height: AppSpacing.md),
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
                ],
                
                const SizedBox(height: AppSpacing.xl),
                
                // Кнопка создания
                AppMagicButton(
                  onPressed: isLoading.value ? null : handleCreate,
                  isLoading: isLoading.value,
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
                        'Создать',
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
          ),
        ),
      ),
    );
  }
}

/// Виджет для выбора пола ребенка
class _GenderSelector extends StatelessWidget {
  final ChildGender gender;
  final ChildGender? selected;
  final Function(ChildGender) onSelected;
  final bool enabled;

  const _GenderSelector({
    required this.gender,
    required this.selected,
    required this.onSelected,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == gender;
    
    return GestureDetector(
      onTap: enabled ? () => onSelected(gender) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.surfaceVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              gender == ChildGender.male ? Icons.boy : Icons.girl,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              gender.displayName,
              style: safeCopyWith(
                AppTypography.labelLarge,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
