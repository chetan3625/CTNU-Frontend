// lib/pages/auth_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _loginUsername = TextEditingController();
  final _loginPassword = TextEditingController();
  final _regUsername = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsername.dispose();
    _loginPassword.dispose();
    _regUsername.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_loginFormKey.currentState?.validate() ?? false) {
      await context.read<AuthProvider>().login(
        _loginUsername.text.trim(),
        _loginPassword.text,
      );
      if (context.read<AuthProvider>().isAuthenticated) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> _handleRegister() async {
    if (_registerFormKey.currentState?.validate() ?? false) {
      await context.read<AuthProvider>().register(
        _regUsername.text.trim(),
        _regEmail.text.trim(),
        _regPassword.text,
      );
      if (context.read<AuthProvider>().isAuthenticated) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chetanu'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Login'), Tab(text: 'Register')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Login Form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _loginFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _loginUsername,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: (v) => v == null || v.isEmpty ? 'Enter username' : null,
                  ),
                  TextFormField(
                    controller: _loginPassword,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _handleLogin, child: const Text('Login')),
                ],
              ),
            ),
          ),
          // Register Form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _registerFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _regUsername,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: (v) => v == null || v.isEmpty ? 'Enter username' : null,
                  ),
                  TextFormField(
                    controller: _regEmail,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
                  ),
                  TextFormField(
                    controller: _regPassword,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _handleRegister, child: const Text('Register')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
