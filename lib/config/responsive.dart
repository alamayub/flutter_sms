import 'package:flutter/material.dart';
import 'constants.dart';

enum DeviceScreenType { mobile, tablet, desktop }

class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppConstants.mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppConstants.mobileBreakpoint &&
        width < AppConstants.tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

  static DeviceScreenType getDeviceType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppConstants.mobileBreakpoint) {
      return DeviceScreenType.mobile;
    } else if (width < AppConstants.tabletBreakpoint) {
      return DeviceScreenType.tablet;
    } else {
      return DeviceScreenType.desktop;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= AppConstants.tabletBreakpoint) {
      return desktop;
    }

    if (width >= AppConstants.mobileBreakpoint) {
      return tablet ?? desktop;
    }

    return mobile;
  }
}

extension ResponsiveContext on BuildContext {
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);

  DeviceScreenType get screenType => Responsive.getDeviceType(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  T responsive<T>({required T mobile, T? tablet, required T desktop}) {
    if (isDesktop) return desktop;
    if (isTablet) return tablet ?? desktop;
    return mobile;
  }
}

class ResponsiveScaffoldWrapper extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;

  const ResponsiveScaffoldWrapper({
    super.key,
    required this.child,
    this.maxContentWidth = 1400.0,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxContentWidth),
      child: child,
    );
  }
}
