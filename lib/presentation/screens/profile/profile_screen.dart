import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miauuic/core/constants/app_colors.dart';
import 'package:miauuic/core/constants/app_dimens.dart';
import 'package:miauuic/services/profile_provider.dart';
import 'package:miauuic/services/theme_provider.dart';
import 'package:miauuic/screens/messages_screen.dart';
import 'package:miauuic/screens/profile_screen.dart' as original;
import 'package:miauuic/utils/user_posts_modal.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final isDarkMode = themeProvider.isDarkMode;
          final textColor = isDarkMode ? Colors.white : AppColors.textPrimary;
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
                  builder: (context) => const original.ProfileScreen(),
                ),
              );
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
