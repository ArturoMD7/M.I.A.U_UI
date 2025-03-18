import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'custom_app_bar.dart';

const Color primaryColor = Color(0xFFD0894B);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Función para cerrar sesión
  Future<void> logout(BuildContext context) async {
    const String logoutUrl =
        "http://192.168.1.95:8000/api/users/logout/"; // Ruta de logout (si existe)

    try {
      final response = await http.post(Uri.parse(logoutUrl));

      if (response.statusCode == 200) {
        // Limpiar el estado de autenticación (por ejemplo, eliminar el token)
        // Redirigir a la pantalla de inicio de sesión
        Navigator.pushReplacementNamed(context, '/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  // Función para eliminar la cuenta
  Future<void> deleteAccount(BuildContext context) async {
    const String deleteUrl =
        "http://192.168.1.95:8000/api/users/delete/1/"; // Reemplaza "1" con el ID del usuario

    try {
      final response = await http.delete(Uri.parse(deleteUrl));

      if (response.statusCode == 200) {
        // Redirigir a la pantalla de inicio de sesión después de eliminar la cuenta
        Navigator.pushReplacementNamed(context, '/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar la cuenta: ${response.body}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  // Función para obtener la información del usuario
  Future<Map<String, dynamic>> fetchUserInfo() async {
    const String userInfoUrl =
        "http://192.168.1.95:8000/api/users/1/"; // Reemplaza "1" con el ID del usuario

    try {
      final response = await http.get(Uri.parse(userInfoUrl));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al obtener la información del usuario');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Mi Perfil",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage("assets/images/profile.jpg"),
            ),
            SizedBox(height: 10),
            Text(
              "Nombre de usuario",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "ID de usuario: #dkfjsdsklfjds",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                // Navegar a la pantalla de vista previa
                final userInfo = await fetchUserInfo();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PreviewScreen(userInfo: userInfo),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.teal,
              ),
              child: Text(
                "Vista Previa",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Navegar a la pantalla de mis publicaciones
                Navigator.pushNamed(context, '/lost-pets');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.teal,
              ),
              child: Text(
                "Mis publicaciones",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Navegar a la pantalla de edición de información
                Navigator.pushNamed(context, '/edit-profile');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.teal,
              ),
              child: Text(
                "Editar Información",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Navegar a la pantalla de mensajes
                Navigator.pushNamed(context, '/messages');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.teal,
              ),
              child: Text(
                "Ir a Mensajes",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Cerrar sesión
                logout(context);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: primaryColor,
              ),
              child: Text(
                "Cerrar Sesión",
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Eliminar cuenta
                deleteAccount(context);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: primaryColor,
              ),
              child: Text(
                "Eliminar Cuenta",
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pantalla de vista previa
class PreviewScreen extends StatelessWidget {
  final Map<String, dynamic> userInfo;

  const PreviewScreen({super.key, required this.userInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Vista Previa")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nombre: ${userInfo['name'] ?? 'No disponible'}",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "Correo: ${userInfo['email'] ?? 'No disponible'}",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "Teléfono: ${userInfo['phone_number'] ?? 'No disponible'}",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "Dirección: ${userInfo['address'] ?? 'No disponible'}",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// Pantalla de edición de información
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Editar Información")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: "Nombre")),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: "Correo")),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: "Teléfono")),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: "Dirección")),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Guardar cambios
              },
              child: Text("Guardar Cambios"),
            ),
          ],
        ),
      ),
    );
  }
}
