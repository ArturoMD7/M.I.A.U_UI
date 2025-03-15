import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lost_pets_screen.dart';
import 'screens/adopt_screen.dart';
import 'screens/qr_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/pet_id_screen.dart';
import 'screens/support_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/messages_screen.dart';

// Colores principales
const Color primaryColor = Colors.blueAccent; // Puedes cambiarlo según el diseño
const Color backgroundColor = Colors.white;
const Color textColor = Colors.black;
const Color accentColor = Colors.blue; // Para botones y elementos destacados

// Estilos de texto
final TextStyle titleStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: textColor,
);

final TextStyle subtitleStyle = TextStyle(
  fontSize: 16,
  color: textColor,
);

final TextStyle buttonTextStyle = TextStyle(
  fontSize: 18,
  color: Colors.white,
);

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/lost-pets': (context) => LostPetsScreen(),
        '/adopt': (context) => AdoptScreen(),
        '/qr': (context) => QRScreen(),
        '/profile': (context) => ProfileScreen(),
        '/pet-id': (context) => PetIdScreen(),
        '/support': (context) => SupportScreen(),
        '/notifications': (context) => NotificationsScreen(),
        '/messages': (context) => MessagesScreen(),
      },
    );
  }
}