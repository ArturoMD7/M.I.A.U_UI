import 'package:flutter/material.dart';

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

final TextStyle subtitleStyle = TextStyle(
  fontSize: 18,
  color: textColor,
);

final TextStyle buttonTextStyle = TextStyle(
  fontSize: 18,
  color: Colors.white,
);

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
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
              Text(
                "M.I.A.U",
                style: titleStyle,
              ),
              SizedBox(height: 10),
              Text(
                "Iniciar sesión",
                style: subtitleStyle,
              ),
              SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: "Correo electrónico / Número de teléfono",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
                ),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/lost-pets');
                },
                child: Text(
                  "Iniciar Sesión",
                  style: buttonTextStyle,
                ),
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
                      "regístrate",
                      style: TextStyle(color: accentColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}