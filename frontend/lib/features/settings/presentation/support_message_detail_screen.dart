import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/api/backend_api.dart';
import '../data/support_messages_provider.dart';
import '../../../ui/components/asset_icon.dart';
import 'package:intl/intl.dart';
import '../../../ui/layouts/desktop_container.dart';

class SupportMessageDetailScreen extends ConsumerStatefulWidget {
  final String messageId;

  const SupportMessageDetailScreen({super.key, required this.messageId});

  @override
  ConsumerState<SupportMessageDetailScreen> createState() => _SupportMessageDetailScreenState();
}

class _SupportMessageDetailScreenState extends ConsumerState<SupportMessageDetailScreen> {
  final _replyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSendingReply = false;
  bool _isMarkingAsRead = false;
  Timer? _pollingTimer;
  bool _isDisposed = false;

  // Интервал обновления сообщений (каждые 3 секунды для детального экрана)
  static const Duration _pollingInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    if (_isDisposed) return;
    
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      
      // Обновляем детали сообщения и список сообщений
      ref.invalidate(supportMessageDetailProvider(widget.messageId));
      ref.invalidate(supportMessagesProvider);
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем данные при возврате на экран
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        ref.invalidate(supportMessageDetailProvider(widget.messageId));
        ref.invalidate(supportMessagesProvider);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopPolling();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSendingReply = true);

    try {
      final api = ref.read(backendApiProvider);
      await api.sendSupportMessageReply(
        messageId: widget.messageId,
        message: _replyController.text.trim(),
      );

      if (mounted) {
        _replyController.clear();
        // Обновляем данные
        ref.invalidate(supportMessageDetailProvider(widget.messageId));
        ref.invalidate(supportMessagesProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ответ отправлен'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingReply = false);
      }
    }
  }

  Future<void> _markRepliesAsRead(List<String> replyIds) async {
    if (_isMarkingAsRead) return;

    setState(() => _isMarkingAsRead = true);

    try {
      final api = ref.read(backendApiProvider);
      
      // Помечаем все непрочитанные ответы как прочитанные
      for (final replyId in replyIds) {
        await api.markSupportMessageReplyAsRead(
          messageId: widget.messageId,
          replyId: replyId,
        );
      }

      if (mounted) {
        // Обновляем данные
        ref.invalidate(supportMessageDetailProvider(widget.messageId));
        ref.invalidate(supportMessagesProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMarkingAsRead = false);
      }
    }
  }

  Future<void> _closeMessage() async {
    try {
      final api = ref.read(backendApiProvider);
      await api.updateSupportMessageStatus(
        messageId: widget.messageId,
        status: 'closed',
      );

      if (mounted) {
        ref.invalidate(supportMessagesProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'bug':
        return 'Ошибка';
      case 'question':
        return 'Вопрос';
      case 'suggestion':
      default:
        return 'Пожелание';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'new':
        return 'Новое';
      case 'answered':
        return 'Отвечено';
      case 'closed':
        return 'Закрыто';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageDetailAsync = ref.watch(supportMessageDetailProvider(widget.messageId));

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_main.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Сообщение поддержки',
          leading: IconButton(
            icon: AssetIcon(
              assetPath: AppIcons.back,
              size: 24,
              color: AppColors.onBackground,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: messageDetailAsync.when(
          data: (detail) {
            final message = detail.message;
            final replies = detail.replies;
            final unreadReplies = replies.where((r) => !r.isRead && !r.repliedBy.startsWith('user_')).toList();
            final unreadReplyIds = unreadReplies.map((r) => r.id).toList();

            // Автоматически помечаем ответы как прочитанные при открытии
            if (unreadReplyIds.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _markRepliesAsRead(unreadReplyIds);
              });
            }

            return DesktopContainer(
              maxWidth: 900,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: AppSpacing.paddingMD,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                        // Информация о сообщении
                        AppMagicCard(
                          padding: AppSpacing.paddingLG,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getTypeLabel(message.type),
                                      style: safeCopyWith(
                                        AppTypography.labelMedium,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getStatusLabel(message.status),
                                      style: AppTypography.labelMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                message.message,
                                style: AppTypography.bodyLarge,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                DateFormat('dd.MM.yyyy HH:mm').format(message.createdAt),
                                style: safeCopyWith(
                                  AppTypography.bodySmall,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // Ответы администрации
                        if (replies.isNotEmpty) ...[
                          Text(
                            'Ответы',
                            style: safeCopyWith(
                              AppTypography.headlineSmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        ...replies.map((reply) {
                          final isFromAdmin = !reply.repliedBy.startsWith('user_');
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: AppMagicCard(
                              padding: AppSpacing.paddingMD,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isFromAdmin ? Icons.support_agent : Icons.person,
                                        size: 20,
                                        color: isFromAdmin ? AppColors.primary : AppColors.secondary,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        isFromAdmin ? 'Администрация' : 'Вы',
                                        style: safeCopyWith(
                                          AppTypography.labelLarge,
                                          fontWeight: FontWeight.bold,
                                          color: isFromAdmin ? AppColors.primary : AppColors.secondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (!reply.isRead && isFromAdmin)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    reply.replyText,
                                    style: AppTypography.bodyMedium,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    DateFormat('dd.MM.yyyy HH:mm').format(reply.createdAt),
                                    style: safeCopyWith(
                                      AppTypography.bodySmall,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: AppSpacing.lg),

                        // Форма ответа (если сообщение не закрыто)
                        if (message.status != 'closed') ...[
                          AppMagicCard(
                            padding: AppSpacing.paddingLG,
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ваш ответ',
                                    style: safeCopyWith(
                                      AppTypography.labelLarge,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  TextFormField(
                                    controller: _replyController,
                                    maxLines: 4,
                                    maxLength: 1000,
                                    decoration: InputDecoration(
                                      hintText: 'Введите ваш ответ...',
                                      filled: true,
                                      fillColor: AppColors.surface.withOpacity(0.5),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Пожалуйста, введите ответ';
                                      }
                                      if (value.trim().length < 10) {
                                        return 'Ответ слишком короткий (минимум 10 символов)';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AppMagicButton(
                                    onPressed: _isSendingReply ? null : _sendReply,
                                    isLoading: _isSendingReply,
                                    fullWidth: true,
                                    child: const Text('Отправить ответ'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        if (message.status != 'closed')
                          AppMagicButton(
                            onPressed: _closeMessage,
                            fullWidth: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.surfaceVariant,
                                AppColors.surfaceVariant.withOpacity(0.8),
                              ],
                            ),
                            child: Text(
                              'Закрыть диалог',
                              style: TextStyle(color: AppColors.onSurfaceVariant),
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.xl),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const LoadingWidget(message: 'Загрузка сообщения...'),
          error: (error, stack) => ErrorDisplayWidget(
            error: error,
            onRetry: () => ref.invalidate(supportMessageDetailProvider(widget.messageId)),
          ),
        ),
      ),
    );
  }
}

