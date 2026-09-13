import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loader_widget.dart';

class LoginScreen extends HookConsumerWidget {
  final Function(String?) onErrorUpdate;
  const LoginScreen({super.key, required this.onErrorUpdate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final authState = ref.watch(authStateProvider);
    final loginUsernameCtrl = useTextEditingController();
    final loginPasswordCtrl = useTextEditingController();
    final obscurePassword = useState<bool>(true);

    void submitLogin() async {
      if (!formKey.currentState!.validate()) return;
      formKey.currentState?.save();
      onErrorUpdate(null);
      if (loginPasswordCtrl.text.isEmpty) {
        onErrorUpdate('Please enter your password or PIN');
        return;
      }

      final success = await ref
          .read(authStateProvider.notifier)
          .login(
            username: loginUsernameCtrl.text,
            password: loginPasswordCtrl.text,
          );

      if (!success && context.mounted) {
        final error = ref.read(authStateProvider).errorMessage;
        if (error != null) {
          onErrorUpdate(error);
        }
      }
    }

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: loginUsernameCtrl,
            decoration: InputDecoration(
              labelText: 'Administrator Username',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: loginPasswordCtrl,
            obscureText: obscurePassword.value,
            onFieldSubmitted: (_) => submitLogin(),
            decoration: InputDecoration(
              labelText: 'Password or PIN',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword.value
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => obscurePassword.value = !obscurePassword.value,
              ),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
              elevation: 2,
            ),
            onPressed: authState.isLoading ? null : submitLogin,
            child:
                authState.isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: LoaderWidget(),
                    )
                    : const Text(
                      'Sign In to SMS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
