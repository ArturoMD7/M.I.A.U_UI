import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';

const Color primaryColor = Color(0xFFD68F5E);
const Color textColor = Colors.black;
const Color accentColor = Colors.blue;

final TextStyle titleStyle = const TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.bold,
  color: textColor,
);

final TextStyle subtitleStyle = const TextStyle(fontSize: 18, color: textColor);
final TextStyle buttonTextStyle = const TextStyle(
  fontSize: 18,
  color: Colors.white,
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  String get loginUrl => '${apiService.baseUrl}/users/login/';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final result = await apiService.post(
        '/users/login/',
        body: {
          'email': emailController.text.trim(),
          'password': passwordController.text,
        },
        requiresAuth: false,
      );

      setState(() {
        isLoading = false;
      });

      if (result.success && result.data != null) {
        final accessToken = result.data!['access']?.toString() ?? '';
        final refreshToken = result.data!['refresh']?.toString() ?? '';
        final userData = result.data!['user'] as Map<String, dynamic>?;

        if (mounted) {
          await context.read<AuthProvider>().login(
                accessToken,
                refreshToken,
                userData,
              );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${result.message}')));
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: size.width * 0.4,
                      height: size.width * 0.4,
                      constraints: const BoxConstraints(
                        maxWidth: 200,
                        maxHeight: 200,
                      ),
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/logomiau.png',
                          width: size.width * 0.28,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),
                  Text(
                    "M.I.A.U",
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Iniciar sesión",
                    style: subtitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: size.height * 0.04),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Correo electrónico",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Ingresa tu correo electrónico";
                      }
                      if (!value.contains('@')) {
                        return "Ingresa un correo válido";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Contraseña",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Ingresa tu contraseña";
                      }
                      return null;
                    },
                  ),
                  // Align(
                  //   alignment: Alignment.centerRight,
                  //   child: TextButton(
                  //     onPressed: () {
                  //       Navigator.pushNamed(context, '/recovery-password');
                  //     },
                  //     child: const Text(
                  //       "¿Olvidaste tu contraseña?",
                  //       style: TextStyle(color: accentColor),
                  //     ),
                  //   ),
                  // ),
                  SizedBox(height: size.height * 0.02),
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: loginUser,
                          child: Text("Iniciar Sesión", style: buttonTextStyle),
                        ),
                  SizedBox(height: size.height * 0.02),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("¿No tienes cuenta?"),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          "Regístrate",
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}