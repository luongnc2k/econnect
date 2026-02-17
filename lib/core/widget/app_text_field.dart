import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;

  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;

  final int? maxLines;
  final int? minLines;

  final IconData? prefixIcon;
  final Widget? suffix;

  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxLines = obscureText ? 1 : maxLines;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: effectiveMaxLines,
      minLines: minLines,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}
