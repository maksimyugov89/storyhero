import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/route_names.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/models/child.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/magic/glassmorphic_card.dart';
import '../../../ui/components/glowing_capsule_button.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../ui/components/photo_preview_grid.dart';
import '../state/child_photos_provider.dart';

final childProvider = FutureProvider.family<Child, String>((ref, childId) async {
  final api = ref.watch(backendApiProvider);
  final children = await api.getChildren();
  try {
    return children.firstWhere((c) => c.id == childId);
  } catch (e) {
    throw Exception('Ребёнок не найден');
  }
});

class ChildProfileScreen extends HookConsumerWidget {
  final String childId;
  static const _storage = FlutterSecureStorage();

  const ChildProfileScreen({
    super.key,
    required this.childId,
  });
  
  /// Получает заголовки авторизации для загрузки изображений
  static Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        return {'Authorization': 'Bearer $token'};
      }
    } catch (e) {
      // Ignore errors
    }
    return {};
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childAsync = ref.watch(childProvider(childId));
    final fadeAnimation = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );
    final photosState = ref.watch(childPhotosProvider(childId));

    useEffect(() {
      fadeAnimation.forward();
      return null;
    }, []);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/logo/storyhero_bg_main.png'),
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
                title: const Text(
                  'Профиль ребёнка',
                  style: TextStyle(color: Colors.white),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: childAsync.when(
                data: (child) {
                  return FadeTransition(
                    opacity: fadeAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Большое фото ребёнка
                          Center(
                            child: Hero(
                              tag: 'child-avatar-${child.id}',
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(75),
                                  child: child.faceUrl != null && child.faceUrl!.isNotEmpty
                                      ? FutureBuilder<Map<String, String>>(
                                          future: _getAuthHeaders(),
                                          builder: (context, snapshot) {
                                            final headers = snapshot.data ?? {};
                                            return CachedNetworkImage(
                                              imageUrl: child.faceUrl!,
                                              width: 150,
                                              height: 150,
                                              fit: BoxFit.cover,
                                              httpHeaders: headers,
                                              placeholder: (context, url) => Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) {
                                                // Тихая обработка ошибки - показываем placeholder
                                                return Center(
                                                  child: Text(
                                                    child.name.isNotEmpty 
                                                        ? child.name[0].toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 60,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        )
                                      : Center(
                                          child: Text(
                                            child.name.isNotEmpty
                                                ? child.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 60,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Информация
                          GlassmorphicCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            child.name,
                                            style: (Theme.of(context).textTheme.headlineMedium ?? 
                                                    const TextStyle(fontSize: 24)).copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${child.age} лет',
                                            style: (Theme.of(context).textTheme.titleMedium ?? 
                                                    const TextStyle(fontSize: 18)).copyWith(
                                                  color: Colors.white70,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _InfoRow(
                                  iconAsset: AppIcons.magicStar,
                                  label: 'Интересы',
                                  value: child.interests.isNotEmpty ? child.interests : 'Не указано',
                                ),
                                const SizedBox(height: 16),
                                _InfoRow(
                                  icon: Icons.psychology,
                                  label: 'Характер',
                                  value: child.character.isNotEmpty ? child.character : 'Не указано',
                                ),
                                const SizedBox(height: 16),
                                _InfoRow(
                                  iconAsset: AppIcons.alert,
                                  label: 'Страхи',
                                  value: child.fears.isNotEmpty ? child.fears : 'Не указано',
                                ),
                                const SizedBox(height: 16),
                                _InfoRow(
                                  iconAsset: AppIcons.myBooks,
                                  label: 'Мораль истории',
                                  value: child.moral.isNotEmpty ? child.moral : 'Не указано',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (photosState.isNotEmpty || child.faceUrl != null)
                            GlassmorphicCard(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Фотографии',
                                        style: (Theme.of(context).textTheme.titleLarge ?? 
                                                const TextStyle(fontSize: 20)).copyWith(
                                              color: Colors.white,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '⭐ Нажмите на фото, чтобы выбрать его как аватарку профиля',
                                    style: (Theme.of(context).textTheme.bodySmall ?? 
                                            const TextStyle(fontSize: 12)).copyWith(
                                          color: Colors.white,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  _PhotoGalleryWithAvatar(
                                    child: child,
                                    childId: childId,
                                    fallbackFaceUrl: child.faceUrl,
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          // Кнопки действий
                          GlowingCapsuleButton(
                            text: '✏️ Редактировать профиль',
                            iconAsset: AppIcons.edit,
                            onPressed: () async {
                              try {
                                final updated = await context.push(
                                  RouteNames.childEdit.replaceAll(':id', child.id),
                                  extra: child,
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка навигации: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  context.go(RouteNames.home);
                                }
                              }
                            },
                            width: double.infinity,
                            height: 56,
                          ),
                          const SizedBox(height: 16),
                          GlowingCapsuleButton(
                            text: '📚 Книги ребёнка',
                            iconAsset: AppIcons.myBooks,
                            onPressed: () {
                              try {
                                context.push(RouteNames.childBooks.replaceAll(':id', child.id));
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка навигации: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  context.go(RouteNames.home);
                                }
                              }
                            },
                            width: double.infinity,
                            height: 56,
                          ),
                          const SizedBox(height: 16),
                          GlowingCapsuleButton(
                            text: '✨ Создать книгу',
                            iconAsset: AppIcons.generateStory,
                            onPressed: () {
                              try {
                                context.push(RouteNames.generate, extra: child);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка навигации: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  context.go(RouteNames.home);
                                }
                              }
                            },
                            width: double.infinity,
                            height: 56,
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
                  onRetry: () => ref.refresh(childProvider(childId)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGalleryWithAvatar extends HookConsumerWidget {
  final Child child;
  final String childId;
  final String? fallbackFaceUrl;

  const _PhotoGalleryWithAvatar({
    required this.child,
    required this.childId,
    this.fallbackFaceUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = useState<bool>(false);
    final photosState = ref.watch(childPhotosProvider(childId));
    final photosNotifier = ref.read(childPhotosProvider(childId).notifier);

    Future<void> _handleAvatarSelection(String photoUrl) async {
      if (isLoading.value) return;

      isLoading.value = true;

      try {
        final api = ref.read(backendApiProvider);
        await api.updateChild(
          id: childId,
          faceUrl: photoUrl,
        );

        photosNotifier.setAvatar(photoUrl);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Аватарка обновлена'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка обновления аватарки: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    void _showAvatarSelectionDialog(String photoUrl) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Выбрать аватарку',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Сделать это фото главным?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  ElevatedButton(
                    onPressed: isLoading.value
                        ? null
                        : () {
                            Navigator.pop(context);
                            _handleAvatarSelection(photoUrl);
                          },
                    child: isLoading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сделать главным'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final displayPhotos = photosState.isNotEmpty 
        ? photosState 
        : (fallbackFaceUrl != null && fallbackFaceUrl!.isNotEmpty ? [fallbackFaceUrl!] : <String>[]);
    final currentAvatar = displayPhotos.isNotEmpty ? displayPhotos.first : null;

    return PhotoPreviewGrid(
      existingPhotos: displayPhotos,
      currentAvatarUrl: currentAvatar,
      allowAvatarSelection: true,
      onPhotoSelectedAsAvatar: (url) {
        if (!isLoading.value) {
          _showAvatarSelectionDialog(url);
        }
      },
      maxPhotos: 5,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String label;
  final String value;

  const _InfoRow({
    this.icon,
    this.iconAsset,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (iconAsset != null)
          AssetIcon(
            assetPath: iconAsset!,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          )
        else if (icon != null)
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: (Theme.of(context).textTheme.bodySmall ?? 
                        const TextStyle(fontSize: 12)).copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: (Theme.of(context).textTheme.bodyMedium ?? 
                        const TextStyle(fontSize: 14)).copyWith(
                      color: Colors.white,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

