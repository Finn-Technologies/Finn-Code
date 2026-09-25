import 'package:flutter/material.dart';

/// Material 3 shape tokens used by Finn Code's surfaces and controls.
abstract final class AppShape {
  static const double small = 8;
  static const double medium = 12;
  static const double control = 14;
  static const double large = 16;
  static const double surface = 16;
  static const double extraLarge = 22;
  static const double composer = 18;
  static const double pill = 999;

  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius mediumRadius = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeRadius = BorderRadius.all(
    Radius.circular(large),
  );
  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius surfaceRadius = BorderRadius.all(
    Radius.circular(surface),
  );
}
