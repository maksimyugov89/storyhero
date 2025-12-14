import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes/route_names.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/presentation/widgets/inputs/app_text_field.dart';
import '../../../core/presentation/widgets/buttons/app_button.dart';
import '../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../core/presentation/widgets/buttons/app_icon_button.dart';
import '../data/auth_repository.dart';
import '../../../core/auth/auth_status_provider.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final showPassword = useState(false);
    final lastLoginTime = useRef<DateTime?>(null);
    final fadeAnimation = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );

    useEffect(() {
      fadeAnimation.forward();
      return null;
    }, []);

    Future<void> handleLogin() async {
      // Защита от повторных запросов
      if (isLoading.value) {
        return; // Уже выполняется запрос
      }

      // Debounce: защита от множественных быстрых нажатий
      final now = DateTime.now();
      if (lastLoginTime.value != null) {
        final timeSinceLastLogin = now.difference(lastLoginTime.value!);
        if (timeSinceLastLogin.inMilliseconds < 500) {
          return; // Слишком быстро после предыдущего запроса
        }
      }
      lastLoginTime.value = now;

      if (emailController.text.isEmpty || passwordController.text.isEmpty) {
        errorMessage.value = 'Заполните все поля';
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      try {
        final authRepo = ref.read(authRepositoryProvider);
        final user = await authRepo.signIn(
          emailController.text.trim(),
          passwordController.text,
        );

        if (user == null) {
          errorMessage.value = 'Неверный email или пароль';
        } else {
          // Токен сохранен, authStatusProvider обновлен в AuthRepository
          // Router redirect автоматически перенаправит на /app/home
          // НЕ вызываем context.go вручную - навигация происходит через redirect
          print('[LoginScreen] Успешный вход, ожидаем redirect на home');
        }
      } catch (e) {
        String errorText = 'Ошибка входа';
        
        if (e is Exception) {
          final errorStr = e.toString();
          if (errorStr.startsWith('Exception: ')) {
            errorText = errorStr.substring(11).trim();
          } else {
            errorText = errorStr.trim();
          }
        } else {
          errorText = e.toString().trim();
        }
        
        final lowerError = errorText.toLowerCase();
        if (lowerError.contains('dioexception') || 
            lowerError.contains('httpexception') ||
            lowerError.contains('is not a subtype') ||
            lowerError.contains('type cast') ||
            lowerError.contains('typeerror') ||
            lowerError.contains('no such method') ||
            lowerError.contains('null check operator')) {
          errorText = 'Ошибка подключения. Проверьте интернет и попробуйте снова.';
        }
        
        errorMessage.value = errorText;
      } finally {
        isLoading.value = false;
      }
    }

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_menyu.png',
      overlayOpacity: 0.3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Вход',
          leading: IconButton(
            icon: AssetIcon(
              assetPath: AppIcons.back,
              size: 24,
              color: AppColors.onBackground,
            ),
            onPressed: () {
              if (context.canPop()) {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RouteNames.splash);
                }
              } else {
                context.go(RouteNames.splash);
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                
                // Email поле
                AppTextField(
                  controller: emailController,
                  label: 'Email',
                  hint: 'example@email.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading.value,
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // Пароль поле
                AppTextField(
                  controller: passwordController,
                  label: 'Пароль',
                  hint: 'Введите пароль',
                  prefixIcon: Icons.lock_outline,
                  obscureText: !showPassword.value,
                  enabled: !isLoading.value,
                  onSubmitted: isLoading.value ? null : handleLogin,
                ),
                
                const SizedBox(height: AppSpacing.sm),
                
                // Забыли пароль
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Реализовать восстановление пароля
                    },
                    child: Text(
                      'Забыли пароль?',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                
                // Ошибка
                if (errorMessage.value != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: AppSpacing.paddingMD,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        AssetIcon(
                          assetPath: AppIcons.alert,
                          size: 20,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            errorMessage.value!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: AppSpacing.xl),
                
                // Кнопка входа
                AppMagicButton(
                  onPressed: isLoading.value ? null : handleLogin,
                  isLoading: isLoading.value,
                  fullWidth: true,
                  child: Text(
                    'Войти',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Разделитель
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.onSurfaceVariant.withOpacity(0.3))),
                    Padding(
                      padding: AppSpacing.paddingHMD,
                      child: Text(
                        'или',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.onSurfaceVariant.withOpacity(0.3))),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Кнопка регистрации
                AppButton(
                  text: 'Зарегистрироваться',
                  outlined: true,
                  fullWidth: true,
                  onPressed: () => context.go(RouteNames.register),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
