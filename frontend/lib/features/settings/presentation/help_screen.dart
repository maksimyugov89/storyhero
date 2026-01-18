import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../ui/components/asset_icon.dart';
import '../data/support_messages_provider.dart';
import '../../../core/models/support_message.dart';
import '../../../app/routes/route_names.dart';
import 'package:intl/intl.dart';
import '../../../ui/layouts/desktop_container.dart';

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedType = 'suggestion'; // suggestion, bug, question
  Timer? _pollingTimer;
  bool _isDisposed = false;

  // Интервал обновления сообщений (каждые 5 секунд)
  static const Duration _pollingInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
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
      
      // Обновляем список сообщений
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
        ref.invalidate(supportMessagesProvider);
      }
    });
  }

  Future<void> _loadUserEmail() async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.currentUser();
      if (user?.email != null && mounted) {
        setState(() {
          _emailController.text = user!.email;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopPolling();
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _messageTypeLabel {
    switch (_selectedType) {
      case 'bug':
        return 'Сообщение об ошибке';
      case 'question':
        return 'Вопрос';
      case 'suggestion':
      default:
        return 'Пожелание';
    }
  }

  String _getMessageHint() {
    switch (_selectedType) {
      case 'bug':
        return 'Опишите кратко вашу проблему';
      case 'question':
        return 'Опишите ваш вопрос';
      case 'suggestion':
      default:
        return 'Введите ваши пожелания, они очень важны для нас';
    }
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final message = _messageController.text.trim();
      
      final api = ref.read(backendApiProvider);
      
      // Отправляем сообщение через API (бэкенд отправит на почту и в телеграм)
      await api.sendSupportMessage(
        name: name,
        email: email,
        type: _selectedType,
        message: message,
      );

      // Обновляем список сообщений
      ref.invalidate(supportMessagesProvider);
        
        if (mounted) {
        // Показываем успешное сообщение
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: const Text('Сообщение отправлено!'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Спасибо за обращение!',
                    style: AppTypography.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ваше сообщение отправлено на почту и в Telegram. Мы свяжемся с вами в ближайшее время.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('👤 Имя: $name'),
                        Text('📧 Email: $email'),
                        Text('📝 Тип: $_messageTypeLabel'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              AppMagicButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Очищаем форму
                  _nameController.clear();
                  _messageController.clear();
                  _selectedType = 'suggestion';
                  setState(() {});
                },
                child: const Text('Закрыть'),
              ),
            ],
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
        setState(() => _isLoading = false);
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
    final messagesAsync = ref.watch(supportMessagesProvider);

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_main.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Помощь и поддержка',
          leading: IconButton(
            icon: AssetIcon(
              assetPath: AppIcons.back,
              size: 24,
              color: AppColors.onBackground,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: child,
          ),
          child: DesktopContainer(
            maxWidth: 900,
            child: SingleChildScrollView(
              padding: AppSpacing.paddingMD,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                const SizedBox(height: AppSpacing.md),
                
                // Заголовок
                AppMagicCard(
                  padding: AppSpacing.paddingLG,
                  child: Column(
                    children: [
                      AssetIcon(
                        assetPath: AppIcons.help,
                        size: 48,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Связаться с разработчиком',
                        style: AppTypography.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Напишите нам о проблемах, пожеланиях или задайте вопрос',
                        style: safeCopyWith(
                          AppTypography.bodyMedium,
                          color: AppColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Список отправленных сообщений
                messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Мои сообщения',
                          style: safeCopyWith(
                            AppTypography.headlineSmall,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...messages.map((message) => _buildMessageCard(message)),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Форма
                AppMagicCard(
                  padding: AppSpacing.paddingLG,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Тип сообщения
                      Text(
                        'Тип обращения',
                        style: safeCopyWith(
                          AppTypography.labelLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildTypeSelector(),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Имя
                      Text(
                        'Ваше имя',
                        style: safeCopyWith(
                          AppTypography.labelLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _FocusGlow(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Как к вам обращаться?',
                            prefixIcon: const Icon(Icons.person_outline),
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
                              return 'Пожалуйста, введите ваше имя';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Email
                      Text(
                        'Ваш Email',
                        style: safeCopyWith(
                          AppTypography.labelLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _FocusGlow(
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Для ответа на ваше обращение',
                            prefixIcon: AssetIcon(
                              assetPath: AppIcons.email,
                              size: 20,
                            ),
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
                              return 'Пожалуйста, введите email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Введите корректный email';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Сообщение
                      Text(
                        'Сообщение',
                        style: safeCopyWith(
                          AppTypography.labelLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _FocusGlow(
                        child: TextFormField(
                          controller: _messageController,
                          maxLines: 5,
                          maxLength: 1000,
                          decoration: InputDecoration(
                            hintText: _getMessageHint(),
                            alignLabelWithHint: true,
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
                              return 'Пожалуйста, введите сообщение';
                            }
                            if (value.trim().length < 10) {
                              return 'Сообщение слишком короткое (минимум 10 символов)';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Кнопка отправки сообщения (на почту и в телеграм)
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AppMagicButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      isLoading: _isLoading,
                      fullWidth: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, color: Colors.white, size: 24),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            _isLoading ? 'Отправка...' : '📧 Отправить на Email и Telegram',
                            style: safeCopyWith(
                              AppTypography.labelLarge,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // Подсказка
                Container(
                  padding: AppSpacing.paddingSM,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Сообщение будет отправлено на почту и в Telegram разработчику',
                          style: safeCopyWith(
                            AppTypography.bodySmall,
                            color: AppColors.onSurfaceVariant,
                          ),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeChip(
            'suggestion',
            '💡 Пожелание',
            Icons.lightbulb_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTypeChip(
            'bug',
            '🐛 Ошибка',
            Icons.bug_report_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTypeChip(
            'question',
            '❓ Вопрос',
            Icons.help_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withOpacity(0.2) 
              : AppColors.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: safeCopyWith(
                AppTypography.labelSmall,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppColors.error, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Удалить сообщение?'),
            ),
          ],
        ),
        content: const Text(
          'Вы уверены, что хотите удалить это сообщение? Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(backendApiProvider);
      await api.deleteSupportMessage(messageId);
      
      if (mounted) {
        // Обновляем список сообщений
        ref.invalidate(supportMessagesProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Сообщение удалено'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildMessageCard(SupportMessage message) {
    final isClosed = message.status == 'closed';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppMagicCard(
        padding: AppSpacing.paddingMD,
        onTap: () {
          context.push(RouteNames.supportMessageDetail.replaceAll(':id', message.id));
        },
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
                if (message.hasUnreadReplies)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusLabel(message.status),
                    style: AppTypography.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message.message,
              style: AppTypography.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  DateFormat('dd.MM.yyyy HH:mm').format(message.createdAt),
                  style: safeCopyWith(
                    AppTypography.bodySmall,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (message.repliesCount > 0) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '• ${message.repliesCount} ${message.repliesCount == 1 ? 'ответ' : message.repliesCount < 5 ? 'ответа' : 'ответов'}',
                    style: safeCopyWith(
                      AppTypography.bodySmall,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            // Кнопка удаления для закрытых диалогов
            if (isClosed) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _deleteMessage(message.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Удалить',
                            style: safeCopyWith(
                              AppTypography.labelSmall,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FocusGlow extends StatefulWidget {
  const _FocusGlow({required this.child});

  final Widget child;

  @override
  State<_FocusGlow> createState() => _FocusGlowState();
}

class _FocusGlowState extends State<_FocusGlow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: widget.child,
      ),
    );
  }
}
