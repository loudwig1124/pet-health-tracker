/// Stored photos come from the filesystem.
library;

import 'dart:io';

import 'package:flutter/material.dart';

Widget photoImage(
  String path, {
  required BoxFit fit,
  double? width,
  double? height,
  ImageErrorWidgetBuilder? errorBuilder,
}) => Image.file(
  File(path),
  fit: fit,
  width: width,
  height: height,
  errorBuilder: errorBuilder,
);
