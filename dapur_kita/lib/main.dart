import 'package:flutter/material.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/home_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/socket_service.dart';
import 'utils/app_colors.dart';

/// Kunci navigator global dipakai saat token kedaluwarsa agar bisa langsung
/// kembali ke halaman login dari mana pun error 401 terjadi.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Token expired / tidak valid -> hapus sesi dan kembali ke login.
  ApiService.onUnauthorized = () async {
    SocketService.disconnect();
    await AuthService().logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };

  // Inisialisasi membaca sesi autentikasi pengguna
  await AuthService().initialize();
  await SocketService.connect();

  runApp(const DapurKitaApp());
}

class DapurKitaApp extends StatelessWidget {
  const DapurKitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    // Penentuan rute awal berdasarkan sesi login & role
    Widget initialScreen;
    if (auth.isLoggedIn) {
      if (auth.isAdmin) {
        initialScreen = const AdminDashboardScreen();
      } else {
        initialScreen = const UserHomeScreen();
      }
    } else {
      initialScreen = const LoginScreen();
    }

    return MaterialApp(
      title: 'DapurKita',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.forestGreen,
          primary: AppColors.forestGreen,
          secondary: AppColors.mutedOrange,
          surface: AppColors.warmCream,
        ),
        scaffoldBackgroundColor: AppColors.warmCream,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.charcoal,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: initialScreen,
    );
  }
}
