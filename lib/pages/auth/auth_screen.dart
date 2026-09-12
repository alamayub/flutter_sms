import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/school_profile_provider.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/ui/app_vector_graphics.dart';
import 'import_db_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthScreen extends HookConsumerWidget {
  final bool initialIsRegister;

  const AuthScreen({super.key, this.initialIsRegister = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final authState = ref.watch(authStateProvider);
    final school = ref.watch(schoolProfileProvider);

    final isRegisterMode = useState(
      initialIsRegister || authState.status == AuthStatus.unregistered,
    );

    final localError = useState<String?>(null);

    final isNarrow = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      body: Stack(
        children: [
          // Background ambient aurora gradient mesh
          const Positioned.fill(child: AuroraMeshBackground(opacity: 0.8)),

          // Main Center Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isRegisterMode.value ? 720 : 440,
                ),
                child: AppCard(
                  depth3d: true,
                  isHoverable: false,
                  padding: EdgeInsets.all(isNarrow ? 20 : 32),
                  accentColor: theme.colorScheme.primary,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // School Crest Icon Badge
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.glow(
                            theme.colorScheme.primary,
                            opacity: 0.35,
                            blur: 12,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.school_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title & Subtitle
                      Text(
                        isRegisterMode.value
                            ? 'Register Institution'
                            : (school.name.isNotEmpty
                                ? school.name
                                : 'School Management System'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRegisterMode.value
                            ? 'Set up your school profile and administrator credentials'
                            : 'Sign in to access your administrative dashboard',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!isRegisterMode.value && school.code.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        AppBadge.primary(
                          'Affiliation: ${school.code}',
                          size: AppBadgeSize.sm,
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Error message if any
                      if (localError.value != null ||
                          authState.errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withAlpha(
                              160,
                            ),
                            borderRadius: AppRadius.roundedMd,
                            border: Border.all(
                              color: theme.colorScheme.error.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  localError.value ?? authState.errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Form Body
                      if (isRegisterMode.value)
                        RegisterScreen(
                          onErrorUpdate: (err) => localError.value = err,
                        )
                      else
                        LoginScreen(
                          onErrorUpdate: (err) => localError.value = err,
                        ),

                      const SizedBox(height: 20),

                      // Mode Switcher & Database Import Action
                      Center(
                        child: Text.rich(
                          TextSpan(
                            text:
                                isRegisterMode.value
                                    ? 'Already registered? '
                                    : 'Need to set up a new school? ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    isRegisterMode.value
                                        ? 'Sign In'
                                        : 'Register School',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationThickness: 1.2,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap = () {
                                        isRegisterMode.value =
                                            !isRegisterMode.value;
                                        localError.value = null;
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Database Import Option
                      const ImportDBScreen(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
