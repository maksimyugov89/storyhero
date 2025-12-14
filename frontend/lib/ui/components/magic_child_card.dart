import 'package:flutter/material.dart';
import '../../core/models/child.dart';
import '../../core/theme/app_theme_magic.dart';
import '../../core/widgets/magic/glassmorphic_card.dart';
import 'asset_icon.dart';

/// Анимированная карточка ребёнка с фото-каруселью и действиями
class MagicChildCard extends StatefulWidget {
  final Child child;
  final List<String>? photoUrls; // До 5 фото
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCreateBook;

  const MagicChildCard({
    super.key,
    required this.child,
    this.photoUrls,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onCreateBook,
  });

  @override
  State<MagicChildCard> createState() => _MagicChildCardState();
}

class _MagicChildCardState extends State<MagicChildCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late PageController _pageController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  
  int _currentPhotoIndex = 0;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleController.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    // Используем переданные photoUrls или формируем из child.faceUrl
    final photoUrls = widget.photoUrls ?? 
        (widget.child.faceUrl != null && widget.child.faceUrl!.isNotEmpty 
            ? [widget.child.faceUrl!] 
            : []);
    final hasPhotos = photoUrls.isNotEmpty;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
        builder: (context, child) {
          final scaleValue = _scaleAnimation.value;
          final glowValue = _glowAnimation.value;

          return Transform.scale(
            scale: scaleValue,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              // Убрали boxShadow - он создавал ореол вокруг карточки
              child: GlassmorphicCard(
                borderRadius: 32,
                onTap: widget.onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Фото-карусель или аватар
                    _buildPhotoSection(hasPhotos, photoUrls, primaryColor, secondaryColor),
                    
                    // Информация о ребёнке
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.child.name,
                            style: (Theme.of(context).textTheme.headlineSmall ?? 
                                    const TextStyle(fontSize: 20)).copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.cake,
                                size: 16,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.child.age} лет',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Кнопки действий
                    _buildActionButtons(primaryColor),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoSection(
    bool hasPhotos,
    List<String> photoUrls,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withOpacity(0.3),
              secondaryColor.withOpacity(0.2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: hasPhotos
            ? Stack(
                children: [
                  // Карусель фото
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPhotoIndex = index);
                    },
                    itemCount: photoUrls.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        photoUrls[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildPlaceholderAvatar(primaryColor);
                        },
                        errorBuilder: (context, error, stackTrace) {
                          // Тихая обработка ошибки
                          return _buildPlaceholderAvatar(primaryColor);
                        },
                      );
                    },
                  ),
                  // Индикаторы
                  if (photoUrls.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          photoUrls.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPhotoIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentPhotoIndex == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : _buildPlaceholderAvatar(primaryColor),
      ),
    );
  }

  Widget _buildPlaceholderAvatar(Color primaryColor) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              primaryColor,
              AppThemeMagic.secondaryColor,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.child.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: primaryColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            iconPath: AppIcons.edit,
            label: 'Редактировать',
            onTap: widget.onEdit,
            color: primaryColor,
          ),
          _buildActionButton(
            iconPath: AppIcons.generateStory,
            label: 'Создать книгу',
            onTap: widget.onCreateBook,
            color: AppThemeMagic.secondaryColor,
          ),
          _buildActionButton(
            iconPath: AppIcons.delete,
            label: 'Удалить',
            onTap: widget.onDelete,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String iconPath,
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Убрали Container с BoxDecoration - теперь просто иконка без ореола
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: AssetIcon(
              assetPath: iconPath,
              size: 32,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

