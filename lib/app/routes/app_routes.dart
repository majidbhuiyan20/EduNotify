import 'package:edunotify/app/auth/login_screen.dart';
import 'package:edunotify/app/auth/signup_screen.dart';
import 'package:edunotify/app/auth/wrapper.dart';
import 'package:edunotify/app/features/home_screen.dart';
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => WrapperScreen()),
    GoRoute(path: '/home_screen', builder: (context, state) => HomeScreen()),
    GoRoute(path: '/login', builder: (context, state) => LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => SignUpScreen()),



  ],
  );