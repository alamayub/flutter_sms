import 'package:flutter/material.dart';

import 'typo_config.dart';

@immutable
class ColorConstants {
  static const fontFamily = 'Poppins';
  static const primary = Color(0xFF373cd7);
  static const textColor = Color(0xFF35485d);
  static const scafoldBG = Color(0xFFF5F5F5);
  const ColorConstants._();
}

@immutable
class Themes {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actionsIconTheme: IconThemeData(color: ColorConstants.primary),
      iconTheme: IconThemeData(size: 20, color: ColorConstants.textColor),
      titleTextStyle: typoConfig.textStyle.largeCaptionLabel2Bold.copyWith(
        color: ColorConstants.textColor,
        height: 1,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: ColorConstants.primary,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
    ),
    bottomAppBarTheme: const BottomAppBarTheme(
      height: 64,
      color: Colors.white,
      padding: EdgeInsets.zero,
    ),
    colorScheme: ColorScheme.fromSeed(seedColor: ColorConstants.primary),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      border: _inputBorder(Colors.transparent),
      focusedBorder: _inputBorder(ColorConstants.primary),
      errorBorder: _inputBorder(Colors.red),
      focusedErrorBorder: _inputBorder(Colors.red.shade500),
      enabledBorder: _inputBorder(ColorConstants.textColor),
      disabledBorder: _inputBorder(Colors.grey),
      labelStyle: typoConfig.textStyle.largeCaptionLabel3Regular.copyWith(
        color: ColorConstants.textColor.withAlpha(100),
      ),
      hintStyle: typoConfig.textStyle.largeCaptionLabel3Regular.copyWith(
        color: ColorConstants.textColor.withAlpha(100),
      ),
      prefixIconColor: ColorConstants.textColor,
      suffixIconColor: ColorConstants.textColor,
      contentPadding: EdgeInsets.all(12.0),
      errorStyle: TextStyle(height: 1, fontSize: 0),
    ),
    tabBarTheme: TabBarTheme(
      dividerHeight: 0,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(width: 1.5, color: ColorConstants.primary),
      ),
      labelColor: ColorConstants.primary,
      labelStyle: typoConfig.textStyle.smallCaptionLabelMedium.copyWith(
        color: ColorConstants.primary,
      ),
      unselectedLabelColor: ColorConstants.textColor,
      unselectedLabelStyle: typoConfig.textStyle.smallCaptionLabelsmall
          .copyWith(color: ColorConstants.textColor),
    ),
    dataTableTheme: DataTableThemeData(
      dataRowMinHeight: 24.0,
      dataRowMaxHeight: 30.0,
      headingRowHeight: 32.0,
      dividerThickness: 0.75,
      headingTextStyle: typoConfig.textStyle.smallSmall.copyWith(
        height: 1,
        fontWeight: FontWeight.w600,
        color: ColorConstants.textColor,
      ),
      dataTextStyle: typoConfig.textStyle.smallSmall.copyWith(
        color: ColorConstants.textColor,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 0.75,
          color: ColorConstants.textColor.withValues(alpha: .25),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: EdgeInsets.all(12.0),
        fixedSize: Size(double.infinity, 26),
        backgroundColor: ColorConstants.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        textStyle: typoConfig.textStyle.smallCaptionSubtitle2.copyWith(
          color: Colors.white,
        ),
        iconColor: Colors.white,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: TextButton.styleFrom(
        side: BorderSide(width: .5, color: ColorConstants.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: typoConfig.textStyle.smallCaptionSubtitle1.copyWith(
          height: 1,
          color: ColorConstants.primary,
        ),
        iconSize: 18,
      ),
    ),
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
  const Themes._();
}

TextStyle textDecorationTextStyle(
  Color color, {
  FontWeight fontWeight = FontWeight.w400,
  double fontSize = 12,
}) => TextStyle(
  color: color,
  letterSpacing: .5,
  fontSize: fontSize,
  fontWeight: fontWeight,
);

OutlineInputBorder _inputBorder(Color color) =>
    OutlineInputBorder(borderSide: BorderSide(width: .5, color: color));
