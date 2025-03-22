import 'package:flutter/material.dart';

// Colores principales
const Color primaryColor = Color(
  0xFFD0894B,
); // Color marrón claro similar al de la imagen
const Color textColor = Colors.black;
const Color iconColor = Colors.black;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          100,
        ), // Aumentamos la altura de la barra para acomodar dos filas
        child: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          flexibleSpace: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Fila superior (Mensajes y Notificaciones)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.chat_bubble_outline, color: iconColor),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications_none, color: iconColor),
                    onPressed: () {},
                  ),
                  SizedBox(width: 10),
                ],
              ),
              // Fila inferior (Iconos principales centrados)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(Icons.pets, color: iconColor), // Perdidas
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.qr_code, color: iconColor), // QR
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.person, color: iconColor), // Usuario
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.article, color: iconColor), // Documentos
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.link, color: iconColor), // Enlace
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Text(
          "Pantalla principal",
          style: TextStyle(fontSize: 16, color: textColor),
        ),
      ),
    );
  }
}
