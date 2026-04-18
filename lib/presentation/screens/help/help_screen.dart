import 'package:flutter/material.dart';
import 'package:miauuic/core/constants/app_colors.dart';
import 'package:miauuic/core/constants/app_dimens.dart';
import 'package:miauuic/widgets/common/cards.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  List<Map<String, String>> _rescueContacts = [
    {
      'name': 'Grupo de Adopción A',
      'phone': '+52 555 123 4567',
      'type': 'adoption',
    },
    {
      'name': 'Grupo de Adopción B',
      'phone': '+52 555 987 6543',
      'type': 'adoption',
    },
    {'name': 'Rescatista 1', 'phone': '+52 555 111 2222', 'type': 'rescue'},
    {'name': 'Rescatista 2', 'phone': '+52 555 333 4444', 'type': 'rescue'},
    {
      'name': 'Refugio Municipal',
      'phone': '+52 555 555 5555',
      'type': 'shelter',
    },
    {
      'name': 'Veterinaria de Emergencia',
      'phone': '+52 555 666 7777',
      'type': 'vet',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : AppColors.background;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
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
            'Ayuda',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Text(
            'Contactos para rescatar mascotas',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Necesitas ayuda?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Contacta a estos grupos y personas para ayudarte con mascotas perdidas o en adopción.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Grupos de Adopción',
            Icons.favorite,
            AppColors.adoptPetColor,
          ),
          const SizedBox(height: 16),
          _buildSection('Rescatistas', Icons.person_search, AppColors.warning),
          const SizedBox(height: 16),
          _buildSection('Refugios', Icons.home, AppColors.primary),
          const SizedBox(height: 16),
          _buildSection('Veterinarias', Icons.local_hospital, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color) {
    final contacts =
        _rescueContacts.where((c) {
          if (title == 'Grupos de Adopción') return c['type'] == 'adoption';
          if (title == 'Rescatistas') return c['type'] == 'rescue';
          if (title == 'Refugios') return c['type'] == 'shelter';
          if (title == 'Veterinarias') return c['type'] == 'vet';
          return false;
        }).toList();

    return ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      children:
          contacts.map((contact) => _buildContactTile(contact, color)).toList(),
    );
  }

  Widget _buildContactTile(Map<String, String> contact, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingMedium,
        vertical: AppDimens.paddingSmall,
      ),
      padding: const EdgeInsets.all(AppDimens.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  contact['phone'] ?? '',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showContactDialog(contact),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Contactar'),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(Map<String, String> contact) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(contact['name'] ?? ''),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Teléfono:'),
                Text(
                  contact['phone'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }
}
