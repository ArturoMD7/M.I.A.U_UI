import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miauuic/services/theme_provider.dart';
import 'package:miauuic/screens/custom_app_bar.dart';
import 'package:miauuic/utils/user_posts_modal.dart';
import 'package:miauuic/services/profile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

const Color primaryColor = Color(0xFFD0894B);
const Color iconColor = Colors.black;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProfileProvider()..initialize(),
      child: Scaffold(
        appBar: CustomAppBar(),
        body: Consumer<ProfileProvider>(
          builder: (context, provider, _) {
            final state = provider.state;

            if (state.isLoading && state.userInfo == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.errorMessage != null && state.userInfo == null) {
              return Center(child: Text(state.errorMessage!));
            }

            return _ProfileContent(state: state, provider: provider);
          },
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final ProfileState state;
  final ProfileProvider provider;

  const _ProfileContent({required this.state, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (state.userInfo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final userData = state.userInfo!['data'] ?? state.userInfo!;
    final String fullName =
        '${userData['name'] ?? ''} ${userData['first_name'] ?? ''}'.trim();
    // Obtener la URL de la foto de perfil si existe en el backend
    final String? profilePictureUrl = userData['profile_picture'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Mi Perfil",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // --- NUEVO: Avatar en el perfil ---
          CircleAvatar(
            radius: 50,
            backgroundColor: primaryColor.withOpacity(0.2),
            backgroundImage:
                profilePictureUrl != null && profilePictureUrl.isNotEmpty
                    ? NetworkImage(profilePictureUrl)
                    : null,
            child:
                profilePictureUrl == null || profilePictureUrl.isEmpty
                    ? const Icon(Icons.person, size: 50, color: primaryColor)
                    : null,
          ),
          const SizedBox(height: 10),

          Text(
            fullName.isEmpty ? 'Nombre no disponible' : fullName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            "ID de usuario: #${userData['id'] ?? 'N/A'}",
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          _ThemeSwitch(),
          _ColorBlindnessSettings(),
          const Divider(),
          const SizedBox(height: 10),
          _ProfileActions(userInfo: userData, provider: provider),
        ],
      ),
    );
  }
}

class _ThemeSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDarkMode = themeProvider.isDarkMode;

    return SwitchListTile(
      title: Text(
        isDarkMode ? 'Modo Oscuro' : 'Modo Claro',
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      value: isDarkMode,
      onChanged: themeProvider.toggleTheme,
      secondary: Icon(
        isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
        color: Theme.of(context).iconTheme.color,
      ),
    );
  }
}

class _ColorBlindnessSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return ExpansionTile(
      title: Text(
        'Modo Daltonismo',
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      leading: Icon(Icons.color_lens, color: Theme.of(context).iconTheme.color),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              _ColorBlindnessTypeDropdown(themeProvider: themeProvider),
              const SizedBox(height: 16),
              _SeveritySlider(themeProvider: themeProvider),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorBlindnessTypeDropdown extends StatelessWidget {
  final ThemeProvider themeProvider;

  const _ColorBlindnessTypeDropdown({required this.themeProvider});

  String _getTypeName(ColorBlindnessType type) {
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

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ColorBlindnessType>(
      initialValue: themeProvider.colorBlindnessType,
      decoration: const InputDecoration(
        labelText: 'Tipo de daltonismo',
        border: OutlineInputBorder(),
      ),
      items:
          ColorBlindnessType.values.map((type) {
            return DropdownMenuItem<ColorBlindnessType>(
              value: type,
              child: Text(_getTypeName(type)),
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
}

class _SeveritySlider extends StatelessWidget {
  final ThemeProvider themeProvider;

  const _SeveritySlider({required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Severidad: ${(themeProvider.severity * 100).round()}%',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
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
}

class _ProfileActions extends StatelessWidget {
  final Map<String, dynamic> userInfo;
  final ProfileProvider provider;

  const _ProfileActions({required this.userInfo, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfileButton(
          icon: Icons.article,
          text: "Mis publicaciones",
          backgroundColor: primaryColor,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.9,
                  child: const UserPostsModal(),
                );
              },
            );
          },
        ),
        _ProfileButton(
          icon: Icons.edit,
          text: "Editar Información",
          backgroundColor: primaryColor,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _EditProfileScreen(userInfo: userInfo),
              ),
            ).then((_) {
              provider.initialize();
            });
          },
        ),
        _ProfileButton(
          icon: Icons.message,
          text: "Ir a Mensajes",
          backgroundColor: primaryColor,
          onPressed: () => Navigator.pushNamed(context, '/messages'),
        ),
        _ProfileButton(
          icon: Icons.logout,
          text: "Cerrar Sesión",
          backgroundColor: primaryColor,
          textColor: Colors.black,
          onPressed: () => _showLogoutDialog(context),
        ),
        _ProfileButton(
          icon: Icons.delete_forever,
          text: "Eliminar Cuenta",
          backgroundColor: Colors.red[700],
          textColor: Colors.white,
          onPressed: () => _showDeleteAccountDialog(context),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                  provider.logout(context);
                },
                child: const Text("Cerrar sesión"),
              ),
            ],
          ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Eliminar cuenta"),
            content: const Text(
              "¿Estás seguro que deseas eliminar tu cuenta permanentemente? Esta acción no se puede deshacer y perderás todos tus datos.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // provider.deleteAccount(context);
                },
                child: const Text(
                  "Eliminar",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  const _ProfileButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
          foregroundColor: textColor ?? Colors.white,
        ),
        icon: Icon(icon, size: 20),
        label: Text(text),
      ),
    );
  }
}

class _EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const _EditProfileScreen({required this.userInfo});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _ageController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _streetController;
  late final TextEditingController _neighborhoodController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _cpController;

  bool _isLoading = false;

  Uint8List? _imageBytes;
  String? _imageName;
  String? _currentImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final userData = widget.userInfo['data'] ?? widget.userInfo;

    _nameController = TextEditingController(text: userData['name'] ?? '');
    _firstNameController = TextEditingController(
      text: userData['first_name'] ?? '',
    );
    _ageController = TextEditingController(
      text: userData['age']?.toString() ?? '',
    );
    _emailController = TextEditingController(text: userData['email'] ?? '');
    _phoneController = TextEditingController(
      text: userData['phone_number'] ?? '',
    );
    _streetController = TextEditingController(text: userData['street'] ?? '');
    _neighborhoodController = TextEditingController(
      text: userData['neighborhood'] ?? '',
    );
    _cityController = TextEditingController(text: userData['city'] ?? '');
    _stateController = TextEditingController(text: userData['state'] ?? '');
    _cpController = TextEditingController(text: userData['cp'] ?? '');

    // Obtener imagen actual si existe (ajusta la key 'profile_picture' a la de tu API)
    _currentImageUrl = userData['profile_picture'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _firstNameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _cpController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        // Leemos los bytes, esto funciona perfecto tanto en Web como en Móvil
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = pickedFile.name; // Guardamos el nombre para el servidor
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Cámara'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Información"),
        backgroundColor: primaryColor,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // --- NUEVO: Widget de Foto de Perfil ---
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          _imageBytes != null
                              ? MemoryImage(_imageBytes!) as ImageProvider
                              : (_currentImageUrl != null &&
                                      _currentImageUrl!.isNotEmpty
                                  ? NetworkImage(_currentImageUrl!)
                                  : null),
                      child:
                          (_imageBytes == null &&
                                  (_currentImageUrl == null ||
                                      _currentImageUrl!.isEmpty))
                              ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey,
                              )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _showImageSourceDialog,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "Datos Personales",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nombre"),
                validator:
                    (value) =>
                        value?.isEmpty ?? true ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: "Apellido"),
                validator:
                    (value) =>
                        value?.isEmpty ?? true ? 'Ingresa tu apellido' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(labelText: "Edad"),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Obligatorio';
                        if (int.tryParse(value!) == null) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: "Teléfono"),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Correo"),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Ingresa tu correo';
                  if (!value!.contains('@')) return 'Correo inválido';
                  return null;
                },
              ),

              const SizedBox(height: 30),
              const Text(
                "Dirección",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: "Calle / Dirección",
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _neighborhoodController,
                decoration: const InputDecoration(labelText: "Colonia"),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: "Ciudad / Municipio",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _cpController,
                      decoration: const InputDecoration(labelText: "C.P."),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _stateController,
                decoration: const InputDecoration(labelText: "Estado"),
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _updateProfile,
                child: const Text("Guardar Cambios"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String baseUrl =
          dotenv.env['API_URL'] ?? 'http://localhost:8000/api';
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      final int? userId = prefs.getInt('user_id');
      final Uri url = Uri.parse('$baseUrl/users/update/$userId');

      // Usar MultipartRequest
      final request = http.MultipartRequest('PUT', url);

      // Agregar Headers
      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      // Agregar los campos de texto
      request.fields['name'] = _nameController.text;
      request.fields['first_name'] = _firstNameController.text;
      request.fields['age'] = _ageController.text;
      request.fields['phone_number'] = _phoneController.text;
      request.fields['street'] = _streetController.text;
      request.fields['neighborhood'] = _neighborhoodController.text;
      request.fields['city'] = _cityController.text;
      request.fields['cp'] = _cpController.text;
      request.fields['state'] = _stateController.text;

      // Agregar la imagen si se seleccionó una
      if (_imageBytes != null && _imageName != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profilePhoto',
            _imageBytes!,
            filename: _imageName,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Información actualizada correctamente'),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Error ${response.statusCode} al actualizar',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
