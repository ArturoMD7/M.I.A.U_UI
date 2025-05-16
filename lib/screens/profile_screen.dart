import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:miauuic/services/theme_provider.dart';
import 'package:miauuic/screens/custom_app_bar.dart';
import 'package:miauuic/utils/user_posts_modal.dart';
import 'package:miauuic/services/profile_provider.dart';

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

  const _ProfileContent({
    required this.state,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (state.userInfo == null) {
      return const Center(child: CircularProgressIndicator());
    }
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
          _ProfileAvatar(state: state, provider: provider),
          const SizedBox(height: 10),
          Text(
            state.userInfo?['name'] ?? 'Nombre no disponible',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            "ID de usuario: #${state.userInfo?['id'] ?? 'N/A'}",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
          _ProfileActions(userInfo: state.userInfo!, provider: provider),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final ProfileState state;
  final ProfileProvider provider;

  const _ProfileAvatar({
    required this.state,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: provider.pickImage,
      onLongPress: () {
        if (state.profilePhotoUrl != null) {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Cambiar foto'),
                  onTap: () {
                    Navigator.pop(context);
                    provider.pickImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Eliminar foto', 
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    // provider.deleteProfilePhoto();
                  },
                ),
              ],
            ),
          );
        }
      },
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: state.profilePhotoUrl != null
                ? NetworkImage(
                    state.profilePhotoUrl!,
                    headers: const {"Cache-Control": "no-cache"},
                  ) as ImageProvider
                : const AssetImage("assets/images/default_profile.jpg") as ImageProvider,
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              size: 20,
              color: Colors.white,
            ),
          ),
          if (provider.state.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
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
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
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
      case ColorBlindnessType.none: return 'Ninguno';
      case ColorBlindnessType.protanopia: return 'Protanopia (rojo-verde)';
      case ColorBlindnessType.deuteranopia: return 'Deuteranopia (rojo-verde)';
      case ColorBlindnessType.tritanopia: return 'Tritanopia (azul-amarillo)';
      case ColorBlindnessType.achromatopsia: return 'Achromatopsia (monocromático)';
      default: return 'Desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ColorBlindnessType>(
      value: themeProvider.colorBlindnessType,
      decoration: InputDecoration(
        labelText: 'Tipo de daltonismo',
        border: const OutlineInputBorder(),
      ),
      items: ColorBlindnessType.values.map((type) {
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
}

class _ProfileActions extends StatelessWidget {
  final Map<String, dynamic> userInfo;
  final ProfileProvider provider;

  const _ProfileActions({
    required this.userInfo,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfileButton(
          icon: Icons.article,
          text: "Mis publicaciones",
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _EditProfileScreen(userInfo: userInfo),
              ),
            );
          },
        ),
        _ProfileButton(
          icon: Icons.message,
          text: "Ir a Mensajes",
          onPressed: () => Navigator.pushNamed(context, '/messages'),
        ),
        _ProfileButton(
          icon: Icons.logout,
          text: "Cerrar Sesión",
          backgroundColor: const Color(0xFFD0894B),
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
      builder: (context) => AlertDialog(
        title: const Text("Eliminar cuenta"),
        content: const Text(
            "¿Estás seguro que deseas eliminar tu cuenta permanentemente? "
            "Esta acción no se puede deshacer y perderás todos tus datos."),
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userInfo['name'] ?? '');
    _firstNameController = TextEditingController(text: widget.userInfo['first_name'] ?? '');
    _ageController = TextEditingController(text: widget.userInfo['age']?.toString() ?? '');
    _emailController = TextEditingController(text: widget.userInfo['email'] ?? '');
    _phoneController = TextEditingController(text: widget.userInfo['phone_number'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _firstNameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Información"),
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
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nombre"),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: "Apellido"),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ingresa tu apellido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: "Edad"),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Ingresa tu edad';
                  if (int.tryParse(value!) == null) return 'Edad inválida';
                  return null;
                },
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
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Teléfono"),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(labelText: "Dirección"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                child: const Text("Guardar Cambios"),
              ),
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
      // Implementar lógica de actualización aquí
      await Future.delayed(const Duration(seconds: 1)); // Simulación
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Información actualizada')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}