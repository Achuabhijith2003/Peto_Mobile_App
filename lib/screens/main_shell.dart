import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/feed_video_manager.dart';
import '../theme/app_theme.dart';
import 'home/home_screen.dart';
import 'community/community_screen.dart';
import 'search/search_screen.dart';
import 'reels/reels_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();
  bool _hasCheckedHealth = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkServerHealth();
    });
  }

  Future<void> _checkServerHealth() async {
    if (_hasCheckedHealth) return;
    _hasCheckedHealth = true;

    final health = await _apiService.checkHealth();
    if (health['isHealthy'] != true && mounted) {
      _showHealthErrorDialog(health['message'] ?? 'API Server is currently unreachable.');
    }
  }

  void _showHealthErrorDialog(String message) {
    debugPrint('API health check error: $message');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 10),
            Text(
              'Connection Notice',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        content: const Text(
          "We couldn't connect to Peto right now. Please check your internet connection and try again.",
          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(color: AppColors.outline)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimaryContainer,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _hasCheckedHealth = false;
              _checkServerHealth();
            },
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          const CommunityScreen(),
          const SearchScreen(),
          ReelsScreen(isActive: _currentIndex == 3),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != 0) {
            FeedVideoManager().pauseAll();
          }
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Communities',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle_fill),
            label: 'Reels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
