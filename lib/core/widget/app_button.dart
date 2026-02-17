import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant { primary, outline, text, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  /// Show loading indicator and disable button
  final bool loading;

  /// primary / outline / text / danger
  final AppButtonVariant variant;

  /// Optional icons
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  /// If true => width = infinity
  final bool fullWidth;

  /// Button height
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.fullWidth = true,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final cs = Theme.of(context).colorScheme;

    // Pick colors per variant
    final _ButtonPalette palette = _paletteForVariant(cs);

    // Build content
    final Widget content = _Content(
      label: label,
      loading: loading,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      spinnerColor: palette.spinnerColor,
      textColor: palette.contentColor,
      fullWidth: fullWidth,
    );

    // Build actual button based on variant
    switch (variant) {
      case AppButtonVariant.primary:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: ElevatedButton(
            onPressed: disabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.backgroundColor,
              foregroundColor: palette.contentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
              ),
            ),
            child: content,
          ),
        );

      case AppButtonVariant.danger:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: ElevatedButton(
            onPressed: disabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.backgroundColor,
              foregroundColor: palette.contentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
              ),
            ),
            child: content,
          ),
        );

      case AppButtonVariant.outline:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: OutlinedButton(
            onPressed: disabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.contentColor,
              side: BorderSide(color: palette.borderColor, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
              ),
            ),
            child: content,
          ),
        );

      case AppButtonVariant.text:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height - 4,
          child: TextButton(
            onPressed: disabled ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor: palette.contentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
              ),
            ),
            child: content,
          ),
        );
    }
  }

  _ButtonPalette _paletteForVariant(ColorScheme cs) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _ButtonPalette(
          backgroundColor: cs.primary,
          contentColor: Colors.white,
          borderColor: cs.primary,
          spinnerColor: Colors.white,
        );

      case AppButtonVariant.danger:
        return _ButtonPalette(
          backgroundColor: AppColors.error,
          contentColor: Colors.white,
          borderColor: AppColors.error,
          spinnerColor: Colors.white,
        );

      case AppButtonVariant.outline:
        return _ButtonPalette(
          backgroundColor: Colors.transparent,
          contentColor: cs.primary,
          borderColor: cs.primary,
          spinnerColor: cs.primary,
        );

      case AppButtonVariant.text:
        return _ButtonPalette(
          backgroundColor: Colors.transparent,
          contentColor: cs.primary,
          borderColor: cs.primary,
          spinnerColor: cs.primary,
        );
    }
  }
}

class _ButtonPalette {
  final Color backgroundColor;
  final Color contentColor;
  final Color borderColor;
  final Color spinnerColor;

  const _ButtonPalette({
    required this.backgroundColor,
    required this.contentColor,
    required this.borderColor,
    required this.spinnerColor,
  });
}

class _Content extends StatelessWidget {
  final String label;
  final bool loading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Color spinnerColor;
  final Color textColor;
  final bool fullWidth;

  const _Content({
    required this.label,
    required this.loading,
    required this.leadingIcon,
    required this.trailingIcon,
    required this.spinnerColor,
    required this.textColor,
    required this.fullWidth,
  });

  @override
  Widget build(BuildContext context) {
    final Widget spinner = SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
      ),
    );

    final TextStyle textStyle = TextStyle(
      color: textColor,
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Leading
        if (loading) ...[
          spinner,
          const SizedBox(width: AppSpacing.sm),
        ] else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 18, color: textColor),
          const SizedBox(width: AppSpacing.sm),
        ],

        // Label
        Flexible(
          child: Text(
            label,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Trailing
        if (!loading && trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: 18, color: textColor),
        ],
      ],
    );
  }
}
