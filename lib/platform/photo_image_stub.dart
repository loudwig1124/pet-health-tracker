/// The web build stores no photo paths, so this is never painted.
library;

import 'package:flutter/material.dart';

Widget photoImage(
  String path, {
  required BoxFit fit,
  double? width,
  double? height,
  ImageErrorWidgetBuilder? errorBuilder,
}) => const SizedBox.shrink();
