// lib/pages/auth_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/error_handler.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  
  final _loginUsername = TextEditingController();
  final _loginPassword = TextEditingController();
  
  final _regUsername = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginUsername.dispose();
    _loginPassword.dispose();
    _regUsername.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_loginFormKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await context.read<AuthProvider>().login(
          _loginUsername.text.trim(),
          _loginPassword.text,
        );
        if (!mounted) return;
        if (context.read<AuthProvider>().isAuthenticated) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = error.toString().replaceFirst('Exception: ', '');
        });
        AppErrorHandler.showError(
          context,
          error,
          fallbackMessage: 'Login failed.',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleRegister() async {
    if (_registerFormKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await context.read<AuthProvider>().register(
          _regUsername.text.trim(),
          _regEmail.text.trim(),
          _regPassword.text,
        );
        if (!mounted) return;
        if (context.read<AuthProvider>().isAuthenticated) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = error.toString().replaceFirst('Exception: ', '');
        });
        AppErrorHandler.showError(
          context,
          error,
          fallbackMessage: 'Registration failed.',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Premium Visual Header / Logo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bubble_chart_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chetanu',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Seamless Real-time Conversations',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 32),

                // Responsive Card for login/register form
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Custom sliding segmented tab selector (No hardcoded heights required)
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (!_isLoading) {
                                      setState(() {
                                        _isLogin = true;
                                        _errorMessage = null;
                                      });
                                    }
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _isLogin ? theme.colorScheme.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Login',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isLogin ? Colors.white : Colors.white60,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (!_isLoading) {
                                      setState(() {
                                        _isLogin = false;
                                        _errorMessage = null;
                                      });
                                    }
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: !_isLogin ? theme.colorScheme.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Register',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: !_isLogin ? Colors.white : Colors.white60,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage != null)
                          AppErrorHandler.buildInlineError(
                            message: _errorMessage!,
                            onRetry: () {
                              if (_isLogin) {
                                _handleLogin();
                              } else {
                                _handleRegister();
                              }
                            },
                          ),
                        
                        // Dynamic rendering without enclosing constraints to support system font-scaling safely
                        _isLogin ? _buildLoginForm(theme) : _buildRegisterForm(theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _loginUsername,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Enter username' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPassword,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(ThemeData theme) {
    return Form(
      key: _registerFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _regUsername,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Enter username' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regEmail,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Enter email';
              }
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPassword,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (v) => v == null || v.length < 6 ? 'Password must be 6+ chars' : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Register'),
            ),
          ),
        ],
      ),
    );
  }
}
