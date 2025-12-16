import 'package:flutter/material.dart';
import '../utils/error_analyzer.dart';
import 'magic/glassmorphic_card.dart';
import 'magic/magic_button.dart';
import '../../ui/components/asset_icon.dart';
import '../utils/text_style_helpers.dart';

class ErrorDisplayWidget extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final VoidCallback? onExit;
  final String? customMessage;
  final String exitText;

  /// Создает виджет ошибки с автоматическим анализом ошибки
  /// 
  /// [error] - объект ошибки (Exception, DioException и т.д.)
  /// [onRetry] - callback для повторной попытки (должен вызывать ref.refresh или ref.invalidate)
  /// [onExit] - callback для выхода/закрытия экрана
  /// [customMessage] - кастомное сообщение (если null, используется автоматический анализ)
  const ErrorDisplayWidget({
    super.key,
    this.error,
    this.onRetry,
    this.customMessage,
    this.onExit,
    this.exitText = 'Выйти',
  }) : assert(
          error != null || customMessage != null,
          'Необходимо указать либо error, либо customMessage',
        );

  @override
  Widget build(BuildContext context) {
    // Анализируем ошибку или используем кастомное сообщение
    final analysis = customMessage != null
        ? ErrorAnalysis(
            userFriendlyMessage: customMessage!,
          )
        : ErrorAnalyzer.analyze(error!);

    // Выбираем иконку в зависимости от типа ошибки
    final icon = analysis.isNetworkError
        ? Icons.wifi_off
        : analysis.isServerError
            ? Icons.cloud_off
            : Icons.error_outline;

    final iconColor = analysis.isNetworkError
        ? Colors.orange
        : analysis.isServerError
            ? Colors.red
            : Theme.of(context).colorScheme.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: GlassmorphicCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Иконка
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor.withOpacity(0.1),
                    ),
                    child: Icon(
                      icon,
                      size: 40,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Заголовок
                  Text(
                    analysis.isNetworkError
                        ? 'Нет соединения'
                        : analysis.isServerError
                            ? 'Сервер недоступен'
                            : 'Произошла ошибка',
                    style: safeCopyWith(
                      Theme.of(context).textTheme.headlineSmall,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Сообщение
                  Text(
                    analysis.userFriendlyMessage,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  // Кнопки действий
                  if (onRetry != null || onExit != null) ...[
                    const SizedBox(height: 32),
                    if (onRetry != null)
                      SizedBox(
                        width: double.infinity,
                        child: MagicButton(
                          onPressed: onRetry,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AssetIcon(
                                assetPath: AppIcons.success,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Повторить',
                                style: safeTextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (onExit != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: MagicButton(
                          onPressed: onExit,
                          gradient: LinearGradient(
                            colors: [
                              Colors.redAccent.withOpacity(0.9),
                              Colors.deepOrangeAccent.withOpacity(0.9),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AssetIcon(
                                assetPath: AppIcons.back,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                exitText,
                                style: safeTextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

