import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color primaryColor = Color(0xFFD0894B);
const Color secondaryColor = Color(0xFF8B5A2B);
const Color backgroundColor = Color(0xFFF5F5F5);
const Color cardColor = Colors.white;

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final TextEditingController _manualCodeController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _manualCodeController.dispose();
    super.dispose();
  }

  Future<void> _processCode(String code) async {
    if (_isProcessing || code.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        _showErrorSnackBar('Inicia sesión para ver la información');
        _resetScanner();
        return;
      }

      final petId = _extractPetId(code);
      if (petId == null) {
        _showErrorSnackBar('Código no válido');
        _resetScanner();
        return;
      }

      final result = await apiService.get('/pets/$petId/', requiresAuth: true);

      if (result.success && result.data != null) {
        _showPetInfo(result.data!);
      } else {
        _showErrorSnackBar(result.message ?? 'Mascota no encontrada');
        _resetScanner();
      }
    } catch (e) {
      _showErrorSnackBar('Error al procesar el código');
      _resetScanner();
    }
  }

  int? _extractPetId(String code) {
    try {
      final match = RegExp(r'\d+').firstMatch(code);
      if (match != null) {
        return int.tryParse(match.group(0)!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _showPetInfo(Map<String, dynamic> petData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PetInfoSheet(pet: petData),
    ).then((_) => _resetScanner());
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetScanner() {
    if (mounted) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      });
    }
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Ingresar código manualmente'),
            content: TextField(
              controller: _manualCodeController,
              decoration: const InputDecoration(
                labelText: 'Código de mascota',
                hintText: 'Ej: MIAU_12345',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processCode(_manualCodeController.text.trim());
                  _manualCodeController.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Buscar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Escanear QR de Mascota',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: _showManualEntryDialog,
            tooltip: 'Ingresar código manualmente',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withAlpha(77),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: primaryColor.withAlpha(51),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner,
                                  size: 80,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Cámara no disponible',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Usa el botón para ingresar\nel código manualmente',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: primaryColor.withAlpha(128),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _showManualEntryDialog,
                icon:
                    _isProcessing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.edit),
                label: Text(
                  _isProcessing ? 'Buscando...' : 'Ingresar código manualmente',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: primaryColor,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '¿Cómo funciona?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoStep(
                      number: '1',
                      title: 'Escanea el QR',
                      description:
                          'Apunta la cámara al código QR de la mascota',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoStep(
                      number: '2',
                      title: 'Ver información',
                      description: 'Visualiza los datos de contacto del dueño',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoStep(
                      number: '3',
                      title: 'Contacta',
                      description: 'Envía un mensaje para ayudar a la mascota',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.search,
                      title: 'Buscar',
                      subtitle: 'Mascota perdida',
                      color: const Color(0xFFE3F2FD),
                      onTap:
                          () => Navigator.pushReplacementNamed(
                            context,
                            '/lost-pets',
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.favorite,
                      title: 'Adoptar',
                      subtitle: 'Nueva familia',
                      color: const Color(0xFFE8F5E9),
                      onTap:
                          () =>
                              Navigator.pushReplacementNamed(context, '/adopt'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: primaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: Colors.green.shade700, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetInfoSheet extends StatelessWidget {
  final Map<String, dynamic> pet;

  const _PetInfoSheet({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: primaryColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.pets,
                        size: 40,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet['name'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pet['breed'] ?? 'Raza desconocida',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(pet['status']).withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusText(pet['status']),
                        style: TextStyle(
                          color: _getStatusColor(pet['status']),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildInfoRow('Tamaño', pet['size'] ?? 'No especificado'),
                _buildInfoRow('Edad', pet['age'] ?? 'No especificada'),
                _buildInfoRow('Ubicación', _getLocationText()),
                if (pet['petDetails'] != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Detalles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pet['petDetails'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/messages');
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Contactar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close, color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF757575)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(dynamic status) {
    switch (status) {
      case 0:
        return 'Perdido';
      case 1:
        return 'Adoptado';
      case 2:
        return 'Buscando familia';
      default:
        return 'No especificado';
    }
  }

  Color _getStatusColor(dynamic status) {
    switch (status) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getLocationText() {
    final city = pet['city'];
    final state = pet['state'];
    if (city != null && state != null) {
      return '$city, $state';
    }
    return state ?? city ?? 'No especificada';
  }
}
