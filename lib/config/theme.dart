import 'dart:ui';
import 'package:flutter/material.dart';

/// Spacing design tokens (matching Tailwind / modern web design system)
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double xxxxl = 48.0;
}

/// Border radius design tokens
class AppRadius {
  static const double xs = 4.0;
  static const double sm = 6.0;
  static const double md = 8.0;
  static const double lg = 10.0;
  static const double xl = 12.0;
  static const double xxl = 16.0;
  static const double full = 9999.0;

  static BorderRadius get roundedXs => BorderRadius.circular(xs);
  static BorderRadius get roundedSm => BorderRadius.circular(sm);
  static BorderRadius get roundedMd => BorderRadius.circular(md);
  static BorderRadius get roundedLg => BorderRadius.circular(lg);
  static BorderRadius get roundedXl => BorderRadius.circular(xl);
  static BorderRadius get roundedXxl => BorderRadius.circular(xxl);
  static BorderRadius get roundedFull => BorderRadius.circular(full);
}

/// Standard button sizing and dimension tokens matching modern SaaS UI
class AppButtonSize {
  /// Small compact button (34px height, 12px font, 16px icon, 12px padding)
  static const double heightSm = 34.0;
  static const EdgeInsets paddingSm = EdgeInsets.symmetric(
    horizontal: 12.0,
    vertical: 7.0,
  );
  static const double fontSizeSm = 12.0;
  static const double iconSizeSm = 16.0;

  /// Standard medium button (44px height, 14px font, 18px icon, 18px padding)
  static const double heightMd = 44.0;
  static const EdgeInsets paddingMd = EdgeInsets.symmetric(
    horizontal: 18.0,
    vertical: 11.0,
  );
  static const double fontSizeMd = 14.0;
  static const double iconSizeMd = 18.0;

  /// Prominent large button (50px height, 15px font, 20px icon, 24px padding)
  static const double heightLg = 50.0;
  static const EdgeInsets paddingLg = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 13.0,
  );
  static const double fontSizeLg = 15.0;
  static const double iconSizeLg = 20.0;
}

/// Shared heights for interactive controls across the application.
class AppControlSize {
  static const double standard = AppButtonSize.heightMd;
  static const double compact = AppButtonSize.heightSm;
  static const double tab = standard;
}

/// Transition durations and curves matching:
/// transition: background-color 300ms cubic-bezier(0.4, 0, 0.2, 1)
class AppTransitions {
  /// 300ms cubic-bezier(0.4, 0, 0.2, 1)
  static const Duration duration = Duration(milliseconds: 300);
  static const Cubic curve = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Default subtle 200ms ease on surfaces
  static const Duration subtleDuration = Duration(milliseconds: 200);
  static const Curve subtleCurve = Curves.ease;
}

/// Global cursor pointer & disabled not-allowed resolvers matching:
/// button, select, a, [role="button"], checkbox, radio, label -> cursor: pointer
/// button:disabled, select:disabled, input:disabled, [disabled] -> cursor: not-allowed
class AppCursors {
  static WidgetStateProperty<MouseCursor> get interactive =>
      WidgetStateProperty.resolveWith<MouseCursor>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return SystemMouseCursors.forbidden; // cursor: not-allowed
        }
        return SystemMouseCursors.click; // cursor: pointer
      });
}

/// Modern soft, layered elevation & shadow tokens for high-end SaaS appearance
class AppShadows {
  /// Subtle card shadow for light mode
  static const List<BoxShadow> cardLight = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0E0F172A), blurRadius: 10, offset: Offset(0, 3)),
  ];

  /// Elevated card shadow for hover states
  static const List<BoxShadow> hoverLight = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x180F172A), blurRadius: 20, offset: Offset(0, 8)),
  ];

  /// Dark mode subtle elevation
  static const List<BoxShadow> cardDark = [
    BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Dark mode hover elevation
  static const List<BoxShadow> hoverDark = [
    BoxShadow(color: Color(0x60000000), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// Floating popovers and dropdown menus
  static List<BoxShadow> popover(bool isDark) => [
    BoxShadow(
      color: isDark ? const Color(0x66000000) : const Color(0x180F172A),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Colored glowing focal shadow for active indicators or primary buttons
  static List<BoxShadow> glow(
    Color color, {
    double opacity = 0.25,
    double blur = 12,
  }) => [
    BoxShadow(
      color: color.withAlpha((opacity * 255).round()),
      blurRadius: blur,
      offset: const Offset(0, 4),
    ),
  ];

  /// Multi-tier 3D depth shadow combining subtle ambient occlusion + directional key light
  static List<BoxShadow> depth3d(bool isDark) => [
    BoxShadow(
      color: isDark ? const Color(0x66000000) : const Color(0x0A0F172A),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: isDark ? const Color(0x55000000) : const Color(0x120F172A),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: isDark ? const Color(0x40000000) : const Color(0x080F172A),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
  ];

  /// Floating dock / mobile bottom nav elevated shadow
  static List<BoxShadow> floatingDock(bool isDark) => [
    BoxShadow(
      color: isDark ? const Color(0x80000000) : const Color(0x1E0F172A),
      blurRadius: 32,
      offset: const Offset(0, 10),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: isDark ? const Color(0x40000000) : const Color(0x100F172A),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Subtle gradients and surface styling for visual polish
class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accent = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warm = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emerald = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Top-edge specular highlight simulating reflection on polished glass/metal edge
  static const LinearGradient specularHighlight = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x0DFFFFFF), Colors.transparent],
    stops: [0.0, 0.4, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Ambient multi-stop aurora radial gradient
  static RadialGradient auroraGlow({
    required Color primary,
    required Color accent,
    double radius = 1.2,
  }) => RadialGradient(
    center: const Alignment(0.6, -0.7),
    radius: radius,
    colors: [accent.withAlpha(50), primary.withAlpha(35), Colors.transparent],
    stops: const [0.0, 0.5, 1.0],
  );

  /// Card surface light bevel gradient for subtle 3D physical surface feel
  static LinearGradient cardBevel(bool isDark) => LinearGradient(
    colors:
        isDark
            ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
            : const [Colors.white, Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glassCard(bool isDark) => LinearGradient(
    colors:
        isDark
            ? [
              const Color(0xFF1E293B).withAlpha(220),
              const Color(0xFF0F172A).withAlpha(190),
            ]
            : [
              Colors.white.withAlpha(235),
              const Color(0xFFF8FAFC).withAlpha(210),
            ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient topAccentBar(Color color) => LinearGradient(
    colors: [color, color.withAlpha(50)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// Luminous border tokens
class AppBorders {
  static BorderSide subtle(bool isDark) => BorderSide(
    color: isDark ? const Color(0x1FFFFFFF) : const Color(0x140F172A),
    width: 1.0,
  );

  static BorderSide luminous(Color color, {double opacity = 0.4}) =>
      BorderSide(color: color.withAlpha((opacity * 255).round()), width: 1.2);
}

/// Micro-animation duration and curve tokens respecting motion design
class AppMotion {
  static const Duration snappy = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration smooth = Duration(milliseconds: 350);

  static const Curve snappyCurve = Curves.easeOutQuad;
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve smoothCurve = Curves.easeInOutCubic;
}

/// Typography tokens with OpenType font feature settings:
/// font-feature-settings: "cv02", "cv03", "cv04", "cv11"
class AppTypography {
  static const List<FontFeature> fontFeatures = [
    FontFeature('cv02'),
    FontFeature('cv03'),
    FontFeature('cv04'),
    FontFeature('cv11'),
  ];

  static TextTheme createTextTheme(Color textColor, Color mutedColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: mutedColor,
        fontFeatures: fontFeatures,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: textColor,
        fontFeatures: fontFeatures,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: mutedColor,
        fontFeatures: fontFeatures,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: mutedColor,
        fontFeatures: fontFeatures,
      ),
    );
  }

  /// Standard button label style with OpenType feature settings
  static TextStyle button({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) => TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: 0.1,
    height: 1.2,
    fontFeatures: fontFeatures,
  );

  /// Standard tab label style with OpenType feature settings
  static TextStyle tab({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) => TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: 0.15,
    height: 1.2,
    fontFeatures: fontFeatures,
  );

  /// Standard input label style
  static TextStyle inputLabel({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) => TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: 0.1,
    fontFeatures: fontFeatures,
  );
}

/// Global scroll behavior removing scroll indicator thumbs and scrollbars:
/// * { scrollbar-width: none; -ms-overflow-style: none; }
/// *::-webkit-scrollbar, ::-webkit-scrollbar { display: none; }
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Hide scrollbars completely while preserving fluid scrolling
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

/// Professional print formatting styles & page layout constants
class AppPrintStyle {
  static const Color printBackground = Color(0xFFFFFFFF);
  static const Color printText = Color(0xFF0F172A);
  static const Color printBorder = Color(0xFFCBD5E1);

  // 15mm page margin
  static const EdgeInsets pageMargin = EdgeInsets.all(15.0 * 3.7795);
  static const EdgeInsets printContainerPadding = EdgeInsets.zero;

  // Student ID Badge Print Sheet (2 columns, 16px gap, 12px padding)
  static const double idCardGridGap = 16.0;
  static const EdgeInsets idCardSheetPadding = EdgeInsets.all(12.0);
}

/// Shorthand brand & semantic color tokens
class AppColors {
  static const Color primary = AppTheme.primaryColor;
  static const Color primaryLight = AppTheme.primaryLight;
  static const Color primaryDark = AppTheme.primaryDark;
  static const Color secondary = AppTheme.secondaryColor;
  static const Color accent = AppTheme.accentColor;
  static const Color success = AppTheme.successColor;
  static const Color error = AppTheme.errorColor;
  static const Color warning = AppTheme.warningColor;
  static const Color info = AppTheme.infoColor;

  static const Color lightBackground = AppTheme.lightBackground;
  static const Color lightSurface = AppTheme.lightSurface;
  static const Color lightBorder = AppTheme.lightBorder;
  static const Color darkBackground = AppTheme.darkBackground;
  static const Color darkSurface = AppTheme.darkSurface;
  static const Color darkBorder = AppTheme.darkBorder;
}

class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF1E3A8A); // Deep Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF172554);

  static const Color secondaryColor = Color(0xFF0D9488); // Teal
  static const Color accentColor = Color(0xFFF59E0B); // Warm Amber

  // Semantic Status Colors for School Management
  static const Color successColor = Color(0xFF10B981); // Present, Paid, Active
  static const Color errorColor = Color(0xFFEF4444); // Absent, Unpaid, Inactive
  static const Color warningColor = Color(0xFFF59E0B); // Late, Partial, Pending
  static const Color infoColor = Color(0xFF3B82F6); // Holiday, Notice

  // Neutral Light Colors (Tailwind Slate scale)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Neutral Dark Colors (Tailwind Slate scale)
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light Theme
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDBEAFE),
      onPrimaryContainer: primaryDark,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFCCFBF1),
      onSecondaryContainer: Color(0xFF134E4A),
      error: errorColor,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF991B1B),
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: Color(0xFFF1F5F9),
      outline: lightBorder,
      outlineVariant: Color(0xFFCBD5E1),
    );

    final textTheme = AppTypography.createTextTheme(
      lightTextPrimary,
      lightTextSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: lightSurface,
        foregroundColor: lightTextPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFeatures: AppTypography.fontFeatures,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: lightBorder, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        isDense: true,
        constraints: const BoxConstraints(minHeight: AppControlSize.standard),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w600,
          fontFeatures: AppTypography.fontFeatures,
        ),
        labelStyle: const TextStyle(
          color: lightTextSecondary,
          fontFeatures: AppTypography.fontFeatures,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontFeatures: AppTypography.fontFeatures,
        ),
        errorStyle: const TextStyle(
          color: errorColor,
          fontSize: 12,
          fontFeatures: AppTypography.fontFeatures,
        ),
        helperStyle: const TextStyle(
          color: lightTextSecondary,
          fontSize: 12,
          fontFeatures: AppTypography.fontFeatures,
        ),
        prefixIconColor: lightTextSecondary,
        suffixIconColor: lightTextSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          minimumSize: const Size(88, AppButtonSize.heightMd),
          padding: AppButtonSize.paddingMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTypography.button(),
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          disabledForegroundColor: const Color(0xFF94A3B8),
          side: const BorderSide(color: primaryColor, width: 1.2),
          minimumSize: const Size(88, AppButtonSize.heightMd),
          padding: AppButtonSize.paddingMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTypography.button(),
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          disabledForegroundColor: const Color(0xFF94A3B8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button(),
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          minimumSize: const Size(88, AppButtonSize.heightMd),
          padding: AppButtonSize.paddingMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTypography.button(),
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: lightTextPrimary,
          disabledForegroundColor: const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.all(8),
        ).copyWith(mouseCursor: AppCursors.interactive),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFFE2E8F0);
          }
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        mouseCursor: AppCursors.interactive,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFFCBD5E1);
          }
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return const Color(0xFF94A3B8);
        }),
        mouseCursor: AppCursors.interactive,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFFCBD5E1);
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFFE2E8F0);
          }
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return const Color(0xFFE2E8F0);
        }),
        mouseCursor: AppCursors.interactive,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        side: const BorderSide(color: lightBorder),
        backgroundColor: lightSurface,
        labelStyle: const TextStyle(
          color: lightTextPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFeatures: AppTypography.fontFeatures,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: lightBorder,
        indicatorColor: primaryColor,
        labelColor: primaryColor,
        unselectedLabelColor: lightTextSecondary,
        labelStyle: AppTypography.tab(),
        unselectedLabelStyle: AppTypography.tab(fontWeight: FontWeight.w500),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return primaryColor.withAlpha(15);
          }
          if (states.contains(WidgetState.pressed)) {
            return primaryColor.withAlpha(25);
          }
          return null;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: AppCursors.interactive,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: lightBorder, width: 1),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryColor;
            }
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFFF1F5F9);
            }
            return lightSurface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return lightTextSecondary;
          }),
          textStyle: WidgetStatePropertyAll(AppTypography.button(fontSize: 13)),
          minimumSize: const WidgetStatePropertyAll(
            Size.fromHeight(AppControlSize.standard),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          side: const BorderSide(color: lightBorder),
        ),
        titleTextStyle: const TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFeatures: AppTypography.fontFeatures,
        ),
        contentTextStyle: const TextStyle(
          color: lightTextSecondary,
          fontSize: 14,
          fontFeatures: AppTypography.fontFeatures,
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryColor,
        selectionColor: Color(0xFFBFDBFE),
        selectionHandleColor: primaryColor,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        hoverElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        mouseCursor: AppCursors.interactive,
      ),
      listTileTheme: const ListTileThemeData(
        mouseCursor: WidgetStatePropertyAll(SystemMouseCursors.click),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 2,
        color: lightSurface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: lightBorder),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          elevation: const WidgetStatePropertyAll(2),
          backgroundColor: const WidgetStatePropertyAll(lightSurface),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              side: const BorderSide(color: lightBorder),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: lightSurface,
        elevation: 1,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: lightSurface,
        elevation: 1,
        selectedIconTheme: IconThemeData(color: primaryColor),
        selectedLabelTextStyle: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w600,
          fontFeatures: AppTypography.fontFeatures,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: lightTextSecondary,
          fontFeatures: AppTypography.fontFeatures,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: lightTextPrimary,
          fontSize: 13,
          fontFeatures: AppTypography.fontFeatures,
        ),
        dataTextStyle: const TextStyle(
          color: lightTextPrimary,
          fontSize: 13,
          fontFeatures: AppTypography.fontFeatures,
        ),
        dataRowCursor: AppCursors.interactive,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: lightSurface,
        headerBackgroundColor: primaryColor,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: lightBorder),
        ),
        dayStyle: const TextStyle(fontFeatures: AppTypography.fontFeatures),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: primaryLight,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF1E3A8A),
      onPrimaryContainer: Color(0xFFDBEAFE),
      secondary: secondaryColor,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF134E4A),
      onSecondaryContainer: Color(0xFFCCFBF1),
      error: errorColor,
      onError: Colors.white,
      errorContainer: Color(0xFF991B1B),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: Color(0xFF0F172A),
      outline: darkBorder,
      outlineVariant: Color(0xFF475569),
    );

    final textTheme = AppTypography.createTextTheme(
      darkTextPrimary,
      darkTextSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFeatures: AppTypography.fontFeatures,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: darkBorder, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        isDense: true,
        constraints: const BoxConstraints(minHeight: AppControlSize.standard),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: const TextStyle(
          color: primaryLight,
          fontWeight: FontWeight.w600,
          fontFeatures: AppTypography.fontFeatures,
        ),
        labelStyle: const TextStyle(
          color: darkTextSecondary,
          fontFeatures: AppTypography.fontFeatures,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontFeatures: AppTypography.fontFeatures,
        ),
        errorStyle: const TextStyle(
          color: errorColor,
          fontSize: 12,
          fontFeatures: AppTypography.fontFeatures,
        ),
        helperStyle: const TextStyle(
          color: darkTextSecondary,
          fontSize: 12,
          fontFeatures: AppTypography.fontFeatures,
        ),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF1E293B),
          disabledForegroundColor: const Color(0xFF64748B),
          minimumSize: const Size(88, AppButtonSize.heightMd),
          padding: AppButtonSize.paddingMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTypography.button(),
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          disabledForegroundColor: const Color(0xFF64748B),
          side: const BorderSide(color: primaryLight, width: 1.2),
          minimumSize: const Size(88, AppButtonSize.heightMd),
          padding: AppButtonSize.paddingMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTypography.button(),
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          disabledForegroundColor: const Color(0xFF64748B),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button(),
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF1E293B),
          disabledForegroundColor: const Color(0xFF64748B),
          minimumSize: const Size(88, AppButtonSize.heightMd),
          padding: AppButtonSize.paddingMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTypography.button(),
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.forbidden,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: darkTextPrimary,
          disabledForegroundColor: const Color(0xFF64748B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.all(8),
        ).copyWith(mouseCursor: AppCursors.interactive),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        side: const BorderSide(color: Color(0xFF64748B), width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF1E293B);
          }
          if (states.contains(WidgetState.selected)) {
            return primaryLight;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        mouseCursor: AppCursors.interactive,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF475569);
          }
          if (states.contains(WidgetState.selected)) {
            return primaryLight;
          }
          return const Color(0xFF64748B);
        }),
        mouseCursor: AppCursors.interactive,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF475569);
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFF64748B);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF1E293B);
          }
          if (states.contains(WidgetState.selected)) {
            return primaryLight;
          }
          return const Color(0xFF1E293B);
        }),
        mouseCursor: AppCursors.interactive,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        side: const BorderSide(color: darkBorder),
        backgroundColor: darkSurface,
        labelStyle: const TextStyle(
          color: darkTextPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFeatures: AppTypography.fontFeatures,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: darkBorder,
        indicatorColor: primaryLight,
        labelColor: primaryLight,
        unselectedLabelColor: darkTextSecondary,
        labelStyle: AppTypography.tab(),
        unselectedLabelStyle: AppTypography.tab(fontWeight: FontWeight.w500),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return primaryLight.withAlpha(20);
          }
          if (states.contains(WidgetState.pressed)) {
            return primaryLight.withAlpha(35);
          }
          return null;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: AppCursors.interactive,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: darkBorder, width: 1),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryLight;
            }
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFF1E293B);
            }
            return darkSurface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return darkTextSecondary;
          }),
          textStyle: WidgetStatePropertyAll(AppTypography.button(fontSize: 13)),
          minimumSize: const WidgetStatePropertyAll(
            Size.fromHeight(AppControlSize.standard),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          side: const BorderSide(color: darkBorder),
        ),
        titleTextStyle: const TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFeatures: AppTypography.fontFeatures,
        ),
        contentTextStyle: const TextStyle(
          color: darkTextSecondary,
          fontSize: 14,
          fontFeatures: AppTypography.fontFeatures,
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryLight,
        selectionColor: Color(0xFF1E3A8A),
        selectionHandleColor: primaryLight,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 2,
        hoverElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        mouseCursor: AppCursors.interactive,
      ),
      listTileTheme: const ListTileThemeData(
        mouseCursor: WidgetStatePropertyAll(SystemMouseCursors.click),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 2,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: darkBorder),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          elevation: const WidgetStatePropertyAll(2),
          backgroundColor: const WidgetStatePropertyAll(darkSurface),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              side: const BorderSide(color: darkBorder),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkSurface,
        elevation: 1,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: darkSurface,
        elevation: 1,
        selectedIconTheme: IconThemeData(color: primaryLight),
        selectedLabelTextStyle: TextStyle(
          color: primaryLight,
          fontWeight: FontWeight.w600,
          fontFeatures: AppTypography.fontFeatures,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: darkTextSecondary,
          fontFeatures: AppTypography.fontFeatures,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF273549)),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
          fontSize: 13,
          fontFeatures: AppTypography.fontFeatures,
        ),
        dataTextStyle: const TextStyle(
          color: darkTextPrimary,
          fontSize: 13,
          fontFeatures: AppTypography.fontFeatures,
        ),
        dataRowCursor: AppCursors.interactive,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: darkSurface,
        headerBackgroundColor: primaryDark,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: darkBorder),
        ),
        dayStyle: const TextStyle(fontFeatures: AppTypography.fontFeatures),
      ),
    );
  }
}
