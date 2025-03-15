import 'package:flutter/material.dart';

// Colores principales
const Color primaryColor = Color(0xFFD4915D); // Naranja suave de la imagen
const Color backgroundColor = Colors.white;
const Color textColor = Colors.black;
const Color accentColor = Colors.black; // Para los textos de enlaces

// Estilos de texto
final TextStyle titleStyle = TextStyle(
  fontSize: 26,
  fontWeight: FontWeight.bold,
  color: textColor,
);

final TextStyle subtitleStyle = TextStyle(
  fontSize: 18,
  color: textColor,
);

final TextStyle buttonTextStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
  color: Colors.white,
);

class RegisterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 40),
              Text("Regístrate", style: titleStyle),
              SizedBox(height: 20),
              _buildTextField("Nombre(s)*"),
              _buildTextField("Apellido(s)*"),
              _buildTextField("Fecha de nacimiento*", suffixIcon: Icons.calendar_today),
              _buildTextField("Número de teléfono"),
              _buildTextField("Dirección*"),
              _buildTextField("Correo electrónico*"),
              _buildTextField("Contraseña*", obscureText: true),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/home');
                },
                child: Text("Registrarme", style: buttonTextStyle),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {bool obscureText = false, IconData? suffixIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextField(
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
        ),
      ),
    );
  }
}