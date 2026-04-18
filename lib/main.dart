import 'package:flutter/material.dart';
import 'screens/recovery_password_screen.dart';
import 'screens/create_pet_screen.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/qr_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/messages_screen.dart';
import 'presentation/screens/main_shell.dart';
import 'services/pet_provider.dart';
import 'services/theme_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //Al usar await esta linea es obligatoria de usar

  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('es', null);

  runApp(const MyApp());
}

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
    super.key,
    required this.child,
    required this.type,
    required this.severity,
  });

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
          0.567,
          0.433,
          0.000,
          0,
          0,
          0.558,
          0.442,
          0.000,
          0,
          0,
          0.000,
          0.242,
          0.758,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
        break;
      case ColorBlindnessType.deuteranopia:
        filterMatrix = [
          0.625,
          0.375,
          0.000,
          0,
          0,
          0.700,
          0.300,
          0.000,
          0,
          0,
          0.000,
          0.300,
          0.700,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
        break;
      case ColorBlindnessType.tritanopia:
        filterMatrix = [
          0.950,
          0.050,
          0.000,
          0,
          0,
          0.000,
          0.433,
          0.567,
          0,
          0,
          0.000,
          0.475,
          0.525,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
        break;
      case ColorBlindnessType.achromatopsia:
        filterMatrix = [
          0.299,
          0.587,
          0.114,
          0,
          0,
          0.299,
          0.587,
          0.114,
          0,
          0,
          0.299,
          0.587,
          0.114,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
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
                scaffoldBackgroundColor: Colors.white,
                colorScheme: const ColorScheme.light(
                  primary: primaryColor,
                  secondary: accentColor,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: primaryColor,
                  elevation: 0,
                  titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  iconTheme: IconThemeData(color: Colors.white),
                ),
                cardTheme: const CardThemeData(color: Colors.white),
                iconTheme: const IconThemeData(color: Colors.black87),
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(color: Colors.black),
                  bodyMedium: TextStyle(color: Colors.black),
                  bodySmall: TextStyle(color: Colors.black54),
                  titleLarge: TextStyle(color: Colors.black),
                  titleMedium: TextStyle(color: Colors.black),
                  titleSmall: TextStyle(color: Colors.black),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                  labelStyle: const TextStyle(color: Colors.black87),
                  hintStyle: const TextStyle(color: Colors.black45),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                dialogTheme: const DialogThemeData(
                  backgroundColor: Colors.white,
                  titleTextStyle: TextStyle(color: Colors.black),
                  contentTextStyle: TextStyle(color: Colors.black87),
                ),
                bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                  backgroundColor: Colors.white,
                  selectedItemColor: primaryColor,
                  unselectedItemColor: Colors.black54,
                ),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                primaryColor: primaryColor,
                scaffoldBackgroundColor: const Color(0xFF1E1E1E),
                colorScheme: const ColorScheme.dark(
                  primary: primaryColor,
                  secondary: accentColor,
                  surface: Color(0xFF2D2D2D),
                  onSurface: Colors.white,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF2D2D2D),
                  elevation: 0,
                  titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  iconTheme: IconThemeData(color: Colors.white),
                ),
                cardTheme: const CardThemeData(color: Color(0xFF2D2D2D)),
                iconTheme: const IconThemeData(color: Colors.white),
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(color: Colors.white),
                  bodyMedium: TextStyle(color: Colors.white),
                  bodySmall: TextStyle(color: Colors.white70),
                  titleLarge: TextStyle(color: Colors.white),
                  titleMedium: TextStyle(color: Colors.white),
                  titleSmall: TextStyle(color: Colors.white),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFF2D2D2D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                  labelStyle: const TextStyle(color: Colors.white),
                  hintStyle: const TextStyle(color: Colors.white54),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
                dialogTheme: const DialogThemeData(
                  backgroundColor: Color(0xFF2D2D2D),
                  titleTextStyle: TextStyle(color: Colors.white),
                  contentTextStyle: TextStyle(color: Colors.white70),
                ),
                bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                  backgroundColor: Color(0xFF2D2D2D),
                  selectedItemColor: primaryColor,
                  unselectedItemColor: Colors.white54,
                ),
              ),
              themeMode: themeProvider.themeMode,
              initialRoute: '/',
              routes: {
                '/': (context) => const LoginScreen(),
                '/register': (context) => const RegisterScreen(),
                '/home': (context) => const MainShell(),
                '/qr': (context) => const QRScreen(),
                '/qr-scanner': (context) => const QRScannerScreen(),
                '/profile': (context) => const ProfileScreen(),
                '/messages': (context) => const MessagesScreen(),
                '/create-pet': (context) => const CreatePetScreen(),
                '/recovery-password':
                    (context) => const RecoveryPasswordScreen(),
              },
            ),
          );
        },
      ),
    );
  }
}
