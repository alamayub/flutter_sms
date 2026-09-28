import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sms/config/extensions.dart';

import '../config/theme.dart';
import '../widgets/loader_widget.dart';
import '../widgets/ui/app_vector_graphics.dart';
import 'wrapper.dart';

/// Production-grade branded animated splash screen for Mero School
class SplashScreen extends HookConsumerWidget {
  final Widget? nextScreen;
  final Duration displayDuration;

  const SplashScreen({
    super.key,
    this.nextScreen,
    this.displayDuration = const Duration(milliseconds: 1800),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animController = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );

    final fadeAnimation = CurvedAnimation(
      parent: animController,
      curve: Curves.easeOutCubic,
    );

    final scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeOutBack),
    );

    useEffect(() {
      animController.forward();

      final timer = Timer(displayDuration, () {
        if (!context.mounted) return;

        final target = nextScreen ?? const Wrapper();
        context.pushReplacementFade(target);
      });

      return timer.cancel;
    }, [animController, displayDuration, nextScreen]);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Brand Crest Shield Emblem
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withAlpha(isDark ? 110 : 80),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: Colors.white.withAlpha(isDark ? 60 : 80),
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Specular top highlight
              Positioned(
                top: 0,
                left: 6,
                right: 6,
                height: 1.5,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppGradients.specularHighlight,
                  ),
                ),
              ),
              const Icon(Icons.school_rounded, size: 54, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Brand Name "Mero School"
        Text(
          'Mero School',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            fontSize: 32,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),

        // Brand Tagline
        Text(
          'SCHOOL MANAGEMENT SYSTEM',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            fontSize: 11.5,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 44),

        // Ambient Progress / Loading Indicator
        SizedBox(
          width: 38,
          height: 38,
          child: LoaderWidget(
            strokeWidth: 2.5,
            valueColor: theme.colorScheme.primary,
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background ambient glowing aurora
          const Positioned.fill(child: AuroraMeshBackground(opacity: 0.9)),

          // Centered Content
          Center(
            child:
                reduceMotion
                    ? content
                    : FadeTransition(
                      opacity: fadeAnimation,
                      child: ScaleTransition(
                        scale: scaleAnimation,
                        child: content,
                      ),
                    ),
          ),

          // Footer Version Tag
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'v1.0.0 • Offline First Edition',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
