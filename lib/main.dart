// main.dart
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

class ColorBlindnessFilter extends StatelessWidget {
  final Widget child;
  final ColorBlindnessType type;
  final double severity;

  const ColorBlindnessFilter({
    Key? key,
    required this.child,
    required this.type,
    required this.severity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (type == ColorBlindnessType.none || severity == 0) {
      return child;
    }

    // Matrices de filtro para diferentes tipos de daltonismo
    final List<double> filterMatrix;
    switch (type) {
      case ColorBlindnessType.protanopia:
        filterMatrix = [
          0.567, 0.433, 0.000, 0, 0,
          0.558, 0.442, 0.000, 0, 0,
          0.000, 0.242, 0.758, 0, 0,
          0, 0, 0, 1, 0,
        ];
        break;
      case ColorBlindnessType.deuteranopia:
        filterMatrix = [
          0.625, 0.375, 0.000, 0, 0,
          0.700, 0.300, 0.000, 0, 0,
          0.000, 0.300, 0.700, 0, 0,
          0, 0, 0, 1, 0,
        ];
        break;
      case ColorBlindnessType.tritanopia:
        filterMatrix = [
          0.950, 0.050, 0.000, 0, 0,
          0.000, 0.433, 0.567, 0, 0,
          0.000, 0.475, 0.525, 0, 0,
          0, 0, 0, 1, 0,
        ];
        break;
      case ColorBlindnessType.achromatopsia:
        filterMatrix = [
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0, 0, 0, 1, 0,
        ];
        break;
      default:
        return child;
    }

    // Aplicar severidad (interpolar entre matriz de identidad y la matriz de filtro)
    final List<double> finalMatrix = List<double>.generate(20, (index) {
      if (index % 5 == 4) return 0; // No cambiar la columna de offset
      final identityValue = index % 5 == index ~/ 5 ? 1.0 : 0.0;
      return identityValue + (filterMatrix[index] - identityValue) * severity;
    });

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(finalMatrix),
      child: child,
    );
  }
}

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
          return ColorBlindnessFilter(
            type: themeProvider.colorBlindnessType,
            severity: themeProvider.severity,
            child: MaterialApp(
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
            ),
          );
        },
      ),
    );
  }
}