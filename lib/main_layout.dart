import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/home/view/home_screen.dart';
import 'features/tracking/view/global_map_screen.dart';
import 'features/chat/view/chat_screen.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/tracking/provider/tracking_provider.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const GlobalMapScreen(),
    const ChatScreen(),
  ];

  void _onTabChanged(int newIndex) {
    final authProvider = context.read<AuthProvider>();
    final trackingProvider = context.read<TrackingProvider>();

    // Handle leaving Map tab
    if (_previousIndex == 1 && newIndex != 1) {
      if (authProvider.user != null) {
        trackingProvider.setMapActive(authProvider.user!.uid, false);
        trackingProvider.stopActiveFriendLocationStream();
      }
    }

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabChanged,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }
}
