import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
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
const String baseUrl = "http://137.131.25.37:8000"; // URL base del backend

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  String? _profilePhotoUrl; // URL de la foto de perfil

  @override
  void initState() {
    super.initState();
    _loadProfilePhotoUrl(); // Cargar la URL de la foto de perfil al iniciar
  }

  // Cargar la URL de la foto de perfil desde SharedPreferences
  Future<void> _loadProfilePhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('userId');
    final String? imageUrl = prefs.getString('profilePhotoUrl_$userId');

    if (imageUrl != null) {
      // Verifica si la URL ya incluye la baseUrl
      if (!imageUrl.startsWith(baseUrl)) {
        // Si no incluye la baseUrl, concaténala
        final String absoluteImageUrl = '$baseUrl$imageUrl';
        setState(() {
          _profilePhotoUrl =
              '$absoluteImageUrl?${DateTime.now().millisecondsSinceEpoch}';
        });
      } else {
        // Si ya incluye la baseUrl, úsala directamente
        setState(() {
          _profilePhotoUrl =
              '$imageUrl?${DateTime.now().millisecondsSinceEpoch}';
        });
      }
    }
  }

  // Seleccionar una imagen desde la galería
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });

      // Subir la imagen automáticamente
      await _uploadImage();
    } else {
      print('No image selected.');
    }
  }

  // Subir la imagen al backend
  Future<void> _uploadImage() async {
    if (_image == null) return;

    final url = Uri.parse('$baseUrl/api/users-profile/');
    final token = await getToken();

    var request =
        http.MultipartRequest('POST', url)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['userId'] =
              '1' // Asegúrate de incluir el ID del usuario
          ..fields['description'] =
              'Descripción del perfil' // Ejemplo de campo adicional
          ..fields['state'] =
              'Estado' // Ejemplo de campo adicional
          ..fields['city'] =
              'Ciudad' // Ejemplo de campo adicional
          ..fields['address'] =
              'Dirección' // Ejemplo de campo adicional
          ..files.add(
            await http.MultipartFile.fromPath(
              'profilePhoto', // Nombre del campo en el backend
              _image!.path,
            ),
          );

    try {
      var response = await request.send();

      if (response.statusCode == 201) {
        // 201 Created es el código esperado para una creación exitosa
        final responseData = await response.stream.bytesToString();
        final Map<String, dynamic> data = jsonDecode(responseData);

        // Verifica que la respuesta contenga la URL de la imagen
        if (data.containsKey('profilePhoto') && data['profilePhoto'] != null) {
          final String imageUrl = data['profilePhoto'];

          // Extraer la parte relativa de la URL si es absoluta
          final String relativeImageUrl = imageUrl.replaceFirst(baseUrl, '');

          // Guardar solo la parte relativa de la URL en SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final String? userId = prefs.getString(
            'userId',
          ); // Obtener el ID del usuario actual
          await prefs.setString('profilePhotoUrl_$userId', relativeImageUrl);

          // Actualizar el estado con la nueva URL
          setState(() {
            _profilePhotoUrl =
                '$baseUrl$relativeImageUrl?${DateTime.now().millisecondsSinceEpoch}';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Foto de perfil actualizada correctamente')),
          );
        } else {
          throw Exception(
            'La respuesta del backend no contiene la URL de la imagen',
          );
        }
      } else if (response.statusCode == 400) {
        final responseData = await response.stream.bytesToString();
        final Map<String, dynamic> data = jsonDecode(responseData);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${data['userId'][0]}')));
      } else {
        throw Exception(
          'Error al subir la foto de perfil: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error al subir la imagen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la foto de perfil: $e')),
      );
    }
  }

  // Función para cerrar sesión
  Future<void> logout(BuildContext context) async {
    const String logoutUrl = "$baseUrl/api/users/logout/";

    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No se encontró un token de autenticación.');
      }

      final response = await http.post(
        Uri.parse(logoutUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Limpiar la URL de la imagen de perfil al cerrar sesión
        final prefs = await SharedPreferences.getInstance();
        final String? userId = prefs.getString('userId');
        await prefs.remove('profilePhotoUrl_$userId');

        await removeToken();
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
    const String deleteUrl = "$baseUrl/api/users/delete/1/";

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
        await removeToken();
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
    const String userInfoUrl = "$baseUrl/api/users/me/";

    try {
      final token = await getToken();
      if (token == null) {
        await removeToken();
        Navigator.pushReplacementNamed(context, '/login');
        throw Exception('No se encontró un token de autenticación.');
      }

      final response = await http.get(
        Uri.parse(userInfoUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken(context);
        if (newToken == null) {
          await removeToken();
          Navigator.pushReplacementNamed(context, '/login');
          throw Exception('No se pudo refrescar el token.');
        }

        final newResponse = await http.get(
          Uri.parse(userInfoUrl),
          headers: {'Authorization': 'Bearer $newToken'},
        );

        if (newResponse.statusCode == 200) {
          return jsonDecode(newResponse.body);
        } else {
          await removeToken();
          Navigator.pushReplacementNamed(context, '/login');
          throw Exception(
            'Error al obtener la información del usuario: ${newResponse.statusCode}',
          );
        }
      } else {
        await removeToken();
        Navigator.pushReplacementNamed(context, '/login');
        throw Exception(
          'Error al obtener la información del usuario: ${response.statusCode}',
        );
      }
    } catch (e) {
      await removeToken();
      Navigator.pushReplacementNamed(context, '/login');
      throw Exception('Error de conexión: $e');
    }
  }

  Future<String?> refreshToken(BuildContext context) async {
    const String refreshUrl = "$baseUrl/api/token/refresh/";
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) {
      await removeToken();
      Navigator.pushReplacementNamed(context, '/login');
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
        await prefs.setString('jwt_token', newAccessToken);
        return newAccessToken;
      } else if (response.statusCode == 401) {
        await removeToken();
        Navigator.pushReplacementNamed(context, '/login');
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else {
        throw Exception('Error al refrescar el token: ${response.body}');
      }
    } catch (e) {
      await removeToken();
      Navigator.pushReplacementNamed(context, '/login');
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
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        _profilePhotoUrl != null
                            ? NetworkImage(
                              _profilePhotoUrl!,
                              headers: {
                                "Cache-Control": "no-cache",
                              }, // Evitar caché
                            )
                            : AssetImage("assets/images/profile.jpg")
                                as ImageProvider,
                    onBackgroundImageError: (exception, stackTrace) {
                      // Manejar errores al cargar la imagen
                      print("Error al cargar la imagen de perfil: $exception");
                    },
                  ),
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
        "$baseUrl/api/users/update/${widget.userInfo['id']}/";

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
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage("assets/images/profile.jpg"),
            ),
            SizedBox(height: 20),
            Text(
              userInfo['name'] ?? 'Nombre no disponible',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              userInfo['first_name'] ?? 'Apellido no disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 20),
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
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
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
