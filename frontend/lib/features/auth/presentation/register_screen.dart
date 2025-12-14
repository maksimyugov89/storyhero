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
import '../data/auth_repository.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final showPassword = useState(false);
    final showConfirmPassword = useState(false);
    final fadeAnimation = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );

    useEffect(() {
      fadeAnimation.forward();
      return null;
    }, []);

    Future<void> handleRegister() async {
      if (emailController.text.isEmpty ||
          passwordController.text.isEmpty ||
          confirmPasswordController.text.isEmpty) {
        errorMessage.value = 'Заполните все поля';
        return;
      }

      if (passwordController.text != confirmPasswordController.text) {
        errorMessage.value = 'Пароли не совпадают';
        return;
      }

      if (passwordController.text.length < 6) {
        errorMessage.value = 'Пароль должен быть не менее 6 символов';
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      try {
        final authRepo = ref.read(authRepositoryProvider);
        final user = await authRepo.signUp(
          emailController.text.trim(),
          passwordController.text,
        );

        if (user == null) {
          errorMessage.value = 'Ошибка регистрации';
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Регистрация успешна! Добро пожаловать!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
          // authStatusProvider обновлен в AuthRepository
          // Router redirect автоматически перенаправит на /app/home
          // НЕ вызываем context.go вручную
        }
      } catch (e) {
        String errorText = 'Ошибка регистрации';
        
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
          title: 'Регистрация',
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
                context.go(RouteNames.login);
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
                  hint: 'Минимум 6 символов',
                  prefixIcon: Icons.lock_outline,
                  obscureText: !showPassword.value,
                  enabled: !isLoading.value,
                  showPasswordToggle: true,
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // Подтверждение пароля
                AppTextField(
                  controller: confirmPasswordController,
                  label: 'Подтвердите пароль',
                  hint: 'Повторите пароль',
                  prefixIcon: Icons.lock_outline,
                  obscureText: !showConfirmPassword.value,
                  enabled: !isLoading.value,
                  showPasswordToggle: true,
                  onSubmitted: handleRegister,
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
                
                // Кнопка регистрации
                AppMagicButton(
                  onPressed: isLoading.value ? null : handleRegister,
                  isLoading: isLoading.value,
                  fullWidth: true,
                  child: Text(
                    'Зарегистрироваться',
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
                
                // Кнопка входа
                AppButton(
                  text: 'Уже есть аккаунт? Войти',
                  outlined: true,
                  fullWidth: true,
                  onPressed: () => context.go(RouteNames.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
