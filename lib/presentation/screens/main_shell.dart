import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import 'home/home_screen.dart';
import 'pets/my_pets_screen.dart';
import 'profile/profile_screen.dart';
import 'help/help_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _unreadMessages = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MyPetsScreen(),
    const ProfileScreen(),
    const HelpScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadMessages();
  }

  Future<void> _loadUnreadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _unreadMessages = prefs.getInt('unread_messages') ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading unread messages: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppColors.background,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final bgColor = isDark ? const Color(0xFF2D2D2D) : AppColors.card;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final textSecColor = isDark ? Colors.white70 : AppColors.textSecondary;
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingSmall,
            vertical: AppDimens.paddingSmall,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Inicio',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.pets_outlined,
                activeIcon: Icons.pets,
                label: 'Mis Mascotas',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Mi Perfil',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.help_outline,
                activeIcon: Icons.help,
                label: 'Ayuda',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingMedium,
          vertical: AppDimens.paddingSmall,
        ),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary.withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: AppDimens.iconMedium,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
