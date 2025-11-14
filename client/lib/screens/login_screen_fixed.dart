import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart' show UserRole;
import '../services/logger_service.dart';
import '../services/connection_service.dart';
import '../services/wifi_service.dart';

class LoginScreenFixed extends StatefulWidget {
  const LoginScreenFixed({Key? key}) : super(key: key);

  @override
  _LoginScreenFixedState createState() => _LoginScreenFixedState();
}

class _LoginScreenFixedState extends State<LoginScreenFixed> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLogin = true; // Toggle between login and signup
  UserRole _selectedRole = UserRole.student;

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        bool success;
        
        if (_isLogin) {
          // Login: userId + password
          success = await authProvider.signIn(
            userId: _userIdController.text.trim(),
            email: _userIdController.text.trim(),
            password: _passwordController.text,
          );
        } else {
          // Signup: userId + name + password + role
          success = await authProvider.signUp(
            userId: _userIdController.text.trim(),
            name: _nameController.text.trim(),
            email: _userIdController.text.trim(),
            password: _passwordController.text,
            role: _selectedRole,
          );
        }
        
        if (!mounted) return;
        
        if (success) {
          // Immediately navigate to Home and start network connection in background.
          final roleStr = _selectedRole == UserRole.faculty ? 'faculty' : 'student';
          final displayName = _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : _userIdController.text.trim();

          // Start connection in background (do not await so UI navigation is instant)
          Future(() async {
            try {
              final wifiOk = await WiFiService.instance.ensureConnectedToCampusNet();
              if (wifiOk) {
                await ConnectionService.instance.init(
                  userId: _userIdController.text.trim(),
                  name: displayName,
                  role: roleStr,
                );
              } else {
                // Still attempt discovery/connect even if automatic Wi-Fi connect failed
                await ConnectionService.instance.init(
                  userId: _userIdController.text.trim(),
                  name: displayName,
                  role: roleStr,
                ).catchError((e) {
                  Log.error('Background ConnectionService.init failed', e);
                });
              }
            } catch (e) {
              Log.error('Background Wi-Fi/connect error', e);
            }
          });

          if (mounted) Navigator.pushReplacementNamed(context, '/home');
        
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.error ?? 'Authentication failed'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        Log.error('Auth error', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('An error occurred. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _toggleLogin() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  _isLogin ? 'Welcome Back!' : 'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin 
                      ? 'Sign in to continue' 
                      : 'Create a new account to get started',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // User ID / Student ID / Faculty ID
                TextFormField(
                  controller: _userIdController,
                  decoration: InputDecoration(
                    labelText: _selectedRole == UserRole.student ? 'Student ID' : 'Faculty ID',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _selectedRole == UserRole.student 
                          ? 'Please enter your Student ID' 
                          : 'Please enter your Faculty ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Name field (only for signup)
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Role selector (only for signup)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<UserRole>(
                      isExpanded: true,
                      value: _selectedRole,
                      underline: const SizedBox(),
                      onChanged: (UserRole? value) {
                        if (value != null) {
                          setState(() {
                            _selectedRole = value;
                          });
                        }
                      },
                      items: [
                        const DropdownMenuItem<UserRole>(
                          value: UserRole.student,
                          child: Text('Student'),
                        ),
                        const DropdownMenuItem<UserRole>(
                          value: UserRole.faculty,
                          child: Text('Faculty'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Confirm Password field (only for signup)
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 24),
                
                // Submit button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isLogin ? 'Sign In' : 'Create Account'),
                ),
                const SizedBox(height: 16),
                
                // Toggle button
                TextButton(
                  onPressed: _isLoading ? null : _toggleLogin,
                  child: Text(_isLogin
                      ? 'Don\'t have an account? Sign Up'
                      : 'Already have an account? Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
