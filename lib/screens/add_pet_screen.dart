import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pet_provider.dart';

class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key});

  @override
  _AddPetScreenState createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  String? _selectedSize;
  int? _selectedStatus;

  final List<String> _sizeOptions = ['Pequeño', 'Mediano', 'Grande'];
  final Map<int, String> _statusOptions = {
    0: 'Perdido',
    1: 'Adoptado', 
    2: 'Buscando familia'
  };

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Agregar Mascota")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nombre*"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Campo obligatorio";
                  }
                  if (value.length > 30) {
                    return "Máximo 30 caracteres";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: "Edad*"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Campo obligatorio";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(labelText: "Raza*"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Campo obligatorio";
                  }
                  if (value.length > 30) {
                    return "Máximo 30 caracteres";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedSize,
                decoration: const InputDecoration(labelText: "Tamaño*"),
                items: _sizeOptions.map((size) {
                  return DropdownMenuItem(
                    value: size,
                    child: Text(size),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSize = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return "Selecciona un tamaño";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _detailsController,
                decoration: const InputDecoration(labelText: "Detalles"),
                maxLines: 3,
                maxLength: 254,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<int>(
                value: _selectedStatus ?? 2, // Default: Buscando familia
                decoration: const InputDecoration(labelText: "Estado*"),
                items: _statusOptions.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final token = await getToken();
                    if (token == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("No se encontró token de autenticación"),
                        ),
                      );
                      return;
                    }

                    // No incluir userId ni qrId - el backend los asignará automáticamente
                    final petData = {
                      'name': _nameController.text,
                      'age': _ageController.text, // Como string según el modelo
                      'breed': _breedController.text,
                      'size': _selectedSize,
                      'petDetails': _detailsController.text,
                      'statusAdoption': _selectedStatus ?? 2,
                    };

                    try {
                      final petProvider = Provider.of<PetProvider>(
                        context,
                        listen: false,
                      );
                      await petProvider.addPet(petData, token);
                      
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Error al agregar mascota: $e"),
                          ),
                        );
                      }
                    }
                  }
                },
                child: const Text("Guardar Mascota"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _breedController.dispose();
    _detailsController.dispose();
    super.dispose();
  }
}