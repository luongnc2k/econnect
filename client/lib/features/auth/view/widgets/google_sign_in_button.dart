import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onTap,
    this.label = 'Sign in with Google',
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        side: BorderSide(color: Theme.of(context).dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      icon: const Icon(Icons.g_mobiledata, size: 28),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
