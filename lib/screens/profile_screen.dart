import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('jwt_token', token);
}

Future<void> removeToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('jwt_token');
}

Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('jwt_token');
}

const Color primaryColor = Color(0xFFD0894B);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Función para cerrar sesión
  Future<void> logout(BuildContext context) async {
    const String logoutUrl = "http://192.168.1.64:8000/api/users/logout/";

    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No se encontró un token de autenticación.');
      }

      final response = await http.post(
        Uri.parse(logoutUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer $token', // Enviar el token en los encabezados
        },
      );

      if (response.statusCode == 200) {
        await removeToken(); // Eliminar el token al cerrar sesión
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
    const String deleteUrl = "http://192.168.1.64:8000/api/users/delete/1/";

    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No se encontró un token de autenticación.');
      }

      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        await removeToken(); // Eliminar el token al eliminar la cuenta
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

  // Función para obtener la información del usuario actual
  Future<Map<String, dynamic>> fetchUserInfo(BuildContext context) async {
    const String userInfoUrl = "http://192.168.1.64:8000/api/users/me/";

    try {
      final token = await getToken();
      if (token == null) {
        await removeToken(); // Eliminar el token expirado
        Navigator.pushReplacementNamed(context, '/login'); // Redirigir al login
        throw Exception('No se encontró un token de autenticación.');
      }

      final response = await http.get(
        Uri.parse(userInfoUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Si el token ha expirado, intenta refrescarlo
        final newToken = await refreshToken(context);
        if (newToken == null) {
          await removeToken(); // Eliminar el token expirado
          Navigator.pushReplacementNamed(
            context,
            '/login',
          ); // Redirigir al login
          throw Exception('No se pudo refrescar el token.');
        }

        // Reintentar la solicitud con el nuevo token
        final newResponse = await http.get(
          Uri.parse(userInfoUrl),
          headers: {'Authorization': 'Bearer $newToken'},
        );

        if (newResponse.statusCode == 200) {
          return jsonDecode(newResponse.body);
        } else {
          await removeToken(); // Eliminar el token expirado
          Navigator.pushReplacementNamed(
            context,
            '/login',
          ); // Redirigir al login
          throw Exception(
            'Error al obtener la información del usuario: ${newResponse.statusCode}',
          );
        }
      } else {
        await removeToken(); // Eliminar el token expirado
        Navigator.pushReplacementNamed(context, '/login'); // Redirigir al login
        throw Exception(
          'Error al obtener la información del usuario: ${response.statusCode}',
        );
      }
    } catch (e) {
      await removeToken(); // Eliminar el token expirado
      Navigator.pushReplacementNamed(context, '/login'); // Redirigir al login
      throw Exception('Error de conexión: $e');
    }
  }

  Future<String?> refreshToken(BuildContext context) async {
    const String refreshUrl = "http://192.168.1.64:8000/api/token/refresh/";
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) {
      await removeToken(); // Eliminar el token expirado
      Navigator.pushReplacementNamed(context, '/login'); // Redirigir al login
      throw Exception('No se encontró un refresh token.');
    }

    try {
      final response = await http.post(
        Uri.parse(refreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String newAccessToken = responseData['access'];

        // Guardar el nuevo access token
        await prefs.setString('jwt_token', newAccessToken);
        return newAccessToken;
      } else if (response.statusCode == 401) {
        // Si el refresh token es inválido, redirigir al login
        await removeToken(); // Eliminar el token expirado
        Navigator.pushReplacementNamed(context, '/login'); // Redirigir al login
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else {
        throw Exception('Error al refrescar el token: ${response.body}');
      }
    } catch (e) {
      await removeToken(); // Eliminar el token expirado
      Navigator.pushReplacementNamed(context, '/login'); // Redirigir al login
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: fetchUserInfo(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('No se encontraron datos del usuario'));
            }

            final userInfo = snapshot.data!;

            return Column(
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
                  userInfo['name'] ?? 'Nombre no disponible',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  "ID de usuario: #${userInfo['id'] ?? 'N/A'}",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 20),
                Divider(),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => EditProfileScreen(userInfo: userInfo),
                      ),
                    );
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
            );
          },
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const EditProfileScreen({super.key, required this.userInfo});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userInfo['name'] ?? '';
    _firstNameController.text = widget.userInfo['first_name'] ?? '';
    _ageController.text = widget.userInfo['age']?.toString() ?? '';
    _emailController.text = widget.userInfo['email'] ?? '';
    _phoneController.text = widget.userInfo['phone_number'] ?? '';
    _addressController.text = widget.userInfo['address'] ?? '';
  }

  Future<void> _updateUserInfo() async {
    final String updateUrl =
        "http://192.168.1.64:8000/api/users/update/${widget.userInfo['id']}/";

    final Map<String, dynamic> updatedData = {
      'name': _nameController.text,
      'first_name': _firstNameController.text,
      'age': int.tryParse(_ageController.text) ?? 0,
      'email': _emailController.text,
      'phone_number': _phoneController.text,
      'address': _addressController.text,
    };

    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No se encontró un token de autenticación.');
      }

      final response = await http.put(
        Uri.parse(updateUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updatedData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Información actualizada correctamente')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al actualizar la información: ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Editar Información")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Nombre"),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: "Apellido"),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _ageController,
                decoration: InputDecoration(labelText: "Edad"),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: "Correo"),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: "Teléfono"),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: "Dirección"),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _updateUserInfo();
                },
                child: Text("Guardar Cambios"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PreviewScreen extends StatelessWidget {
  final Map<String, dynamic> userInfo;

  const PreviewScreen({super.key, required this.userInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Vista Previa"), backgroundColor: Colors.teal),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Foto de perfil
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage("assets/images/profile.jpg"),
            ),
            SizedBox(height: 20),
            // Nombre
            Text(
              userInfo['name'] ?? 'Nombre no disponible',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            // Apellido
            Text(
              userInfo['first_name'] ?? 'Apellido no disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 20),
            // Datos del usuario
            Text(
              "ID de usuario: #${userInfo['id'] ?? 'N/A'}",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              "Edad: ${userInfo['age'] ?? 'N/A'}",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              "Correo: ${userInfo['email'] ?? 'N/A'}",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              "Teléfono: ${userInfo['phone_number'] ?? 'N/A'}",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              "Dirección: ${userInfo['address'] ?? 'N/A'}",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 30),
            // Botón de regreso
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Volver a la pantalla anterior
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.teal,
              ),
              child: Text(
                "Regresar",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
