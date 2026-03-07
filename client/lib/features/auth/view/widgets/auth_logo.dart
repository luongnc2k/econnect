import 'package:flutter/material.dart';

/// Logo responsive theo chiều cao màn hình.
class AuthLogo extends StatelessWidget {
  final double heightFraction;
  final double minHeight;
  final double maxHeight;

  const AuthLogo({
    super.key,
    this.heightFraction = 0.22,
    this.minHeight = 120,
    this.maxHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.of(context).size.height * heightFraction)
        .clamp(minHeight, maxHeight);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset('assets/images/logo.png', height: size),
    );
  }
}
