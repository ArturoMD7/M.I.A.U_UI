import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

const Color primaryColor = Color(0xFFD0894B);

class CreatePetScreen extends StatefulWidget {
  final Map<String, dynamic>? petToEdit;
  const CreatePetScreen({super.key, this.petToEdit});

  @override
  _CreatePetScreenState createState() => _CreatePetScreenState();
}

class _CreatePetScreenState extends State<CreatePetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _detailsController = TextEditingController();
  String? _selectedSize;
  int? _selectedStatus;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  int? _selectedAge = 0;

  bool get isEditing => widget.petToEdit != null;
  String get _baseUrl => apiService.baseUrl;

  final _sizeOptions = ['Pequeño', 'Mediano', 'Grande'];
  final _statusOptions = {0: 'Perdido', 1: 'Adoptado', 2: 'Buscando familia'};
  final _ageOptions = {0: 'Cachorro', 1: 'joven', 2: 'adulto'};

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final pet = widget.petToEdit!;
      _nameController.text = pet['name'] ?? '';
      _breedController.text = pet['breed'] ?? '';
      _detailsController.text = pet['petDetails'] ?? '';
      _selectedSize = _sizeOptions.contains(pet['size']) ? pet['size'] : null;
      _selectedStatus =
          _statusOptions.containsKey(pet['statusAdoption'])
              ? pet['statusAdoption']
              : 2;
      final ageVal = pet['age'];
      _selectedAge =
          ageVal is int
              ? ageVal
              : (ageVal == 'Cachorro' || ageVal == 'cachorro'
                  ? 0
                  : ageVal == 'joven' || ageVal == 'Joven'
                  ? 1
                  : 2);
    } else {
      _selectedStatus = 2;
      _selectedAge = 0;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getString('user_id');

    if (token == null || userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Debes iniciar sesión")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final petData = <String, dynamic>{
        "name": _nameController.text,
        "age": _selectedAge,
        "breed": _breedController.text,
        "size": _selectedSize,
        "petDetails":
            _detailsController.text.isEmpty ? null : _detailsController.text,
        "userId": userId,
        "statusAdoption": _selectedStatus,
      };

      if (_imageBytes != null) {
        petData["image"] = base64Encode(_imageBytes!);
      }

      final url =
          isEditing
              ? "$_baseUrl/pets/${widget.petToEdit!['id']}/"
              : "$_baseUrl/pets/";
      final method = isEditing ? http.put : http.post;

      final response = await method(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(petData),
      );

      if ((isEditing && response.statusCode != 200) ||
          (!isEditing && response.statusCode != 201)) {
        throw Exception("Error: ${response.body}");
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Mascota ${isEditing ? 'actualizada' : 'creada'} exitosamente",
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galería'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Cámara'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              ],
            ),
          ),
    );

    if (source == null) return;
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );
    if (image != null) {
      _imageBytes = await image.readAsBytes();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Editar mascota" : "Crear nueva mascota"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        _imageBytes != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                            : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Agregar foto",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Nombre*"),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? "Requerido"
                              : v.length > 30
                              ? "Máx 30"
                              : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedAge,
                  decoration: const InputDecoration(labelText: "Edad*"),
                  items:
                      _ageOptions.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _selectedAge = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _breedController,
                  decoration: const InputDecoration(labelText: "Raza*"),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? "Requerido"
                              : v.length > 30
                              ? "Máx 30"
                              : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSize,
                  decoration: const InputDecoration(labelText: "Tamaño*"),
                  items: [
                    const DropdownMenuItem(
                      value: "",
                      child: Text("Selecciona"),
                    ),
                    ..._sizeOptions.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged:
                      (v) => setState(
                        () => _selectedSize = v?.isEmpty == true ? null : v,
                      ),
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
                  value: _selectedStatus,
                  decoration: const InputDecoration(labelText: "Estado*"),
                  items:
                      _statusOptions.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                            isEditing
                                ? "Actualizar Mascota"
                                : "Guardar Mascota",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
    _breedController.dispose();
    _detailsController.dispose();
    super.dispose();
  }
}
