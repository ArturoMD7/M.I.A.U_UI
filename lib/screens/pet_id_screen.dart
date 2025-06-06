import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'custom_app_bar.dart';
import 'add_pet_screen.dart';
import '../services/pet_provider.dart';

class PetIdScreen extends StatefulWidget {
  const PetIdScreen({super.key});

  @override
  _PetIdScreenState createState() => _PetIdScreenState();
}
const Color primaryColor = Color(
  0xFFD0894B,
); // Color marrón claro similar al de la imagen
const Color iconColor = Colors.black;

class _PetIdScreenState extends State<PetIdScreen> {
  late String _baseUrl;
  
  // Mapas para las traducciones de estado, tipo y edad
  final Map<int, String> _statusTexts = {
    0: 'Perdido',
    1: 'Adoptado',
    2: 'Buscando familia',
  };

  final Map<int, String> _typeTexts = {
    0: 'Perro',
    1: 'Gato', 
    2: 'Ave',
    3: 'Roedor',
    4: 'Otro'
  };

  final Map<int, String> _ageTexts = {
    0: 'Cachorro',
    1: 'Joven', 
    2: 'Adulto'
  };

  final Map<int, Color> _statusColors = {
    0: Colors.red,
    1: Colors.green,
    2: Colors.orange,
  };

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _refreshPets() async {
    final token = await _getToken();
    if (token != null) {
      await Provider.of<PetProvider>(context, listen: false).fetchPets(token);
    }
  }

  Future<void> _deletePet(BuildContext context, int petId) async {
    final token = await _getToken();
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar eliminación"),
        content: const Text("¿Estás seguro de que quieres eliminar esta mascota?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse("$_baseUrl/pets/$petId/"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 204) {
        if (!mounted) return;
        
        // Actualiza el estado local primero
        Provider.of<PetProvider>(context, listen: false).removePet(petId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mascota eliminada exitosamente")),
        );
      } else {
        throw Exception("Error al eliminar mascota: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al eliminar mascota: ${e.toString()}")),
      );
    }
  }


  void _showPetDetails(BuildContext context, Map<String, dynamic> pet) {
    final statusText = {
      0: 'Perdido',
      1: 'Adoptado',
      2: 'Buscando familia',
    }[pet['statusAdoption']] ?? 'Desconocido';

    final ageText = {
      0: 'Cachorro',
      1: 'Joven',
      2: 'Adulto',
    }[pet['age']] ?? pet['age']?.toString() ?? 'Desconocido';

    final statusColor = {
      0: Colors.red,
      1: Colors.green,
      2: Colors.orange,
    }[pet['statusAdoption']] ?? Colors.grey;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
                      errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.pets, size: 100, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildDetailRow("Nombre:", pet['name']),
                _buildDetailRow("Edad:", pet['age']),
                _buildDetailRow("Raza:", pet['breed']),
                _buildDetailRow("Tamaño:", pet['size']),
                _buildDetailRow("Estado:", statusText),
                _buildDetailRow("Detalles:", pet['petDetails'] ?? 'Sin detalles'),
                if (pet['qrCode'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Text("Código QR:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Image.network(
                        pet['qrCode']['qr_code_url'], 
                        height: 100,
                        errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.qr_code, size: 100, color: Colors.grey),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
    final petProvider = Provider.of<PetProvider>(context);

    if (!petProvider.hasLoaded && !petProvider.isLoading) {
      _getToken().then((token) {
        if (token != null) {
          petProvider.fetchPets(token);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se encontró un token de autenticación.")),
          );
        }
      });
    }

    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Mis Mascotas",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: petProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : petProvider.pets.isEmpty
                      ? const Center(
                          child: Text(
                            "No tienes mascotas registradas aún.",
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            final token = await _getToken();
                            if (token != null) {
                              await petProvider.fetchPets(token);
                            }
                          },
                          child: ListView.builder(
                            itemCount: petProvider.pets.length,
                            itemBuilder: (context, index) {
                              final pet = petProvider.pets[index];
                              return _buildPetCard(context, pet);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPetScreen()),
          ).then((_) {
            _getToken().then((token) {
              if (token != null) {
                petProvider.fetchPets(token);
              }
            });
          });
        },
        icon: const Icon(Icons.add),
        label: const Text("Agregar Mascota"),
        backgroundColor: primaryColor,
      ),
    );
  }

  Widget _buildPetCard(BuildContext context, Map<String, dynamic> pet) {
    final ageText = {
      0: 'Cachorro',
      1: 'Joven',
      2: 'Adulto',
    }[pet['age']] ?? pet['age']?.toString() ?? 'Desconocido';
    final statusText = _statusTexts[pet['statusAdoption']] ?? 'Desconocido';
    final breedText = pet['breed'] ?? 'Desconocido'; // Mostramos directamente el breed
    final statusColor = _statusColors[pet['statusAdoption']] ?? Colors.grey;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: () => _showPetDetails(context, pet),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (pet['imagePath'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        pet['imagePath'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.pets, size: 40),
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet['name'] ?? 'Nombre no disponible',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$breedText - $ageText', // Mostramos breed directamente
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Tamaño: ${pet['size'] ?? 'No especificado'}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(statusText),
                    backgroundColor: statusColor.withOpacity(0.2),
                    labelStyle: TextStyle(color: statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddPetScreen(
                            petToEdit: pet,
                          ),
                        ),
                      ).then((_) {
                        _getToken().then((token) {
                          if (token != null) {
                            Provider.of<PetProvider>(context, listen: false)
                                .fetchPets(token);
                          }
                        });
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePet(context, pet['id']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}