import 'package:flutter/material.dart'
    show
        Alignment,
        BoxShadow,
        Color,
        FontWeight,
        GradientRotation,
        LinearGradient,
        MaterialColor,
        Offset,
        TextStyle;

import 'theme.dart' show ColorConstants;

abstract class TypoConfig {
  ColorTokens get color;
  TextStyleTokens get textStyle;
  ShadowTokens get shadow;
  GradientTokens get gradient;
  MaterialColorTokens get materialColor;
}

abstract class ColorTokens {
  Color get brandColoursSunshade;
  Color get brandColoursPersianRose;
  Color get brandColoursBlueberry;
  Color get brandColoursBlueberryLight;
  Color get neutralsWhite;
  Color get neutralsBGWhite;
  Color get neutralsNeutrals100;
  Color get neutralsNeutrals200;
  Color get neutralsNeutrals300;
  Color get neutralsNeutrals400;
  Color get neutralsNeutrals500;
  Color get neutralsNeutrals600;
  Color get neutralsNeutrals700;
  Color get neutralsNeutrals800;
  Color get neutralsNeutrals900;
  Color get alertsDanger;
  Color get alertsSuccess;
  Color get alertsWarning;
  Color get buttonPriButtonOutline;
  Color get subshadeSubshade50;
  Color get subshadeSubshade100;
  Color get subshadeSubshade200;
  Color get subshadeSubshade300;
  Color get subshadeSubshade400;
  Color get subshadeSubshade500;
  Color get subshadeSubshade600;
  Color get subshadeSubshade700;
  Color get subshadeSubshade800;
  Color get subshadeSubshade900;
  Color get blueberryAltBBAlt50;
  Color get blueberryAltBBAlt100;
  Color get blueberryAltBBAlt200;
  Color get blueberryAltBBAlt300;
  Color get blueberryAltBBAlt400;
  Color get blueberryAltBBAlt500;
  Color get blueberryAltBBAlt600;
  Color get blueberryAltBBAlt700;
  Color get blueberryAltBBAlt800;
  Color get blueberryAltBBAlt900;
  Color get blueberryLBlueberryL300;
  Color get blueberryLBlueberryL400;
  Color get blueberryLBlueberryL500;
  Color get blueberryLBlueberryL600;
  Color get blueberryLBlueberryL700;
  Color get blueberryLBlueberryL800;
  Color get pRosePRose200;
  Color get pRosePRose300;
  Color get pRosePRose400;
  Color get pRosePRose500;
  Color get pRosePRose600;
  Color get pRosePRose700;
  Color get pRosePRose800;
  Color get surfaceWhite;
  Color get surfaceBGWhite;
}

abstract class TextStyleTokens {
  TextStyle get buttonsButtonLarge;
  TextStyle get buttonsButtonMedium;
  TextStyle get buttonsButtonSmall;
  TextStyle get largeHeaderH1;
  TextStyle get largeHeaderH2;
  TextStyle get largeHeaderH3Bold;
  TextStyle get largeHeaderH3Regular;
  TextStyle get largeHeaderH4Bold;
  TextStyle get largeHeaderH4Regular;
  TextStyle get largeHeaderH5Bold;
  TextStyle get largeHeaderH5Regular;
  TextStyle get largeHeaderH6Bold;
  TextStyle get largeHeaderH6Regular;
  TextStyle get largeBodyBodyBold;
  TextStyle get largeBodyBodyRegular;
  TextStyle get largeCaptionLabel1Bold;
  TextStyle get largeCaptionLabel1Regular;
  TextStyle get largeCaptionLabel2Bold;
  TextStyle get largeCaptionLabel2Regular;
  TextStyle get largeCaptionLabel3Bold;
  TextStyle get largeCaptionLabel3Regular;
  TextStyle get smallHeaderHeadline1;
  TextStyle get smallHeaderHeadline2;
  TextStyle get smallHeaderHeadline3;
  TextStyle get smallHeaderHeadline4;
  TextStyle get smallHeaderHeadline5;
  TextStyle get smallHeaderHeadline6;
  TextStyle get smallBodyBodyText1;
  TextStyle get smallBodyBodyText2;
  TextStyle get smallCaptionCaption;
  TextStyle get smallCaptionLabelMedium;
  TextStyle get smallCaptionLabelsmall;
  TextStyle get smallCaptionSubtitle1;
  TextStyle get smallCaptionSubtitle2;
  TextStyle get smallSmall;
}

abstract class ShadowTokens {
  List<BoxShadow> get neoElevationsElevation1;
  List<BoxShadow> get neoElevationsElevation2;
  List<BoxShadow> get neoElevationsElevation3;
  List<BoxShadow> get neoElevationsElevation4;
  List<BoxShadow> get neoElevationsElevation5;
  List<BoxShadow> get neoElevationsElevation6;
  List<BoxShadow> get buttonsPriGlassButtonShadow;
  List<BoxShadow> get buttonsPriGlassButtonTextShadow;
  List<BoxShadow> get buttonsPriNeoButtonShadow;
}

abstract class GradientTokens {
  LinearGradient get neutralsElementWhite;
  LinearGradient get buttonPriButtonFill;
  LinearGradient get surfaceElementWhite;
}

abstract class MaterialColorTokens {
  MaterialColor get neutralsNeutrals;
  MaterialColor get subshadeSubshade;
  MaterialColor get blueberryAltBBAlt;
  MaterialColor get blueberryLBlueberryL;
  MaterialColor get pRosePRose;
}

class DefaultTypoConfig extends TypoConfig {
  @override
  ColorTokens get color => DefaultColorTokens();
  @override
  TextStyleTokens get textStyle => DefaultTextStyleTokens();
  @override
  ShadowTokens get shadow => DefaultShadowTokens();
  @override
  GradientTokens get gradient => DefaultGradientTokens();
  @override
  MaterialColorTokens get materialColor => DefaultMaterialColorTokens();
}

class DefaultColorTokens extends ColorTokens {
  @override
  Color get brandColoursSunshade => const Color(0xFFF4A71D);
  @override
  Color get brandColoursPersianRose => const Color(0xFFE539B5);
  @override
  Color get brandColoursBlueberry => const Color(0xFF3A3087);
  @override
  Color get brandColoursBlueberryLight => const Color(0xFF7364EC);
  @override
  Color get neutralsWhite => const Color(0xFFFFFFFF);
  @override
  Color get neutralsBGWhite => const Color(0xFFF7F7FB);
  @override
  Color get neutralsNeutrals100 => const Color(0xFFC5C7CB);
  @override
  Color get neutralsNeutrals200 => const Color(0xFFA9ACB2);
  @override
  Color get neutralsNeutrals300 => const Color(0xFF82868E);
  @override
  Color get neutralsNeutrals400 => const Color(0xFF696F79);
  @override
  Color get neutralsNeutrals500 => const Color(0xFF444B57);
  @override
  Color get neutralsNeutrals600 => const Color(0xFF3E444F);
  @override
  Color get neutralsNeutrals700 => const Color(0xFF30353E);
  @override
  Color get neutralsNeutrals800 => const Color(0xFF252930);
  @override
  Color get neutralsNeutrals900 => const Color(0xFF1D2025);
  @override
  Color get alertsDanger => const Color(0xFFFF7448);
  @override
  Color get alertsSuccess => const Color(0xFF5DDA5D);
  @override
  Color get alertsWarning => const Color(0xFFF4A71D);
  @override
  Color get buttonPriButtonOutline => const Color(0xFFFBDBA9);
  @override
  Color get subshadeSubshade50 => const Color(0xFFFEF6E8);
  @override
  Color get subshadeSubshade100 => const Color(0xFFFBE3B9);
  @override
  Color get subshadeSubshade200 => const Color(0xFFF9D697);
  @override
  Color get subshadeSubshade300 => const Color(0xFFF7C368);
  @override
  Color get subshadeSubshade400 => const Color(0xFFF5B84A);
  @override
  Color get subshadeSubshade500 => const Color(0xFFF3A61D);
  @override
  Color get subshadeSubshade600 => const Color(0xFFDD971A);
  @override
  Color get subshadeSubshade700 => const Color(0xFFAD7615);
  @override
  Color get subshadeSubshade800 => const Color(0xFF865B10);
  @override
  Color get subshadeSubshade900 => const Color(0xFF66460C);
  @override
  Color get blueberryAltBBAlt50 => const Color(0xFFF6F5FF);
  @override
  Color get blueberryAltBBAlt100 => const Color(0xFFD0CBFD);
  @override
  Color get blueberryAltBBAlt200 => const Color(0xFFAAA2F9);
  @override
  Color get blueberryAltBBAlt300 => const Color(0xFF8A7EF2);
  @override
  Color get blueberryAltBBAlt400 => const Color(0xFF6F61E9);
  @override
  Color get blueberryAltBBAlt500 => const Color(0xFF594BDD);
  @override
  Color get blueberryAltBBAlt600 => const Color(0xFF4839CD);
  @override
  Color get blueberryAltBBAlt700 => const Color(0xFF3A2CB8);
  @override
  Color get blueberryAltBBAlt800 => const Color(0xFF2F22A0);
  @override
  Color get blueberryAltBBAlt900 => const Color(0xFF261B87);
  @override
  Color get blueberryLBlueberryL300 => const Color(0xFFA197F2);
  @override
  Color get blueberryLBlueberryL400 => const Color(0xFF8F83F0);
  @override
  Color get blueberryLBlueberryL500 => const Color(0xFF7364EC);
  @override
  Color get blueberryLBlueberryL600 => const Color(0xFF695BD7);
  @override
  Color get blueberryLBlueberryL700 => const Color(0xFF5247A8);
  @override
  Color get blueberryLBlueberryL800 => const Color(0xFF3F3782);
  @override
  Color get pRosePRose200 => const Color(0xFFF3A4DD);
  @override
  Color get pRosePRose300 => const Color(0xFFEE7ACD);
  @override
  Color get pRosePRose400 => const Color(0xFFEA61C4);
  @override
  Color get pRosePRose500 => const Color(0xFFE539B5);
  @override
  Color get pRosePRose600 => const Color(0xFFD034A5);
  @override
  Color get pRosePRose700 => const Color(0xFFA32881);
  @override
  Color get pRosePRose800 => const Color(0xFF7E1F64);
  @override
  Color get surfaceWhite => const Color(0xFFFFFFFF);
  @override
  Color get surfaceBGWhite => const Color(0xFFF7F7FB);
}

class DefaultTextStyleTokens extends TextStyleTokens {
  @override
  TextStyle get buttonsButtonLarge => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 17.0,
    height: 0.0,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get buttonsButtonMedium => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 15.0,
    height: 0.0,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get buttonsButtonSmall => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 14.0,
    height: 0.0,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w600,
  );
  @override
  TextStyle get largeHeaderH1 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 34.0,
    height: 1.411764705882353,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w800,
  );
  @override
  TextStyle get largeHeaderH2 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 30.0,
    height: 1.4666666666666666,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeHeaderH3Bold => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 27.0,
    height: 1.4074074074074074,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeHeaderH3Regular => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 27.0,
    fontWeight: FontWeight.w500,
    height: 1.4074074074074074,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeHeaderH4Bold => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    height: 1.4166666666666667,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeHeaderH4Regular => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 24.0,
    fontWeight: FontWeight.w500,
    height: 1.4166666666666667,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeHeaderH5Bold => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 21.0,
    fontWeight: FontWeight.w700,
    height: 1.5238095238095237,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeHeaderH5Regular => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 21.0,
    fontWeight: FontWeight.w500,
    height: 1.5238095238095237,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeHeaderH6Bold => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 19.0,
    fontWeight: FontWeight.w700,
    height: 1.263157894736842,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeHeaderH6Regular => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 19.0,
    fontWeight: FontWeight.w500,
    height: 1.263157894736842,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeBodyBodyBold => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 17.0,
    height: 1.411764705882353,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeBodyBodyRegular => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 17.0,
    fontWeight: FontWeight.w400,
    height: 1.411764705882353,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeCaptionLabel1Bold => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 17.0,
    height: 1.2941176470588236,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeCaptionLabel1Regular => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 17.0,
    fontWeight: FontWeight.w400,
    height: 1.2941176470588236,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeCaptionLabel2Bold => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 15.0,
    height: 1.2,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w600,
  );
  @override
  TextStyle get largeCaptionLabel2Regular => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get largeCaptionLabel3Bold => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 13.0,
    height: 1.2307692307692308,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w600,
  );
  @override
  TextStyle get largeCaptionLabel3Regular => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    height: 1.2307692307692308,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallHeaderHeadline1 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 30.0,
    fontWeight: FontWeight.w700,
    height: 1.4666666666666666,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallHeaderHeadline2 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 27.0,
    fontWeight: FontWeight.w700,
    height: 1.4814814814814814,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallHeaderHeadline3 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    height: 1.5,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallHeaderHeadline4 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 21.0,
    fontWeight: FontWeight.w700,
    height: 1.5238095238095237,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallHeaderHeadline5 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 19.0,
    fontWeight: FontWeight.w700,
    height: 1.4736842105263157,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallHeaderHeadline6 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 17.0,
    fontWeight: FontWeight.w700,
    height: 1.411764705882353,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallBodyBodyText1 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    height: 1.4666666666666666,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallBodyBodyText2 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    height: 1.4666666666666666,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallCaptionCaption => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 15.0,
    height: 1.2,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w600,
  );
  @override
  TextStyle get smallCaptionLabelMedium => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 14.0,
    height: 1.1428571428571428,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w600,
  );
  @override
  TextStyle get smallCaptionLabelsmall => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 1.1428571428571428,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallCaptionSubtitle1 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 12.0,
    height: 0.0,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w600,
  );
  @override
  TextStyle get smallCaptionSubtitle2 => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    height: 0.0,
    letterSpacing: 0.3,
  );
  @override
  TextStyle get smallSmall => const TextStyle(
    fontFamily: ColorConstants.fontFamily,
    fontSize: 10.0,
    fontWeight: FontWeight.normal,
    height: 1.25,
    letterSpacing: 0.3,
  );
}

class DefaultShadowTokens extends ShadowTokens {
  @override
  List<BoxShadow> get neoElevationsElevation1 => const [
    BoxShadow(
      offset: Offset(2.0, 2.0),
      blurRadius: 2.0,
      spreadRadius: 0.0,
      color: Color(0xFFE7E7E7),
    ),
    BoxShadow(
      offset: Offset(0.0, 1.0),
      blurRadius: 1.0,
      spreadRadius: 0.0,
      color: Color(0x99E7E7E7),
    ),
    BoxShadow(
      offset: Offset(-2.0, -2.0),
      blurRadius: 2.0,
      spreadRadius: 0.0,
      color: Color(0xFFFFFFFF),
    ),
    BoxShadow(
      offset: Offset(0.0, -1.0),
      blurRadius: 1.0,
      spreadRadius: 0.0,
      color: Color(0x99FFFFFF),
    ),
  ];
  @override
  List<BoxShadow> get neoElevationsElevation2 => const [
    BoxShadow(
      offset: Offset(4.0, 4.0),
      blurRadius: 4.0,
      spreadRadius: 0.0,
      color: Color(0xFFE7E7E7),
    ),
    BoxShadow(
      offset: Offset(0.0, 2.0),
      blurRadius: 2.0,
      spreadRadius: 0.0,
      color: Color(0x99E7E7E7),
    ),
    BoxShadow(
      offset: Offset(-4.0, -4.0),
      blurRadius: 4.0,
      spreadRadius: 0.0,
      color: Color(0xFFFFFFFF),
    ),
    BoxShadow(
      offset: Offset(0.0, -2.0),
      blurRadius: 2.0,
      spreadRadius: 0.0,
      color: Color(0x99FFFFFF),
    ),
  ];
  @override
  List<BoxShadow> get neoElevationsElevation3 => const [
    BoxShadow(
      offset: Offset(6.0, 6.0),
      blurRadius: 6.0,
      spreadRadius: 0.0,
      color: Color(0xFFE7E7E7),
    ),
    BoxShadow(
      offset: Offset(0.0, 4.0),
      blurRadius: 4.0,
      spreadRadius: 0.0,
      color: Color(0x99E7E7E7),
    ),
    BoxShadow(
      offset: Offset(-6.0, -6.0),
      blurRadius: 6.0,
      spreadRadius: 0.0,
      color: Color(0xFFFFFFFF),
    ),
    BoxShadow(
      offset: Offset(0.0, -4.0),
      blurRadius: 4.0,
      spreadRadius: 0.0,
      color: Color(0x99FFFFFF),
    ),
  ];
  @override
  List<BoxShadow> get neoElevationsElevation4 => const [
    BoxShadow(
      offset: Offset(8.0, 8.0),
      blurRadius: 8.0,
      spreadRadius: 0.0,
      color: Color(0xFFE7E7E7),
    ),
    BoxShadow(
      offset: Offset(0.0, 6.0),
      blurRadius: 6.0,
      spreadRadius: 0.0,
      color: Color(0x99E7E7E7),
    ),
    BoxShadow(
      offset: Offset(-8.0, -8.0),
      blurRadius: 8.0,
      spreadRadius: 0.0,
      color: Color(0xFFFFFFFF),
    ),
    BoxShadow(
      offset: Offset(0.0, -6.0),
      blurRadius: 6.0,
      spreadRadius: 0.0,
      color: Color(0x99FFFFFF),
    ),
  ];
  @override
  List<BoxShadow> get neoElevationsElevation5 => const [
    BoxShadow(
      offset: Offset(12.0, 12.0),
      blurRadius: 12.0,
      spreadRadius: 0.0,
      color: Color(0xFFE7E7E7),
    ),
    BoxShadow(
      offset: Offset(0.0, 6.0),
      blurRadius: 6.0,
      spreadRadius: 0.0,
      color: Color(0x99E7E7E7),
    ),
    BoxShadow(
      offset: Offset(-12.0, -12.0),
      blurRadius: 12.0,
      spreadRadius: 0.0,
      color: Color(0xFFFFFFFF),
    ),
    BoxShadow(
      offset: Offset(0.0, -6.0),
      blurRadius: 6.0,
      spreadRadius: 0.0,
      color: Color(0x99FFFFFF),
    ),
  ];
  @override
  List<BoxShadow> get neoElevationsElevation6 => const [
    BoxShadow(
      offset: Offset(16.0, 16.0),
      blurRadius: 15.0,
      spreadRadius: 0.0,
      color: Color(0xFFE7E7E7),
    ),
    BoxShadow(
      offset: Offset(0.0, 8.0),
      blurRadius: 8.0,
      spreadRadius: 0.0,
      color: Color(0x99E7E7E7),
    ),
    BoxShadow(
      offset: Offset(-16.0, -16.0),
      blurRadius: 15.0,
      spreadRadius: 0.0,
      color: Color(0xFFFFFFFF),
    ),
    BoxShadow(
      offset: Offset(0.0, -8.0),
      blurRadius: 13.899999618530273,
      spreadRadius: 0.0,
      color: Color(0x99FFFFFF),
    ),
  ];

  @override
  List<BoxShadow> get buttonsPriGlassButtonShadow => const [
    BoxShadow(
      offset: Offset(0.0, 1.0),
      blurRadius: 1.0,
      spreadRadius: 0.0,
      color: Color(0x61FEA015),
    ),
    BoxShadow(
      offset: Offset(0.0, 3.0),
      blurRadius: 2.0,
      spreadRadius: 0.0,
      color: Color(0x52FEA015),
    ),
    BoxShadow(
      offset: Offset(0.0, 6.0),
      blurRadius: 3.0,
      spreadRadius: 0.0,
      color: Color(0x29FEA015),
    ),
    BoxShadow(
      offset: Offset(0.0, 10.0),
      blurRadius: 3.0,
      spreadRadius: 0.0,
      color: Color(0x17FEA015),
    ),
  ];
  @override
  List<BoxShadow> get buttonsPriGlassButtonTextShadow => const [
    BoxShadow(
      offset: Offset(0.0, 2.0),
      blurRadius: 12.0,
      spreadRadius: -5.0,
      color: Color(0x47000000),
    ),
  ];
  @override
  List<BoxShadow> get buttonsPriNeoButtonShadow => const [
    BoxShadow(
      offset: Offset(6.0, 6.0),
      blurRadius: 6.0,
      spreadRadius: 0.0,
      color: Color(0xFFDEDEDE),
    ),
    BoxShadow(
      offset: Offset(-6.0, -6.0),
      blurRadius: 6.0,
      spreadRadius: 0.0,
      color: Color(0xFFFFFFFF),
    ),
  ];
}

class DefaultGradientTokens extends GradientTokens {
  @override
  LinearGradient get neutralsElementWhite => const LinearGradient(
    colors: [Color(0xFFF7F7F8), Color(0xFFF4F4F6)],
    stops: [0.0001, 1.0],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    transform: GradientRotation(2.30),
  );
  @override
  LinearGradient get buttonPriButtonFill => const LinearGradient(
    colors: [Color(0xCCF6BC54), Color(0xFFF4A71D)],
    stops: [0.0, 1.0],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    transform: GradientRotation(4.71),
  );
  @override
  LinearGradient get surfaceElementWhite => const LinearGradient(
    colors: [Color(0xFFF7F7F8), Color(0xFFF4F4F6)],
    stops: [0.0001, 1.0],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    transform: GradientRotation(2.30),
  );
}

class DefaultMaterialColorTokens extends MaterialColorTokens {
  @override
  MaterialColor get neutralsNeutrals => const MaterialColor(0xFF444B57, {
    100: Color(0xFFC5C7CB),
    200: Color(0xFFA9ACB2),
    300: Color(0xFF82868E),
    400: Color(0xFF696F79),
    500: Color(0xFF444B57),
    600: Color(0xFF3E444F),
    700: Color(0xFF30353E),
    800: Color(0xFF252930),
    900: Color(0xFF1D2025),
  });

  @override
  MaterialColor get subshadeSubshade => const MaterialColor(0xFFF3A61D, {
    50: Color(0xFFFEF6E8),
    100: Color(0xFFFBE3B9),
    200: Color(0xFFF9D697),
    300: Color(0xFFF7C368),
    400: Color(0xFFF5B84A),
    500: Color(0xFFF3A61D),
    600: Color(0xFFDD971A),
    700: Color(0xFFAD7615),
    800: Color(0xFF865B10),
    900: Color(0xFF66460C),
  });

  @override
  MaterialColor get blueberryAltBBAlt => const MaterialColor(0xFF594BDD, {
    50: Color(0xFFF6F5FF),
    100: Color(0xFFD0CBFD),
    200: Color(0xFFAAA2F9),
    300: Color(0xFF8A7EF2),
    400: Color(0xFF6F61E9),
    500: Color(0xFF594BDD),
    600: Color(0xFF4839CD),
    700: Color(0xFF3A2CB8),
    800: Color(0xFF2F22A0),
    900: Color(0xFF261B87),
  });

  @override
  MaterialColor get blueberryLBlueberryL => const MaterialColor(0xFF7364EC, {
    300: Color(0xFFA197F2),
    400: Color(0xFF8F83F0),
    500: Color(0xFF7364EC),
    600: Color(0xFF695BD7),
    700: Color(0xFF5247A8),
    800: Color(0xFF3F3782),
  });

  @override
  MaterialColor get pRosePRose => const MaterialColor(0xFFE539B5, {
    200: Color(0xFFF3A4DD),
    300: Color(0xFFEE7ACD),
    400: Color(0xFFEA61C4),
    500: Color(0xFFE539B5),
    600: Color(0xFFD034A5),
    700: Color(0xFFA32881),
    800: Color(0xFF7E1F64),
  });
}

final typoConfig = DefaultTypoConfig();
