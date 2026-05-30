import 'package:flutter/material.dart';

class CustomField extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final bool isObscureText;
  final String? requiredMessage;
  const CustomField({
    super.key,
    required this.hintText,
    required this.controller,
    this.isObscureText = false,
    this.requiredMessage,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(hintText: hintText),
      obscureText: isObscureText,
      validator: (val) {
        if (val!.trim().isEmpty) {
          return requiredMessage ?? "$hintText is missing!";
        }
        return null;
      },
    );
  }
}
