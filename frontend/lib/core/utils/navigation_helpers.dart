import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/routes/route_names.dart';

/// Безопасный pop с fallback на home
void safePop(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(RouteNames.home);
  }
}

/// Безопасный pop с fallback на указанный маршрут
void safePopOrGo(BuildContext context, String fallbackRoute) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallbackRoute);
  }
}

