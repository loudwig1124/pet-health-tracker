/// Tracked-caps section label — the only divider a list needs.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Uppercase, letter-spaced label used above sections and between list groups.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(0, 20, 0, 8),
  });

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.sectionLabel,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
