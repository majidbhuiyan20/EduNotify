import 'package:edunotify/app/app.dart';
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => MyApp()),
    GoRoute(path: '/home', builder: (context, state) => MyApp()),
    GoRoute(path: '/', builder: (context, state) => MyApp()),
    GoRoute(path: '/', builder: (context, state) => MyApp()),



  ],
  );