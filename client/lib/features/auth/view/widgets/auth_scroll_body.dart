import 'package:client/core/widgets/loader.dart';
import 'package:flutter/material.dart';

/// Bọc body của auth screen.
/// Top padding tính theo chiều cao màn hình để tránh khoảng trắng quá lớn.
class AuthScrollBody extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const AuthScrollBody({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Loader();
    final topPad = (MediaQuery.of(context).size.height * 0.06).clamp(24.0, 60.0);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, topPad, 24, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      ),
    );
  }
}
