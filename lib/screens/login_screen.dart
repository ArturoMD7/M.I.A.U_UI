import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String loginUrl =
    "http://192.168.1.95:8000/api/users/login/"; // Ruta de login en el backend

// Colores principales
const Color primaryColor = Color(0xFFD68F5E); // Naranja similar al de la imagen
const Color backgroundColor = Colors.white;
const Color textColor = Colors.black;
const Color accentColor = Colors.blue;

// Estilos de texto
final TextStyle titleStyle = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.bold,
  color: textColor,
);

final TextStyle subtitleStyle = TextStyle(fontSize: 18, color: textColor);

final TextStyle buttonTextStyle = TextStyle(fontSize: 18, color: Colors.white);

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

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailController.text,
          'password': passwordController.text,
        }),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        // Si el login es exitoso, guarda el access token y el refresh token
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String accessToken = responseData['access'];
        final String refreshToken = responseData['refresh'];

        // Guardar los tokens en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Inicio de sesión exitoso')));
        Navigator.pushNamed(context, '/lost-pets');
      } else {
        // Si hay un error, muestra el mensaje de error
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/logomiau.png', // Ruta de la imagen
                      width: 140, // Ajusta el tamaño según necesites
                      height: 140,
                      fit: BoxFit.contain, // Para que la imagen no se recorte
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text("M.I.A.U", style: titleStyle),
                SizedBox(height: 10),
                Text("Iniciar sesión", style: subtitleStyle),
                SizedBox(height: 20),
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "Correo electrónico",
                    border: OutlineInputBorder(),
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
                SizedBox(height: 10),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Ingresa tu contraseña";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      "¿Olvidaste tu contraseña?",
                      style: TextStyle(color: accentColor),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 15,
                        ),
                      ),
                      onPressed: loginUser,
                      child: Text("Iniciar Sesión", style: buttonTextStyle),
                    ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("¿No tienes cuenta?"),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text(
                        "Regístrate",
                        style: TextStyle(color: accentColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
