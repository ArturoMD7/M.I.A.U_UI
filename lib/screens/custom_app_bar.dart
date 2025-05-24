import 'package:flutter/material.dart';

// Colores principales
const Color primaryColor = Color(
  0xFFD0894B,
); // Color marrón claro similar al de la imagen
const Color iconColor = Colors.black;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  final Size preferredSize = Size.fromHeight(100);
  final List<Widget>? actions;
  final Widget? leading;

  CustomAppBar({super.key, this.actions, this.leading}); // Altura de la barra

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: primaryColor,
      actions: actions,
      leading: leading,
      elevation: 0,
      flexibleSpace: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, color: iconColor),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/messages',
                  ); // Navegar a mensajes
                },
              ),
              IconButton(
                icon: Icon(Icons.notifications_none, color: iconColor),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/notifications',
                  ); // Navegar a notificaciones
                },
              ),
              SizedBox(width: 10),
            ],
          ),
          // Fila inferior (Iconos principales centrados)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Image.asset(
                  'assets/icons/gatotriste.png', // Ruta de la imagen en assets
                  width: 30, // Ajusta el tamaño según necesites
                  height: 30,
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/lost-pets',
                  ); // Navegar a mascotas perdidas
                },
              ),
              IconButton(
                icon: Image.asset(
                  'assets/icons/gatofeliz.png', // Ruta de la imagen en assets
                  width: 30, // Ajusta el tamaño según necesites
                  height: 30,
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/adopt',
                  ); // Navegar a mascotas perdidas
                },
              ),
              IconButton(
                icon: Icon(Icons.qr_code, color: iconColor,), // QR

                onPressed: () {
                  Navigator.pushNamed(context, '/qr'); // Navegar a QR
                },
              ),
              IconButton(
                icon: Icon(Icons.person, color: iconColor), // Usuario
                onPressed: () {
                  Navigator.pushNamed(context, '/profile'); // Navegar a perfil
                },
              ),
              IconButton(
                icon: Icon(Icons.pets, color: iconColor), // Documentos
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/pet-id',
                  ); // Navegar a documentos
                },
              ),
              IconButton(
                icon: Icon(Icons.link, color: iconColor), // Enlace
                onPressed: () {
                  Navigator.pushNamed(context, '/support'); // Navegar a soporte
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
