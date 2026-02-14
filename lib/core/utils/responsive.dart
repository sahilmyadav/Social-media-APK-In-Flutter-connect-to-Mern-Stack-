import 'package:flutter/material.dart';

/// Lightweight responsive utility for scaling UI elements
/// relative to a design base of 375×812 (iPhone standard).
///
/// Usage:
///   Responsive.init(context);  // Call once in MyApp.build()
///   Text('Hello', style: TextStyle(fontSize: Responsive.sp(16)));
///   SizedBox(width: Responsive.w(24));
///   SizedBox(height: Responsive.h(40));
///   BorderRadius.circular(Responsive.r(12));
class Responsive {
  static late double _screenWidth;
  static late double _screenHeight;
  static bool _initialized = false;

  // Design base dimensions (standard iPhone)
  static const double _designWidth = 375.0;
  static const double _designHeight = 812.0;

  /// Must be called once in the root widget's build method.
  static void init(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _screenWidth = size.width;
    _screenHeight = size.height;
    _initialized = true;
  }

  static double get _scaleW {
    assert(_initialized, 'Responsive.init(context) must be called first');
    return _screenWidth / _designWidth;
  }

  static double get _scaleH {
    assert(_initialized, 'Responsive.init(context) must be called first');
    return _screenHeight / _designHeight;
  }

  /// Scale for font sizes (based on width)
  static double sp(double size) => size * _scaleW;

  /// Scale for widths/horizontal dimensions
  static double w(double size) => size * _scaleW;

  /// Scale for heights/vertical dimensions
  static double h(double size) => size * _scaleH;

  /// Scale for border radius (based on width)
  static double r(double size) => size * _scaleW;

  /// Responsive horizontal padding
  static EdgeInsets padH(double val) =>
      EdgeInsets.symmetric(horizontal: w(val));

  /// Responsive vertical padding
  static EdgeInsets padV(double val) => EdgeInsets.symmetric(vertical: h(val));

  /// Responsive all-side padding
  static EdgeInsets padAll(double val) => EdgeInsets.all(w(val));

  /// Responsive symmetric padding
  static EdgeInsets padSymmetric(
          {double horizontal = 0, double vertical = 0}) =>
      EdgeInsets.symmetric(horizontal: w(horizontal), vertical: h(vertical));

  /// Current screen width
  static double get screenWidth => _screenWidth;

  /// Current screen height
  static double get screenHeight => _screenHeight;
}
