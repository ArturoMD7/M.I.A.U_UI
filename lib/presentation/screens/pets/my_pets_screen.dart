import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miauuic/core/constants/app_colors.dart';
import 'package:miauuic/core/constants/app_dimens.dart';
import 'package:miauuic/widgets/common/indicators.dart';
import 'package:miauuic/widgets/common/badges.dart';
import 'package:miauuic/services/pet_provider.dart';
import 'package:miauuic/services/api_service.dart';
import 'package:miauuic/screens/create_pet_screen.dart';

class MyPetsScreen extends StatefulWidget {
  const MyPetsScreen({super.key});

  @override
  State<MyPetsScreen> createState() => MyPetsScreenState();
}

class MyPetsScreenState extends State<MyPetsScreen> {
  late ScrollController _scrollController;
  bool _showFab = true;

  final Map<int, String> _statusTexts = {
    0: 'Perdido',
    1: 'Adoptado',
    2: 'Buscando familia',
  };

  final Map<int, Color> _statusColors = {
    0: AppColors.lostPetColor,
    1: AppColors.adoptPetColor,
    2: AppColors.warning,
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadPets();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_showFab) setState(() => _showFab = false);
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_showFab) setState(() => _showFab = true);
    }
  }

  Future<void> _loadPets() async {
    final token = await _getToken();
    if (token != null) {
      await Provider.of<PetProvider>(context, listen: false).fetchPets(token);
    }
  }

  void refresh() => _loadPets();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _deletePet(int petId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text(
              '¿Estás seguro de que quieres eliminar esta mascota?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final token = await _getToken();
      if (token == null) return;

      final result = await apiService.delete('/pets/$petId/');

      if (result.success) {
        if (mounted) {
          Provider.of<PetProvider>(context, listen: false).removePet(petId);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Mascota eliminada')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Error al eliminar')),
          );
        }
      }
    }
  }

  void _showPetDetails(Map<String, dynamic> pet) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(pet['name'] ?? 'Nombre no disponible'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pet['imagePath'] != null)
                    Center(
                      child: Image.network(
                        pet['imagePath'],
                        height: 150,
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
                              Icons.pets,
                              size: 100,
                              color: Colors.grey,
                            ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Edad:', pet['age']),
                  _buildDetailRow('Raza:', pet['breed']),
                  _buildDetailRow('Tamaño:', pet['size']),
                  _buildDetailRow(
                    'Estado:',
                    _statusTexts[pet['statusAdoption']] ?? 'Desconocido',
                  ),
                  _buildDetailRow(
                    'Detalles:',
                    pet['petDetails'] ?? 'Sin detalles',
                  ),
                ],
              ),
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

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value?.toString() ?? 'No disponible')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : AppColors.background;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _showFab ? _buildFab() : null,
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
            'Mis Mascotas',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Text(
            'Gestiona tus mascotas',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<PetProvider>(
      builder: (context, petProvider, _) {
        if (petProvider.isLoading) {
          return const LoadingIndicator();
        }

        if (petProvider.pets.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.pets,
            title: 'No tienes mascotas',
            subtitle: 'Agrega tu primera mascota',
            actionText: 'Agregar Mascota',
            onAction: () => _navigateToAddPet(),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadPets,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppDimens.paddingLarge),
            itemCount: petProvider.pets.length,
            itemBuilder: (context, index) {
              final pet = petProvider.pets[index];
              return _PetCard(
                pet: pet,
                statusColors: _statusColors,
                statusTexts: _statusTexts,
                onTap: () => _showPetDetails(pet),
                onEdit: () => _navigateToEditPet(pet),
                onDelete: () => _deletePet(pet['id']),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _navigateToAddPet,
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Agregar',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _navigateToAddPet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePetScreen()),
    ).then((_) => _loadPets());
  }

  void _navigateToEditPet(Map<String, dynamic> pet) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreatePetScreen(petToEdit: pet)),
    ).then((_) => _loadPets());
  }
}

class _PetCard extends StatelessWidget {
  final Map<String, dynamic> pet;
  final Map<int, Color> statusColors;
  final Map<int, String> statusTexts;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PetCard({
    required this.pet,
    required this.statusColors,
    required this.statusTexts,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = pet['statusAdoption'] ?? 2;
    final statusText = statusTexts[status] ?? 'Desconocido';
    final statusColor = statusColors[status] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.paddingMedium),
            child: Column(
              children: [
                Row(
                  children: [
                    if (pet['imagePath'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusMedium,
                        ),
                        child: Image.network(
                          pet['imagePath'],
                          width: AppDimens.avatarLarge,
                          height: AppDimens.avatarLarge,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                width: AppDimens.avatarLarge,
                                height: AppDimens.avatarLarge,
                                color: AppColors.primary.withAlpha(26),
                                child: const Icon(
                                  Icons.pets,
                                  color: AppColors.primary,
                                ),
                              ),
                        ),
                      ),
                    const SizedBox(width: AppDimens.paddingMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet['name'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pet['breed'] ?? ''} - ${pet['age'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Tamaño: ${pet['size'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          StatusChip(
                            label: statusText,
                            backgroundColor: statusColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.paddingSmall),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
