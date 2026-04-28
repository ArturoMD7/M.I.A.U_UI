import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:miauuic/core/constants/app_colors.dart';
import 'package:miauuic/core/constants/app_dimens.dart';
import 'package:miauuic/services/profile_provider.dart';
import 'package:miauuic/services/theme_provider.dart';
import 'package:miauuic/utils/user_posts_modal.dart';
import '../../../services/api_service.dart';
import 'package:miauuic/screens/messages_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  void refresh() {
    context.read<ProfileProvider>().initialize();
  }

  Future<void> _logout() async {
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

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider(
      create: (context) => ProfileProvider()..initialize(),
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : AppColors.background,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
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
          onPressed: _logout,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        if (state.isLoading && state.userInfo == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (state.errorMessage != null && state.userInfo == null) {
          return Center(child: Text(state.errorMessage!));
        }

        return _ProfileContent(
          state: state,
          provider: provider,
          onLogout: _logout,
        );
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final ProfileState state;
  final ProfileProvider provider;
  final VoidCallback onLogout;

  const _ProfileContent({
    required this.state,
    required this.provider,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : AppColors.card;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final textSecColor = isDark ? Colors.white70 : AppColors.textSecondary;

    if (state.userInfo == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final userData = state.userInfo!['data'] ?? state.userInfo!;
    final String userId = userData['id']?.toString() ?? '';
    final String fullName =
        '${userData['name'] ?? ''} ${userData['first_name'] ?? ''}'.trim();
    final String? profilePictureUrl = userData['profile_picture'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: AppDimens.avatarLarge,
            backgroundColor: AppColors.primary.withAlpha(26),
            backgroundImage:
                profilePictureUrl != null && profilePictureUrl.isNotEmpty
                    ? NetworkImage(profilePictureUrl)
                    : null,
            child:
                profilePictureUrl == null || profilePictureUrl.isEmpty
                    ? const Icon(
                      Icons.person,
                      size: 60,
                      color: AppColors.primary,
                    )
                    : null,
          ),
          const SizedBox(height: 16),
          Text(
            fullName.isEmpty ? 'Nombre no disponible' : fullName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            userData['email'] ?? '',
            style: TextStyle(fontSize: 14, color: textSecColor),
          ),
          if (userId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ID: $userId',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildSettingsSection(context, isDark, cardColor),
          const SizedBox(height: 16),
          _buildActionsSection(context, userData, cardColor),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    bool isDark,
    Color cardColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppDimens.paddingLarge),
      child: Column(
        children: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final isDarkMode = themeProvider.isDarkMode;
              final textColor =
                  isDarkMode ? Colors.white : AppColors.textPrimary;
              return SwitchListTile(
                title: Text(
                  isDarkMode ? 'Modo Oscuro' : 'Modo Claro',
                  style: TextStyle(color: textColor),
                ),
                value: isDarkMode,
                onChanged: (isOn) => themeProvider.toggleTheme(isOn),
                secondary: Icon(
                  isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                  color: AppColors.primary,
                ),
              );
            },
          ),
          const Divider(),
          _ColorBlindnessSettings(),
        ],
      ),
    );
  }

  Widget _buildActionsSection(
    BuildContext context,
    Map<String, dynamic> userData,
    Color cardColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppDimens.paddingLarge),
      child: Column(
        children: [
          _ActionButton(
            icon: Icons.article,
            text: 'Mis publicaciones',
            onPressed: () => _showUserPosts(context),
          ),
          _ActionButton(
            icon: Icons.edit,
            text: 'Editar Información',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _EditProfileScreen(userInfo: userData),
                ),
              ).then((_) {
                provider.initialize();
              });
            },
          ),
          _ActionButton(
            icon: Icons.message,
            text: 'Ir a Mensajes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MessagesScreen()),
              );
            },
          ),
          _ActionButton(
            icon: Icons.qr_code,
            text: 'Generar QR',
            onPressed: () {
              Navigator.pushNamed(context, '/qr');
            },
          ),
          _ActionButton(
            icon: Icons.delete_forever,
            text: 'Eliminar Cuenta',
            onPressed: () => _showDeleteAccountDialog(context),
            color: Colors.red[700],
          ),
          _ActionButton(
            icon: Icons.logout,
            text: 'Cerrar Sesión',
            onPressed: onLogout,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  void _showUserPosts(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.9,
            child: const UserPostsModal(),
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

class _ColorBlindnessSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return ExpansionTile(
      title: Text('Modo Daltonismo', style: TextStyle(color: textColor)),
      leading: Icon(Icons.color_lens, color: AppColors.primary),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Severidad: ${(themeProvider.severity * 100).round()}%',
          style: TextStyle(color: textColor),
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.paddingSmall),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            ),
          ),
          icon: Icon(icon, size: 20),
          label: Text(text),
        ),
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
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = pickedFile.name;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : AppColors.background;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text("Editar Información", style: TextStyle(color: textColor)),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[300],
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
                              ? Icon(
                                Icons.person,
                                size: 60,
                                color: isDark ? Colors.white70 : Colors.grey,
                              )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 2),
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

              Text(
                "Datos Personales",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Nombre",
                  labelStyle: TextStyle(color: textColor.withAlpha(178)),
                ),
                validator:
                    (value) =>
                        value?.isEmpty ?? true ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _firstNameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Apellido",
                  labelStyle: TextStyle(color: textColor.withAlpha(178)),
                ),
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
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Edad",
                        labelStyle: TextStyle(color: textColor.withAlpha(178)),
                      ),
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
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Teléfono",
                        labelStyle: TextStyle(color: textColor.withAlpha(178)),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Correo",
                  labelStyle: TextStyle(color: textColor.withAlpha(178)),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Ingresa tu correo';
                  if (!value!.contains('@')) return 'Correo inválido';
                  return null;
                },
              ),

              const SizedBox(height: 30),
              Text(
                "Dirección",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _streetController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Calle / Dirección",
                  labelStyle: TextStyle(color: textColor.withAlpha(178)),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _neighborhoodController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Colonia",
                  labelStyle: TextStyle(color: textColor.withAlpha(178)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Ciudad / Municipio",
                        labelStyle: TextStyle(color: textColor.withAlpha(178)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _cpController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "C.P.",
                        labelStyle: TextStyle(color: textColor.withAlpha(178)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _stateController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Estado",
                  labelStyle: TextStyle(color: textColor.withAlpha(178)),
                ),
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColors.primary,
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
        'email': _emailController.text,
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
        '/users/$userId/',
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
