/// Flat list row on the 60 px rhythm, with an optional hairline divider.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Icon + title + subtitle + trailing slot. One hairline between neighbours,
/// never around each row — sections are separated by `SectionLabel`.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.minHeight = 60,
    this.horizontalInset = 0,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final double minHeight;

  /// Padding between the row's edges and its content. The press highlight
  /// always fills the row, so a screen can keep its text column inset while
  /// the ink bleeds a little wider.
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final Widget row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: InkWell(
        onTap: onTap,
        // A soft radius, not the chip pill: enough to stop the highlight
        // reading as a rendering bug, small enough to stay a row.
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalInset,
            AppSpacing.md,
            horizontalInset,
            AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                // A wide trailing label (a date, a count) must give way to the
                // title rather than overflow the row at large text sizes.
                Flexible(child: trailing!),
              ],
            ],
          ),
        ),
      ),
    );

    if (!showDivider) {
      return row;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        row,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalInset),
          child: const Divider(height: 1),
        ),
      ],
    );
  }
}
