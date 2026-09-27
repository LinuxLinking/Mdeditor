import 'package:flutter/animation.dart';

abstract final class AppSpacing {
  AppSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

abstract final class AppRadius {
  AppRadius._();
  static const double sm = 8;
}

abstract final class AppIconSize {
  AppIconSize._();
  static const double xs = 16;
  static const double hero = 56;
}

abstract final class AppMotion {
  AppMotion._();
  static const Curve standard = Cubic(0.4, 0, 0.2, 1);
}
