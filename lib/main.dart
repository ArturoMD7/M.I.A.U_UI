import 'package:flutter/material.dart';
import 'screens/add_pet_screen.dart';
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
import 'services/theme_provider.dart';

// Colores principales
const Color primaryColor = Colors.blueAccent;
const Color darkPrimaryColor = Color(0xFF1565C0);
const Color backgroundColor = Colors.white;
const Color darkBackgroundColor = Color(0xFF121212);
const Color textColor = Colors.black;
const Color darkTextColor = Colors.white;
const Color accentColor = Colors.blue;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PetProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: primaryColor,
              colorScheme: ColorScheme.light(
                primary: primaryColor,
                secondary: accentColor,
              ),
              scaffoldBackgroundColor: backgroundColor,
              appBarTheme: AppBarTheme(
                backgroundColor: primaryColor,
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: darkPrimaryColor,
              colorScheme: ColorScheme.dark(
                primary: darkPrimaryColor,
                secondary: accentColor,
              ),
              scaffoldBackgroundColor: darkBackgroundColor,
              appBarTheme: AppBarTheme(
                backgroundColor: darkPrimaryColor,
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkTextColor,
                ),
              ),
            ),
            themeMode: themeProvider.themeMode,
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
          );
        },
      ),
    );
  }
}