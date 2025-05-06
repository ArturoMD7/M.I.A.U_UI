import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
const Color darkPrimaryColor = Color(0xFF8B5A2B);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  String? _profilePhotoUrl;

  late final String apiUrl;
  late final String baseUrl;

  @override
  void initState() {
    super.initState();
    apiUrl = dotenv.env['API_URL'] ?? '192.168.1.133:8000/';
    baseUrl = apiUrl;
    _loadProfilePhotoUrl();
  }

  

  Widget _buildThemeSwitch(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return SwitchListTile(
      title: Text(
        isDarkMode ? 'Modo Oscuro' : 'Modo Claro',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      value: isDarkMode,
      onChanged: (value) {
        themeProvider.toggleTheme(value);
      },
      secondary: Icon(
        isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
        color: Theme.of(context).iconTheme.color,
      ),
    );
  }

  Widget _buildColorBlindnessSettings(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ExpansionTile(
      title: Text(
        'Modo Daltonismo',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      leading: Icon(
        Icons.color_lens,
        color: Theme.of(context).iconTheme.color,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              _buildColorBlindnessTypeDropdown(themeProvider),
              const SizedBox(height: 16),
              _buildSeveritySlider(themeProvider, context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorBlindnessTypeDropdown(ThemeProvider themeProvider) {
    return DropdownButtonFormField<ColorBlindnessType>(
      value: themeProvider.colorBlindnessType,
      decoration: InputDecoration(
        labelText: 'Tipo de daltonismo',
        border: const OutlineInputBorder(),
      ),
      items: ColorBlindnessType.values.map((type) {
        return DropdownMenuItem<ColorBlindnessType>(
          value: type,
          child: Text(_getColorBlindnessTypeName(type)),
        );
      }).toList(),
      onChanged: (type) {
        if (type != null) {
          themeProvider.setColorBlindness(
            type: type,
            severity: themeProvider.severity,
          );
        }
      },
    );
  }

  String _getColorBlindnessTypeName(ColorBlindnessType type) {
    switch (type) {
      case ColorBlindnessType.none:
        return 'Ninguno';
      case ColorBlindnessType.protanopia:
        return 'Protanopia (rojo-verde)';
      case ColorBlindnessType.deuteranopia:
        return 'Deuteranopia (rojo-verde)';
      case ColorBlindnessType.tritanopia:
        return 'Tritanopia (azul-amarillo)';
      case ColorBlindnessType.achromatopsia:
        return 'Achromatopsia (monocromático)';
      default:
        return 'Desconocido';
    }
  }

  Widget _buildSeveritySlider(ThemeProvider themeProvider, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Severidad: ${(themeProvider.severity * 100).round()}%',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        Slider(
          value: themeProvider.severity,
          min: 0,
          max: 1,
          divisions: 10,
          label: '${(themeProvider.severity * 100).round()}%',
          onChanged: (value) {
            themeProvider.setColorBlindness(
              type: themeProvider.colorBlindnessType,
              severity: value,
            );
          },
        ),
      ],
    );
  }

  Future<void> _loadProfilePhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('userId');
    final String? imageUrl = prefs.getString('profilePhotoUrl_$userId');
    final String baseUrl = dotenv.env['API_URL'] ?? '192.168.1.133:8000/';
    if (imageUrl != null) {
      if (!imageUrl.startsWith(baseUrl)) {
        final String absoluteImageUrl = '$baseUrl$imageUrl';
        setState(() {
          _profilePhotoUrl = '$absoluteImageUrl?${DateTime.now().millisecondsSinceEpoch}';
        });
      } else {
        setState(() {
          _profilePhotoUrl = '$imageUrl?${DateTime.now().millisecondsSinceEpoch}';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) return;

    final url = Uri.parse('$baseUrl/users-profile/');
    final token = await getToken();

    var request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['userId'] = '1'
      ..fields['description'] = 'Descripción del perfil'
      ..fields['state'] = 'Estado'
      ..fields['city'] = 'Ciudad'
      ..fields['address'] = 'Dirección'
      ..files.add(
        await http.MultipartFile.fromPath('profilePhoto', _image!.path),
      );

    try {
      var response = await request.send();

      if (response.statusCode == 201) {
        final responseData = await response.stream.bytesToString();
        final Map<String, dynamic> data = jsonDecode(responseData);

        if (data.containsKey('profilePhoto') && data['profilePhoto'] != null) {
          final String imageUrl = data['profilePhoto'];
          final String relativeImageUrl = imageUrl.replaceFirst(baseUrl, '');

          final prefs = await SharedPreferences.getInstance();
          final String? userId = prefs.getString('userId');
          await prefs.setString('profilePhotoUrl_$userId', relativeImageUrl);

          setState(() {
            _profilePhotoUrl = '$baseUrl$relativeImageUrl?${DateTime.now().millisecondsSinceEpoch}';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de perfil actualizada correctamente')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la foto de perfil: $e')),
      );
    }
  }


  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final refreshToken = prefs.getString('refresh_token');
    final String? userId = prefs.getString('userId');

    try {
      if (token != null && refreshToken != null) {
        final response = await http.post(
          Uri.parse('$baseUrl/users/logout/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'refresh': refreshToken}),
        );

        // Puedes imprimir para debug
        print('Logout response: ${response.body}');
      }
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }

    // Eliminar datos del usuario
    await prefs.remove('jwt_token');
    await prefs.remove('refresh_token');
    await prefs.remove('userId');
    await prefs.remove('profilePhotoUrl_$userId');

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Future<void> deleteAccount(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    String deleteUrl = "$baseUrl/users/delete/$userId/";

    try {
      final token = await getToken();
      if (token == null) return;

      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        await removeToken();
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> fetchUserInfo(BuildContext context) async {
    String userInfoUrl = "$baseUrl/users/me/";

    try {
      final token = await getToken();
      if (token == null) throw Exception('No hay token');

      final response = await http.get(
        Uri.parse(userInfoUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      await removeToken();
      Navigator.pushReplacementNamed(context, '/login');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: FutureBuilder<Map<String, dynamic>>(
            future: fetchUserInfo(context),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No se encontraron datos del usuario'));
              }

              final userInfo = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Mi Perfil",
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _profilePhotoUrl != null
                          ? NetworkImage(
                        _profilePhotoUrl!,
                        headers: {"Cache-Control": "no-cache"},
                      )
                          : const AssetImage("assets/images/profile.jpg") as ImageProvider,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userInfo['name'] ?? 'Nombre no disponible',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    "ID de usuario: #${userInfo['id'] ?? 'N/A'}",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  _buildThemeSwitch(context),
                  _buildColorBlindnessSettings(context),
                  const Divider(),
                  const SizedBox(height: 10),
                  _buildButton(
                    context: context,
                    text: "Vista Previa",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PreviewScreen(userInfo: userInfo),
                        ),
                      );
                    },
                  ),
                  _buildButton(
                    context: context,
                    text: "Mis publicaciones",
                    onPressed: () => Navigator.pushNamed(context, '/lost-pets'),
                  ),
                  _buildButton(
                    context: context,
                    text: "Editar Información",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(userInfo: userInfo),
                        ),
                      );
                    },
                  ),
                  _buildButton(
                    context: context,
                    text: "Ir a Mensajes",
                    onPressed: () => Navigator.pushNamed(context, '/messages'),
                  ),
                  _buildButton(
                    context: context,
                    text: "Cerrar Sesión",
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Cerrar sesión"),
                          content: const Text("¿Estás seguro que deseas cerrar sesión?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancelar"),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                logout(context);
                              },
                              child: const Text("Cerrar sesión"),
                              
                            ),
                          ],
                        ),
                      );
                    },

                    backgroundColor: primaryColor,
                    textColor: Colors.black,
                  ),
                  _buildButton(
                    context: context,
                    text: "Eliminar Cuenta",
                    onPressed: () => deleteAccount(context),
                    backgroundColor: primaryColor,
                    textColor: Colors.black,
                  ),
                  const SizedBox(height: 20), // Espacio adicional al final para mejor scroll
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String text,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: backgroundColor ?? Colors.teal,
          foregroundColor: textColor ?? Colors.white,
        ),
        child: Text(text),
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
    final String baseUrl = dotenv.env['API_URL'] ?? '192.168.1.133:8000/';
    String updateUrl = "$baseUrl/users/update/${widget.userInfo['id']}/";

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
      if (token == null) return;

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
          const SnackBar(content: Text('Información actualizada correctamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editar Información")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nombre"),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: "Apellido"),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: "Edad"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Correo"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Teléfono"),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: "Dirección"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateUserInfo,
                child: const Text("Guardar Cambios"),
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
      appBar: AppBar(
        title: const Text("Vista Previa"),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage("assets/images/profile.jpg"),
            ),
            const SizedBox(height: 20),
            Text(
              userInfo['name'] ?? 'Nombre no disponible',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              userInfo['first_name'] ?? 'Apellido no disponible',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Text(
              "ID de usuario: #${userInfo['id'] ?? 'N/A'}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              "Edad: ${userInfo['age'] ?? 'N/A'}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              "Correo: ${userInfo['email'] ?? 'N/A'}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              "Teléfono: ${userInfo['phone_number'] ?? 'N/A'}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              "Dirección: ${userInfo['address'] ?? 'N/A'}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.teal,
              ),
              child: const Text(
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