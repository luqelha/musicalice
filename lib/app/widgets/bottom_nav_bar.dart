import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:musicalice/core/services/spotify_auth_service.dart';
import 'package:musicalice/features/home/presentation/pages/home_page.dart';
import 'package:musicalice/features/search/presentation/pages/search_page.dart';
import 'package:musicalice/features/library/presentation/pages/library_page.dart';
import 'package:musicalice/features/settings/presentation/pages/settings_page.dart';
import 'package:musicalice/app/widgets/mini_player.dart';

class BottomNavBar extends StatefulWidget {
  final SpotifyAuthService authService;

  const BottomNavBar({super.key, required this.authService});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(authService: widget.authService),
      SearchPage(authService: widget.authService),
      LibraryPage(authService: widget.authService),
      SettingsPage(authService: widget.authService),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Konten utama
          IndexedStack(index: _selectedIndex, children: _pages),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                ClipRRect(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, -2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: BottomNavigationBar(
                        type: BottomNavigationBarType.fixed,
                        backgroundColor: Colors.transparent,
                        selectedItemColor: Colors.white,
                        unselectedItemColor: Colors.grey[600],
                        currentIndex: _selectedIndex,
                        onTap: _onItemTapped,
                        selectedFontSize: 12,
                        unselectedFontSize: 12,
                        elevation: 0,
                        items: const [
                          BottomNavigationBarItem(
                            icon: Icon(Icons.home_outlined),
                            activeIcon: Icon(Icons.home),
                            label: 'Home',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(
                              Symbols.search,
                              weight: 400,
                              opticalSize: 24,
                            ),
                            activeIcon: Icon(
                              Symbols.search,
                              weight: 800,
                              opticalSize: 24,
                            ),
                            label: 'Search',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.library_music_outlined),
                            activeIcon: Icon(Icons.library_music),
                            label: 'Library',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.settings_outlined),
                            activeIcon: Icon(Icons.settings),
                            label: 'Settings',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
