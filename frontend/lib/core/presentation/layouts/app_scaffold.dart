import 'package:flutter/material.dart';
import 'app_page.dart';

/// Расширение Scaffold с магическими стилями
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final String? backgroundImage;
  final double overlayOpacity;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundImage,
    this.overlayOpacity = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    return AppPage(
      backgroundImage: backgroundImage,
      overlayOpacity: overlayOpacity,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
      ),
    );
  }
}









