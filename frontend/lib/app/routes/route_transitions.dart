import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Типы переходов
enum TransitionType {
  magic,
  slide,
  fade,
  scale,
}

/// Создает страницу с кастомной анимацией
Page<T> buildPageWithTransition<T extends Object?>(
  Widget child, {
  required LocalKey key,
  TransitionType type = TransitionType.magic,
  String? name,
}) {
  return CustomTransitionPage<T>(
    key: key,
    name: name,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (type) {
        case TransitionType.magic:
          return _buildMagicTransition(animation, child);
        case TransitionType.slide:
          return _buildSlideTransition(animation, child);
        case TransitionType.fade:
          return _buildFadeTransition(animation, child);
        case TransitionType.scale:
          return _buildScaleTransition(animation, child);
      }
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}

Widget _buildMagicTransition(Animation<double> animation, Widget child) {
  final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
  final slide = Tween<Offset>(
    begin: const Offset(0.0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
  ));
  final scale = Tween<double>(begin: 0.95, end: 1.0).animate(
    CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
  );
  
  return FadeTransition(
    opacity: fade,
    child: SlideTransition(
      position: slide,
      child: ScaleTransition(
        scale: scale,
        child: child,
      ),
    ),
  );
}

Widget _buildSlideTransition(Animation<double> animation, Widget child) {
  final slide = Tween<Offset>(
    begin: const Offset(1.0, 0.0),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
  ));
  
  return SlideTransition(position: slide, child: child);
}

Widget _buildFadeTransition(Animation<double> animation, Widget child) {
  final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
  return FadeTransition(opacity: fade, child: child);
}

Widget _buildScaleTransition(Animation<double> animation, Widget child) {
  final scale = Tween<double>(begin: 0.8, end: 1.0).animate(
    CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
  );
  return ScaleTransition(scale: scale, child: child);
}









