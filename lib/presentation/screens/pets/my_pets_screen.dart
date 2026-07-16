import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  String? _getPetImageUrl(Map<String, dynamic> pet) {
    final possibleKeys = ['image', 'imagePath', 'photo', 'profile_picture', 'imageUrl'];
    for (final key in possibleKeys) {
      final value = pet[key];
      if (value != null && value.toString().isNotEmpty) {
        return apiService.getFullMediaUrl(value.toString());
      }
    }
    return null;
  }

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
        final token = await _getToken();
        if (token != null && mounted) {
          await Provider.of<PetProvider>(context, listen: false).fetchPets(token, forceRefresh: true);
        }
        if (mounted) {
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


  Future<void> _generateQR(Map<String, dynamic> pet) async {
    final petId = pet['id'];
    final token = await _getToken();
    if (token == null) return;
    
    // Mostramos un loader
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final String generateQRUrl = "${apiService.baseUrl}/codeqr/generate_qr/";

    try {
      final response = await http.post(
        Uri.parse(generateQRUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pet_id': petId}),
      );
      
      if (!mounted) return;
      Navigator.pop(context); // cerrar loader

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        pet['qrId'] = data['data']['qr_id'];
        pet['qrUrl'] = data['data']['qr_code'];
        Provider.of<PetProvider>(context, listen: false).updatePet(pet);
        
        Navigator.pop(context); // cerrar bottom sheet para que se vea reflejado al volver a abrir
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR generado correctamente')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar el QR: ${response.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // cerrar loader
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  Future<void> _deleteQR(Map<String, dynamic> pet) async {
    final qrId = pet['qrId'];
    if (qrId == null) return;
    final token = await _getToken();
    if (token == null) return;

    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final String deleteQRUrl = "${apiService.baseUrl}/codeqr/";

    try {
      final response = await http.delete(
        Uri.parse('$deleteQRUrl$qrId/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;
      Navigator.pop(context); // cerrar loader

      if (response.statusCode == 204) {
        pet['qrId'] = null;
        pet['qrUrl'] = null;
        Provider.of<PetProvider>(context, listen: false).updatePet(pet);
        
        Navigator.pop(context); // Cerrar bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR eliminado correctamente')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar el QR: ${response.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // cerrar loader
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  void _generateAndDownloadPDF(Map<String, dynamic> pet) async {
    try {
      final pdf = pw.Document();
      final qrImageUrl = pet['qrUrl'];
      
      if (qrImageUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay URL de QR disponible")));
        }
        return;
      }

      final response = await http.get(Uri.parse(qrImageUrl));
      final qrImage = pw.MemoryImage(response.bodyBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Header(level: 0, child: pw.Text("Identificación de Mascota")),
                pw.SizedBox(height: 20),
                pw.Text("Nombre: ${pet['name'] ?? 'Sin nombre'}"),
                pw.Text("Raza: ${pet['breed'] ?? 'No especificada'}"),
                pw.SizedBox(height: 20),
                pw.Image(qrImage, width: 250, height: 250),
                pw.SizedBox(height: 20),
                pw.Text("Escanea este código para ver mi información.", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
              ],
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'QR_${pet['name'] ?? 'Mascota'}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generando PDF: $e")));
      }
    }
  }

  void _showPetDetails(Map<String, dynamic> pet) {
    final imageUrl = _getPetImageUrl(pet);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasQR = pet['qrId'] != null;
    final qrUrl = pet['qrUrl'] != null ? apiService.getFullMediaUrl(pet['qrUrl']) : null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Agarradera (Drag handle)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Encabezado con imagen
                      if (imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 250,
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(Icons.pets, size: 80, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        ),
                      const SizedBox(height: 24),
                      
                      // Título
                      Text(
                        pet['name'] ?? 'Sin nombre',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Detalles en tarjetas
                      _buildInfoCards(pet, isDark),
                      const SizedBox(height: 24),
                      
                      // Detalles de texto
                      if (pet['petDetails'] != null && pet['petDetails'].toString().isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Detalles",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pet['petDetails'],
                              style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 16, height: 1.5),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      
                      // Separador QR
                      Divider(color: isDark ? Colors.white24 : Colors.grey[300]),
                      const SizedBox(height: 16),
                      
                      // Sección QR
                      Text(
                        "Código QR",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      
                      if (!hasQR)
                        // Botón generar QR
                        ElevatedButton.icon(
                          onPressed: () => _generateQR(pet),
                          icon: const Icon(Icons.qr_code, color: Colors.white),
                          label: const Text("Generar código QR para collar", style: TextStyle(color: Colors.white, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        )
                      else
                        // QR Generado
                        Column(
                          children: [
                            if (qrUrl != null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10)],
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: qrUrl,
                                  width: 200,
                                  height: 200,
                                  placeholder: (context, url) => const SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator())),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _generateAndDownloadPDF(pet),
                                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                    label: const Text("Exportar", style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _deleteQR(pet),
                                    icon: const Icon(Icons.delete, color: Colors.white),
                                    label: const Text("Eliminar", style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCards(Map<String, dynamic> pet, bool isDark) {
    // Calculamos edad como en la tarjeta
    String displayAge = pet['age']?.toString() ?? 'N/A';
    if (displayAge != 'N/A') {
      final date = DateTime.tryParse(displayAge);
      if (date != null) {
        final now = DateTime.now();
        int years = now.year - date.year;
        int months = now.month - date.month;
        if (months < 0) {
          years--;
          months += 12;
        }
        if (years > 0) displayAge = '$years año(s)';
        else if (months > 0) displayAge = '$months mes(es)';
        else displayAge = 'Menos de un mes';
      } else {
        if (displayAge == '0') displayAge = 'Cachorro';
        if (displayAge == '1') displayAge = 'Joven';
        if (displayAge == '2') displayAge = 'Adulto';
      }
    }
    
    return Row(
      children: [
        Expanded(child: _buildSmallInfoCard(Icons.cake, 'Edad', displayAge, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildSmallInfoCard(Icons.pets, 'Raza', pet['breed'] ?? 'Mestizo', isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildSmallInfoCard(Icons.straighten, 'Tamaño', pet['size'] ?? 'Mediano', isDark)),
      ],
    );
  }

  Widget _buildSmallInfoCard(IconData icon, String title, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(15) : AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
      floatingActionButton: _buildFab(),
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

  String? _getPetImageUrl() {
    final possibleKeys = ['image', 'imagePath', 'photo', 'profile_picture', 'imageUrl'];
    for (final key in possibleKeys) {
      final value = pet[key];
      if (value != null && value.toString().isNotEmpty) {
        return apiService.getFullMediaUrl(value.toString());
      }
    }
    return null;
  }

  String _getFormattedAge(String? rawAge) {
    if (rawAge == null || rawAge.isEmpty) return 'N/A';
    final date = DateTime.tryParse(rawAge);
    if (date != null) {
      final now = DateTime.now();
      int years = now.year - date.year;
      int months = now.month - date.month;
      if (months < 0) {
        years--;
        months += 12;
      }
      if (years > 0) return '$years año(s)';
      if (months > 0) return '$months mes(es)';
      return 'Menos de un mes';
    }
    // Legacy support (e.g. '0', '1', 'Cachorro')
    if (rawAge == '0') return 'Cachorro';
    if (rawAge == '1') return 'Joven';
    if (rawAge == '2') return 'Adulto';
    return rawAge;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = pet['statusAdoption'] ?? 2;
    final statusText = statusTexts[status] ?? 'Desconocido';
    final statusColor = statusColors[status] ?? Colors.grey;
    final imageUrl = _getPetImageUrl();
    final displayAge = _getFormattedAge(pet['age']?.toString());

    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subTextColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.paddingLarge),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 60 : 15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Header
              Stack(
                children: [
                  if (imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: Icon(Icons.pets, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(Icons.pets, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  
                  // Status Badge Overlay
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(217),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Action Buttons Overlay
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      children: [
                        _buildGlassButton(Icons.edit, Colors.white, onEdit),
                        const SizedBox(width: 8),
                        _buildGlassButton(Icons.delete_outline, Colors.redAccent, onDelete),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Details Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pet['name'] ?? 'Sin nombre',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cake, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                displayAge,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.pets, size: 16, color: subTextColor),
                        const SizedBox(width: 6),
                        Text(
                          pet['breed'] ?? 'Mestizo',
                          style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.straighten, size: 16, color: subTextColor),
                        const SizedBox(width: 6),
                        Text(
                          pet['size'] ?? 'Mediano',
                          style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, Color color, VoidCallback onPressed) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(80),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: 20),
            onPressed: onPressed,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
