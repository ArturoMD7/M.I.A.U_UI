import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CreatePetScreen extends StatefulWidget {
  const CreatePetScreen({super.key});

  @override
  _CreatePetScreenState createState() => _CreatePetScreenState();
}

class _CreatePetScreenState extends State<CreatePetScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  String? _selectedSize;
  int? _selectedStatus;
  File? _selectedImage;
  bool _isLoading = false;
  int? _selectedAge;

  late final String _baseUrl;
  final List<String> _sizeOptions = ['Pequeño', 'Mediano', 'Grande'];
  final Map<int, String> _statusOptions = {
    0: 'Perdido',
    1: 'Adoptado', 
    2: 'Buscando familia'
  };

  final Map<int, String> _ageOptions = {
    0: 'Cachorro (0-1)',
    1: 'Joven (2-6)',  
    2: 'Adulto (+6)'
  };

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
    //Default dropdowns
    _selectedStatus = 2; 
    _selectedAge = 0;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getInt('user_id');

    if (token == null || userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Crear la mascota según tu modelo Django
      final petData = {
        "name": _nameController.text,
        "age": _ageController.text,
        "breed": _breedController.text,
        "size": _selectedSize,
        "petDetails": _detailsController.text.isEmpty ? null : _detailsController.text,
        "userId": userId,
        "statusAdoption": _selectedStatus,
      };

      // 1. Crear la mascota
      final petResponse = await http.post(
        Uri.parse("$_baseUrl/pets/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(petData),
      );

      if (petResponse.statusCode != 201) {
        throw Exception("Error al crear mascota: ${petResponse.body}");
      }

      final petId = jsonDecode(petResponse.body)['id'];

      // 2. Subir imagen si existe
      if (_selectedImage != null) {
        final request = http.MultipartRequest(
          "POST", 
          Uri.parse("$_baseUrl/pet-images/")
        )
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['petId'] = petId.toString()
          ..files.add(await http.MultipartFile.fromPath(
            'image',
            _selectedImage!.path,
          ));

        final response = await request.send();
        if (response.statusCode != 201) {
          throw Exception("Error al subir imagen");
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mascota creada exitosamente")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear nueva mascota")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Campo Nombre
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Nombre*"),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Campo requerido";
                    if (value.length > 30) return "Máximo 30 caracteres";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  value: _selectedAge,
                  decoration: const InputDecoration(labelText: "Edad*"),
                  items: _ageOptions.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedAge = value),
                ),
                const SizedBox(height: 20),

                // Campo Raza
                TextFormField(
                  controller: _breedController,
                  decoration: const InputDecoration(labelText: "Raza*"),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Campo requerido";
                    if (value.length > 30) return "Máximo 30 caracteres";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Selector de Tamaño
                DropdownButtonFormField<String>(
                  value: _selectedSize,
                  hint: const Text("Tamaño*"),
                  items: _sizeOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedSize = value),
                  validator: (value) => value == null ? "Selecciona un tamaño" : null,
                ),
                const SizedBox(height: 16),

                // Campo Detalles
                TextFormField(
                  controller: _detailsController,
                  decoration: const InputDecoration(
                    labelText: "Detalles",
                    hintText: "Detalles adicionales sobre la mascota",
                  ),
                  maxLines: 3,
                  maxLength: 254,
                ),
                const SizedBox(height: 16),

                // Selector de Estado
                DropdownButtonFormField<int>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(labelText: "Estado*"),
                  items: _statusOptions.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedStatus = value),
                ),
                const SizedBox(height: 20),

                // Botón de Guardar
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Guardar Mascota"),
                ),
              ],
            ),
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