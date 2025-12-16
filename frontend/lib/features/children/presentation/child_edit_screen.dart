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
import '../state/child_photos_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;

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
    final interestsController = useTextEditingController(text: child.interests ?? '');
    final fearsController = useTextEditingController(text: child.fears ?? '');
    final characterController = useTextEditingController(text: child.character ?? '');
    final moralController = useTextEditingController(text: child.moral ?? '');
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final selectedPhotos = useState<List<io.File>>([]);
    final photosState = ref.watch(childPhotosProvider(child.id));
    final photosNotifier = ref.read(childPhotosProvider(child.id).notifier);
    final fadeAnimation = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );

    useEffect(() {
      fadeAnimation.forward();
      return null;
    }, []);

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
        final photosNotifier = ref.read(childPhotosProvider(child.id).notifier);
        
        final updatedChild = await api.updateChild(
          id: child.id,
          name: nameController.text.trim(),
          age: age,
          interests: interestsController.text.trim(),
          fears: fearsController.text.trim(),
          character: characterController.text.trim(),
          moral: moralController.text.trim(),
          faceUrl: photosState.isNotEmpty ? photosState.first : null,
          photos: selectedPhotos.value.isNotEmpty ? selectedPhotos.value : null,
          existingPhotoUrls: photosState.isNotEmpty ? photosState : null,
        );

        if (updatedChild.faceUrl != null && updatedChild.faceUrl!.isNotEmpty) {
          photosNotifier.addPhoto(updatedChild.faceUrl!);
        }

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
          child: SingleChildScrollView(
            padding: AppSpacing.paddingMD,
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
                PhotoPreviewGrid(
                  existingPhotos: photosState,
                  selectedPhotos: selectedPhotos.value,
                  onPhotosChanged: (photos) {
                    selectedPhotos.value = photos;
                  },
                  maxPhotos: 5,
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
                  prefixIcon: Icons.book_outlined,
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
    );
  }
}
