import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../shared/gradient_button.dart';
import '../shared/menzo_toast.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      showMenzoToast(context, 'Completa tu correo y contraseña.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).login(email, password);
    } on ApiException catch (e) {
      if (mounted) showMenzoToast(context, e.message);
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos iniciar sesión.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/branding/menzo-logo.png',
                  width: 72,
                  height: 72,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bienvenido de vuelta',
                  style: AppTextStyles.h1(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Iniciá sesión para volver a tu comunidad',
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.body(),
                  decoration: const InputDecoration(
                    hintText: 'Correo electrónico',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: AppTextStyles.body(),
                  decoration: const InputDecoration(hintText: 'Contraseña'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Iniciar sesión',
                  loading: _loading,
                  onPressed: _submit,
                  size: GradientButtonSize.lg,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text(
                    '¿No tenés cuenta? Registrate',
                    style: AppTextStyles.label(color: AppColors.cyan),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
