import 'package:cliniccare/pages/auth_pages.dart';
import 'package:cliniccare/pages/dashboard_page.dart';
import 'package:cliniccare/pages/public_pages.dart';
import 'package:cliniccare/pages/records_page.dart';
import 'package:cliniccare/session.dart';
import 'package:cliniccare/url_strategy.dart';
import 'package:cliniccare/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  session.boot();
  runApp(const ClinicApp());
}

class ClinicApp extends StatefulWidget {
  const ClinicApp({super.key});

  @override
  State<ClinicApp> createState() => _ClinicAppState();
}

class _ClinicAppState extends State<ClinicApp> {
  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    errorBuilder: (context, state) => const NotFoundPage(),
    redirect: (context, state) {
      if (!session.ready) return null;
      final path = state.uri.path;
      final role = session.user?['role'];
      final loggedIn = session.user != null;
      if (path.startsWith('/dashboard')) {
        if (role == 'admin') return null;
        if (role == 'doctor' && (path == '/dashboard/accounts' || path == '/dashboard/appointments')) return null;
        if (role == 'doctor') return '/records';
        return '/login';
      }
      if (path == '/records' && role != 'admin' && role != 'doctor') return '/login';
      if ((path == '/profile' || path == '/results') && !loggedIn) return '/login';
      if (path == '/booking' && !loggedIn) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (path == '/login' && loggedIn) {
        if (role == 'admin') return '/dashboard/overview';
        if (role == 'doctor') return '/records';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => HomePage(section: state.uri.queryParameters['section'])),
      GoRoute(path: '/packages', builder: (context, state) => const PackagesPage()),
      GoRoute(
        path: '/booking',
        builder: (context, state) => BookingPage(
          packageId: state.uri.queryParameters['package'],
          doctorId: state.uri.queryParameters['doctor'],
        ),
      ),
      GoRoute(
        path: '/success',
        builder: (context, state) => SuccessPage(
          code: state.uri.queryParameters['code'] ?? '',
          phone: state.uri.queryParameters['phone'] ?? '',
        ),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => HistoryPage(
          code: state.uri.queryParameters['code'],
          phone: state.uri.queryParameters['phone'],
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(from: state.uri.queryParameters['from']),
      ),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPage()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPage(
          token: state.uri.queryParameters['token'] ?? '',
          email: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => VerifyPage(
          email: state.uri.queryParameters['email'] ?? '',
          code: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(
        path: '/dashboard',
        redirect: (context, state) => '/dashboard/overview',
      ),
      GoRoute(
        path: '/dashboard/:section',
        builder: (context, state) => DashboardPage(section: state.pathParameters['section'] ?? 'overview'),
      ),
      GoRoute(path: '/records', builder: (context, state) => const RecordsPage()),
      GoRoute(
        path: '/results',
        builder: (context, state) => ResultsPage(id: state.uri.queryParameters['id'] ?? ''),
      ),
      GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.beVietnamProTextTheme();
    return MaterialApp.router(
      title: 'ClinicCare',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal),
        textTheme: textTheme.apply(bodyColor: ink, displayColor: navy),
        dividerColor: line,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: tealDark,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
