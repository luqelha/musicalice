import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'core/services/spotify_auth_service.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/splash_screen.dart';
import 'app/widgets/bottom_nav_bar.dart';
import 'app/providers/player_provider.dart';
import 'package:musicalice/app/widgets/no_glow_scroll_behavior.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlayerProvider(),
      child: MaterialApp(
        title: 'Musicalice',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const NoGlowScrollBehavior(),
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black,
          primaryColor: const Color(0xFF1DB954),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SpotifyAuthService _authService = SpotifyAuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  StreamSubscription? _linkSubscription;
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initAuth();
    _setupDeepLinkListener();
  }

  Future<void> _initAuth() async {
    final hasToken = await _authService.loadSavedTokens();
    setState(() {
      _isLoggedIn = hasToken;
      _isLoading = false;
    });
  }

  void _setupDeepLinkListener() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? uri) async {
        if (uri != null && uri.scheme == 'musicalice') {
          debugPrint('🔗 Received deep link: $uri');
          final success = await _authService.handleCallback(uri);
          if (success) {
            setState(() {
              _isLoggedIn = true;
            });
          } else {
            _showErrorDialog('Login failed. Please try again.');
          }
        }
      },
      onError: (err) {
        debugPrint('❌ Deep link error: $err');
        _showErrorDialog('An error occurred during login.');
      },
    );

    _appLinks.getInitialLink().then((uri) async {
      if (uri != null && uri.scheme == 'musicalice') {
        debugPrint('🔗 Initial deep link: $uri');
        final success = await _authService.handleCallback(uri);
        if (success) {
          setState(() {
            _isLoggedIn = true;
          });
        }
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    try {
      await _authService.login();
    } catch (e) {
      _showErrorDialog('Could not open Spotify login. Please try again.');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    if (!_isLoggedIn) {
      return LoginPage(onLogin: _handleLogin);
    }

    return BottomNavBar(authService: _authService);
  }
}
