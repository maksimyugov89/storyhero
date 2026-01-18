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
import '../../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../../core/widgets/rounded_image.dart';
import '../../../../ui/components/photo_preview_grid.dart';
import '../../../../ui/components/asset_icon.dart';
import '../presentation/children_list_screen.dart';
import '../presentation/child_profile_screen.dart'; // Для childProvider
import '../data/child_photos_provider.dart';
import '../../../core/models/child_photo.dart';
import '../../../../ui/layouts/desktop_container.dart';

class ChildEditScreen extends HookConsumerWidget {
  final Child child;

  const ChildEditScreen({
    super.key,
    required this.child,
  });
  

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController(text: child.name);
    final ageController = useTextEditingController(text: child.age.toString());
    final selectedGender = useState<ChildGender>(child.gender);
    final interestsController = useTextEditingController(text: child.interests ?? '');
    final fearsController = useTextEditingController(text: child.fears ?? '');
    final characterController = useTextEditingController(text: child.character ?? '');
    final moralController = useTextEditingController(text: child.moral ?? '');
    final isLoading = useState(false);
    final isDeleting = useState(false);
    final errorMessage = useState<String?>(null);
    final selectedPhotos = useState<List<XFile>>([]);
    final photosAsync = ref.watch(childPhotosProvider(child.id));
    final fadeAnimation = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );

    useEffect(() {
      fadeAnimation.forward();
      return null;
    }, []);
    
    // Получаем список URL фотографий из API
    final existingPhotoUrls = photosAsync.when(
      data: (response) => response.photos.map((p) => p.url).toList(),
      loading: () => <String>[],
      error: (_, __) => <String>[],
    );
    
    // Текущая аватарка
    final currentAvatarUrl = child.faceUrl;
    
    // Функция удаления фото
    Future<void> handleDeletePhoto(String photoUrl) async {
      isDeleting.value = true;
      try {
        final api = ref.read(backendApiProvider);
        await api.deleteChildPhoto(
          childId: child.id,
          photoUrl: photoUrl,
        );
        
        // Обновляем провайдер
        ref.invalidate(childPhotosProvider(child.id));
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Фото удалено'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final errorStr = e.toString();
          String message;
          if (errorStr.contains('405') || errorStr.contains('Method Not Allowed')) {
            message = 'Удаление фото временно недоступно. Функция в разработке.';
          } else {
            message = 'Ошибка удаления: ${errorStr.replaceAll('Exception: ', '')}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        isDeleting.value = false;
      }
    }
    
    // Диалог подтверждения удаления
    Future<void> showDeleteConfirmation(String photoUrl) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Удалить фото?',
            style: safeCopyWith(
              AppTypography.headlineSmall,
              color: AppColors.onSurface,
            ),
          ),
          content: Text(
            'Фотография будет удалена безвозвратно.',
            style: safeCopyWith(
              AppTypography.bodyMedium,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Отмена',
                style: safeCopyWith(
                  AppTypography.labelLarge,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Удалить',
                style: safeCopyWith(
                  AppTypography.labelLarge,
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        await handleDeletePhoto(photoUrl);
      }
    }

    Future<void> handleUpdate() async {
      if (nameController.text.trim().isEmpty) {
        errorMessage.value = 'Имя не может быть пустым';
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
        
        final updatedChild = await api.updateChild(
          id: child.id.toString(),
          name: nameController.text.trim(),
          age: age,
          gender: selectedGender.value,
          interests: interestsController.text.trim(),
          fears: fearsController.text.trim(),
          character: characterController.text.trim(),
          moral: moralController.text.trim(),
          faceUrl: existingPhotoUrls.isNotEmpty ? existingPhotoUrls.first : null,
          photos: selectedPhotos.value.isNotEmpty ? selectedPhotos.value : null,
          existingPhotoUrls: existingPhotoUrls.isNotEmpty ? existingPhotoUrls : null,
        );

        // Обновляем провайдеры для обновления UI
        ref.invalidate(childPhotosProvider(child.id));
        ref.invalidate(childProvider(child.id));
        ref.invalidate(childrenProvider); // Обновляем список "Дети" чтобы аватарка обновилась сразу

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Изменения сохранены'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(true);
        }
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr.contains('Ошибка загрузки фотографии') || 
            errorStr.contains('uploadPhoto')) {
          errorMessage.value = 'Ошибка загрузки фотографии. Попробуйте другую.';
        } else {
          errorMessage.value = 'Ошибка сохранения: ${e.toString()}';
        }
      } finally {
        isLoading.value = false;
      }
    }

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_edit_child.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Редактировать ребёнка',
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
          child: DesktopContainer(
            maxWidth: 1100,
            child: SingleChildScrollView(
              padding: AppSpacing.paddingMD,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                const SizedBox(height: AppSpacing.lg),
                
                // Информационная подсказка
                Container(
                  padding: AppSpacing.paddingMD,
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info),
                  ),
                  child: Row(
                    children: [
                      AssetIcon(
                        assetPath: AppIcons.help,
                        size: 24,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Измените данные ребёнка. Фотографии можно добавить или заменить.',
                          style: safeCopyWith(
                            AppTypography.bodySmall,
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Фотографии
                photosAsync.when(
                  data: (response) {
                    final photoUrls = response.photos.map((p) => p.url).toList();
                    return Stack(
                      children: [
                        PhotoPreviewGrid(
                          existingPhotos: photoUrls,
                          selectedPhotos: selectedPhotos.value,
                          currentAvatarUrl: currentAvatarUrl,
                          onPhotosChanged: (photos) {
                            selectedPhotos.value = photos;
                          },
                          onPhotoDeleted: (index) {
                            if (index < photoUrls.length) {
                              showDeleteConfirmation(photoUrls[index]);
                            }
                          },
                          maxPhotos: 5,
                          allowAvatarSelection: false,
                        ),
                        if (isDeleting.value)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.3),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => Container(
                    padding: AppSpacing.paddingMD,
                    child: Column(
                      children: [
                        Text(
                          'Ошибка загрузки фото',
                          style: safeCopyWith(
                            AppTypography.bodyMedium,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(childPhotosProvider(child.id)),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
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
                
                // Кнопка сохранения
                AppMagicButton(
                  onPressed: isLoading.value ? null : handleUpdate,
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
                        'Сохранить',
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
