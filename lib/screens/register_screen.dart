import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl =
    "http://192.168.1.64:8000/api/users/signup/"; // Asegúrate de que termine con /

// Colores principales
const Color primaryColor = Color(0xFFD4915D); // Naranja suave
const Color backgroundColor = Colors.white;
const Color textColor = Colors.black;
const Color accentColor = Colors.black;

// Estilos de texto
final TextStyle titleStyle = TextStyle(
  fontSize: 26,
  fontWeight: FontWeight.bold,
  color: textColor,
);
final TextStyle buttonTextStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
  color: Colors.white,
);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();

  bool isLoading = false;

  Future<void> createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': nameController.text,
          'first_name': firstNameController.text,
          'last_name': lastNameController.text,
          'age': int.parse(ageController.text), // Convertir a entero
          'email': emailController.text,
          'password': passwordController.text,
          'phone_number': phoneController.text,
          'address': addressController.text,
          'birth_date':
              birthDateController
                  .text, // Asegúrate de que esté en formato YYYY-MM-DD
        }),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Usuario registrado con éxito')));
        Navigator.pushNamed(context, '/lost-pets');
      } else {
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: 40),
                Text("Regístrate", style: titleStyle),
                SizedBox(height: 20),
                _buildTextField("Nombre*", nameController),
                _buildTextField("Primer nombre*", firstNameController),
                _buildTextField(
                  "Apellido",
                  lastNameController,
                  required: false,
                ),
                _buildTextField(
                  "Edad*",
                  ageController,
                  inputType: TextInputType.number,
                ),
                _buildTextField(
                  "Correo electrónico*",
                  emailController,
                  inputType: TextInputType.emailAddress,
                ),
                _buildTextField(
                  "Contraseña*",
                  passwordController,
                  obscureText: true,
                ),
                _buildTextField(
                  "Número de teléfono",
                  phoneController,
                  required: false,
                ),
                _buildTextField("Dirección*", addressController),
                _buildTextField(
                  "Fecha de nacimiento (YYYY-MM-DD)",
                  birthDateController,
                  required: false,
                  suffixIcon: Icons.calendar_today,
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
                      onPressed: createUser,
                      child: Text("Registrarme", style: buttonTextStyle),
                    ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
    IconData? suffixIcon,
    TextInputType inputType = TextInputType.text,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return "Campo obligatorio";
          }
          if (inputType == TextInputType.emailAddress &&
              !value!.contains('@')) {
            return "Ingresa un correo válido";
          }
          if (inputType == TextInputType.number &&
              int.tryParse(value!) == null) {
            return "Ingresa un número válido";
          }
          return null;
        },
      ),
    );
  }
}
