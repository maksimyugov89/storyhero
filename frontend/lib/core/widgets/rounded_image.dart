import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class RoundedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  const RoundedImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.radius = 12,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(
          Icons.image_outlined,
          size: (width != null && height != null)
              ? (width! < height! ? width! * 0.5 : height! * 0.5)
              : 48,
          color: Colors.grey[600],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          // Тихая обработка ошибки - не логируем в консоль
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey[600],
              size: (width != null && height != null)
                  ? (width! < height! ? width! * 0.5 : height! * 0.5)
                  : 48,
            ),
          );
        },
        httpHeaders: const {},
      ),
    );
  }
}

