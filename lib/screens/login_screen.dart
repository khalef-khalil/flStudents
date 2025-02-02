import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'home_screen.dart';
import 'student_dashboard_screen.dart';
import 'package:lottie/lottie.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isProfessor = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    print('🔑 Starting login process...');
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('👤 Attempting login as ${_isProfessor ? "professor" : "student"}');
      print('📝 Username: ${_usernameController.text}');
      
      if (_isProfessor) {
        print('🎓 Authenticating professor...');
        final isAuthenticated = await DatabaseHelper.instance.authenticateProfessor(
          _usernameController.text,
          _passwordController.text,
        );

        print('🔐 Professor authentication result: $isAuthenticated');
        if (isAuthenticated && mounted) {
          print('✅ Professor login successful, navigating to home screen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          print('❌ Professor authentication failed');
          _showError('Identifiants invalides');
        }
      } else {
        print('👨‍🎓 Authenticating student...');
        final student = await DatabaseHelper.instance.authenticateStudent(
          _usernameController.text,
          _passwordController.text,
        );

        if (student != null && mounted) {
          print('✅ Student login successful, navigating to dashboard');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StudentDashboardScreen(student: student),
            ),
          );
        } else {
          print('❌ Student authentication failed');
          _showError('Identifiants invalides');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error during login: $e');
      print('📜 Stack trace: $stackTrace');
      _showError('Une erreur est survenue');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    print('⚠️ Showing error: $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 Building login screen');
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Replace Lottie animation with a static icon if animation fails
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.school,
                    size: 100,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Bienvenue',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Connectez-vous pour continuer',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Professeur'),
                              icon: Icon(Icons.school),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Étudiant'),
                              icon: Icon(Icons.person),
                            ),
                          ],
                          selected: {_isProfessor},
                          onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              _isProfessor = newSelection.first;
                              _usernameController.clear();
                              _passwordController.clear();
                            });
                          },
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Theme.of(context).colorScheme.primary;
                                }
                                return Colors.transparent;
                              },
                            ),
                            foregroundColor: MaterialStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.white;
                                }
                                return Theme.of(context).colorScheme.primary;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: _isProfessor ? 'Nom d\'utilisateur' : 'Numéro étudiant',
                            prefixIcon: Icon(
                              _isProfessor ? Icons.person : Icons.badge,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ce champ est requis';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: Icon(
                              Icons.lock,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey,
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
                              return 'Ce champ est requis';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Se connecter'),
                        ),
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
} 