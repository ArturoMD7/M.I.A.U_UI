import 'package:flutter/material.dart';
import 'package:miauui/screens/add_pet_screen.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/lost_pets_screen.dart';
import 'screens/adopt_screen.dart';
import 'screens/qr_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/pet_id_screen.dart';
import 'screens/support_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/messages_screen.dart';
import 'services/pet_provider.dart';

// Colores principales
const Color primaryColor = Colors.blueAccent;
const Color backgroundColor = Colors.white;
const Color textColor = Colors.black;
const Color accentColor = Colors.blue;

// Estilos de texto
final TextStyle titleStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: textColor,
);

final TextStyle subtitleStyle = TextStyle(fontSize: 16, color: textColor);

final TextStyle buttonTextStyle = TextStyle(fontSize: 18, color: Colors.white);

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PetProvider(),
        ), // Agrega el PetProvider aquí
      ],
      child: MaterialApp(
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
          '/add-pet': (context) => AddPetScreen(),
        },
      ),
    );
  }
}
