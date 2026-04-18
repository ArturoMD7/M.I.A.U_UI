import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miauuic/services/theme_provider.dart';
import 'package:miauuic/utils/user_posts_modal.dart';
import 'package:miauuic/services/profile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/api_service.dart';

const Color primaryColor = Color(0xFFD0894B);
const Color iconColor = Colors.black;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cerrar sesión'),
            content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProfileProvider()..initialize(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mi Perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Text(
                'Gestiona tu cuenta',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () => _logout(context),
              tooltip: 'Cerrar sesión',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Consumer<ProfileProvider>(
          builder: (context, provider, _) {
            final state = provider.state;

            if (state.isLoading && state.userInfo == null) {
              return const Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
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
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    final userData = state.userInfo!['data'] ?? state.userInfo!;
    final String fullName =
        '${userData['name'] ?? ''} ${userData['first_name'] ?? ''}'.trim();
    final String? profilePictureUrl = userData['profile_picture'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 60,
            backgroundColor: primaryColor.withAlpha(26),
            backgroundImage:
                profilePictureUrl != null && profilePictureUrl.isNotEmpty
                    ? NetworkImage(profilePictureUrl)
                    : null,
            child:
                profilePictureUrl == null || profilePictureUrl.isEmpty
                    ? const Icon(Icons.person, size: 60, color: primaryColor)
                    : null,
          ),
          const SizedBox(height: 16),
          Text(
            fullName.isEmpty ? 'Nombre no disponible' : fullName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          Text(
            userData['email'] ?? '',
            style: const TextStyle(fontSize: 14, color: Color(0xFF757575)),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          _buildCard([
            _ThemeSwitch(),
            const Divider(),
            _ColorBlindnessSettings(),
          ]),
          const SizedBox(height: 16),
          _buildCard([_ProfileActions(userInfo: userData, provider: provider)]),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: children),
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
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('user_id');

      if (userId == null) {
        throw Exception('No se encontró el ID de usuario');
      }

      final fields = <String, String>{
        'name': _nameController.text,
        'first_name': _firstNameController.text,
        'age': _ageController.text,
        'phone_number': _phoneController.text,
        'street': _streetController.text,
        'neighborhood': _neighborhoodController.text,
        'city': _cityController.text,
        'cp': _cpController.text,
        'state': _stateController.text,
      };

      final files = <http.MultipartFile>[];
      if (_imageBytes != null && _imageName != null) {
        files.add(
          http.MultipartFile.fromBytes(
            'profilePhoto',
            _imageBytes!,
            filename: _imageName,
          ),
        );
      }

      final result = await apiService.multipartPut(
        '/users/update/$userId/',
        fields: fields,
        files: files.isNotEmpty ? files : null,
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Información actualizada correctamente'),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception(result.message ?? 'Error al actualizar');
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
