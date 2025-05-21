import 'package:flutter/material.dart';
import '../../views/home_screen.dart';
import 'firebase_auth_service.dart';
import 'signup_view.dart';
import 'home_screen.dart'; // Ensure you have a home_screen.dart file or import your actual home screen widget.

class LogInView extends StatefulWidget {
  const LogInView({super.key});

  @override
  State<LogInView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LogInView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = FirebaseAuthService();

  void _login() async {
    final error = await _authService.signIn(
      _emailController.text,
      _passwordController.text,
    );
    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $error")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: "Email"),
          ),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: "Password"),
            obscureText: true,
          ),
          SizedBox(height: 16),
          ElevatedButton(onPressed: _login, child: Text("Login")),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SignUpView()),
            ),
            child: Text("Don't have an account? Sign Up"),
          ),
        ]),
      ),
    );
  }
}
