import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends StatefulWidget {
  final Widget child;
  const MainScreen({super.key, required this.child});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int index = 0;
  final locations = ['/home', '/my-profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) {
          setState(() => index = i);
          context.go(locations[i]);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
