import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'asset_icon.dart';

// Тип для файлов (поддержка web/mobile)
typedef PhotoFile = io.File;

/// Компонент загрузки фото ребёнка с поддержкой до 5 фото
class PhotoPreviewGrid extends StatefulWidget {
  final List<String>? existingPhotos; // URLs существующих фото
  final List<PhotoFile>? selectedPhotos; // Локальные файлы
  final Function(List<PhotoFile>)? onPhotosChanged;
  final Function(int)? onPhotoDeleted;
  final Function(String)? onPhotoSelectedAsAvatar; // Callback для выбора аватарки (URL)
  final Function(PhotoFile)? onLocalPhotoSelectedAsAvatar; // Callback для выбора аватарки (локальный файл)
  final String? currentAvatarUrl; // URL текущей аватарки
  final int maxPhotos;
  final bool allowAvatarSelection; // Разрешить выбор аватарки

  const PhotoPreviewGrid({
    super.key,
    this.existingPhotos,
    this.selectedPhotos,
    this.onPhotosChanged,
    this.onPhotoDeleted,
    this.onPhotoSelectedAsAvatar,
    this.onLocalPhotoSelectedAsAvatar,
    this.currentAvatarUrl,
    this.maxPhotos = 5,
    this.allowAvatarSelection = false,
  });

  @override
  State<PhotoPreviewGrid> createState() => _PhotoPreviewGridState();
}

class _PhotoPreviewGridState extends State<PhotoPreviewGrid>
    with SingleTickerProviderStateMixin {
  late List<PhotoFile> _localPhotos;
  late List<String> _existingPhotoUrls;
  late AnimationController _animationController;
  static const _storage = FlutterSecureStorage();
  
  Future<Map<String, String>> _getAuthHeaders() async {
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
  void initState() {
    super.initState();
    _localPhotos = List.from(widget.selectedPhotos ?? []);
    _existingPhotoUrls = List.from(widget.existingPhotos ?? []);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(PhotoPreviewGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPhotos != oldWidget.selectedPhotos) {
      _localPhotos = List.from(widget.selectedPhotos ?? []);
    }
    if (widget.existingPhotos != oldWidget.existingPhotos) {
      _existingPhotoUrls = List.from(widget.existingPhotos ?? []);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int get totalPhotos => _localPhotos.length + _existingPhotoUrls.length;

  Future<void> _pickPhoto() async {
    if (totalPhotos >= widget.maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Можно загрузить максимум ${widget.maxPhotos} фото'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null && image.path.isNotEmpty) {
      final file = io.File(image.path);
      setState(() {
        _localPhotos.add(file);
      });
      widget.onPhotosChanged?.call(_localPhotos);
      _animationController.forward(from: 0.0);
    }
  }

  void _deleteLocalPhoto(int index) {
    setState(() {
      _localPhotos.removeAt(index);
    });
    widget.onPhotosChanged?.call(_localPhotos);
  }

  void _deleteExistingPhoto(int index) {
    widget.onPhotoDeleted?.call(index);
    setState(() {
      _existingPhotoUrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Создаем список всех фото (сначала существующие, потом новые)
    final allPhotos = <_PhotoItem>[
      ..._existingPhotoUrls.map((url) => _ExistingPhotoItem(url: url)),
      ..._localPhotos.map((file) => _LocalPhotoItem(file: file)),
    ];

    // Разбиваем на строки по 3 элемента (сетка 2x3)
    final rows = <List<_PhotoItem>>[];
    for (int i = 0; i < allPhotos.length; i += 3) {
      rows.add(allPhotos.sublist(i, (i + 3 > allPhotos.length) ? allPhotos.length : i + 3));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Фотографии (${totalPhotos}/${widget.maxPhotos})',
          style: (Theme.of(context).textTheme.titleMedium ?? 
                  const TextStyle(fontSize: 18)).copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Существующие и новые фото
            ...allPhotos.asMap().entries.map((entry) {
              final index = entry.key;
              final photo = entry.value;
              return _buildPhotoItem(
                photo,
                index,
                isDark,
                primaryColor,
              );
            }),
            // Кнопка добавления
            if (totalPhotos < widget.maxPhotos)
              _buildAddButton(isDark, primaryColor),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoItem(
    _PhotoItem photo,
    int index,
    bool isDark,
    Color primaryColor,
  ) {
    final isExisting = photo is _ExistingPhotoItem;
    final displayIndex = isExisting ? index : index;
    
    // Проверяем, является ли это фото текущей аватаркой
    final isCurrentAvatar = widget.allowAvatarSelection && 
        photo is _ExistingPhotoItem && 
        widget.currentAvatarUrl != null &&
        (photo as _ExistingPhotoItem).url == widget.currentAvatarUrl;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: value,
                child: child,
              ),
            );
          },
          child: Container(
            width: 100,
            height: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Stack(
                children: [
                  // Фото
                  photo is _ExistingPhotoItem
                      ? FutureBuilder<Map<String, String>>(
                          future: _getAuthHeaders(),
                          builder: (context, snapshot) {
                            final headers = snapshot.data ?? {};
                            return CachedNetworkImage(
                              imageUrl: (photo as _ExistingPhotoItem).url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              httpHeaders: headers,
                              placeholder: (context, url) => Container(
                                color: primaryColor.withOpacity(0.1),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                // Тихая обработка ошибки
                                return Container(
                                  color: primaryColor.withOpacity(0.1),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: primaryColor,
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : photo is _LocalPhotoItem
                          ? Image.file(
                              (photo as _LocalPhotoItem).file,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.image_not_supported,
                                color: primaryColor,
                              ),
                            ),
                  // Индикатор аватарки
                  if (isCurrentAvatar)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  // Кнопка удаления
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        if (photo is _ExistingPhotoItem) {
                          _deleteExistingPhoto(index);
                        } else if (photo is _LocalPhotoItem) {
                          _deleteLocalPhoto(index - _existingPhotoUrls.length);
                        }
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  // Подсказка для выбора аватарки
                  if (widget.allowAvatarSelection && !isCurrentAvatar)
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: () {
                            // Выбор фотографии как аватарки
                            if (photo is _ExistingPhotoItem) {
                              widget.onPhotoSelectedAsAvatar?.call((photo as _ExistingPhotoItem).url);
                            } else if (photo is _LocalPhotoItem) {
                              widget.onLocalPhotoSelectedAsAvatar?.call((photo as _LocalPhotoItem).file);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.2),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.star_border,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
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

  Widget _buildAddButton(bool isDark, Color primaryColor) {
    return GestureDetector(
      onTap: _pickPhoto,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(seconds: 2),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3 * value),
                    blurRadius: 12 * value,
                    spreadRadius: 2 * value,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.1),
                      primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: AssetIcon(
                  assetPath: AppIcons.add,
                  size: 32,
                  color: primaryColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Вспомогательные классы для типизации фото
abstract class _PhotoItem {}

class _ExistingPhotoItem extends _PhotoItem {
  final String url;
  _ExistingPhotoItem({required this.url});
}

class _LocalPhotoItem extends _PhotoItem {
  final PhotoFile file;
  _LocalPhotoItem({required this.file});
}

