import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddPetScreen extends StatefulWidget {
  final Map<String, dynamic>? petToEdit;
  const AddPetScreen({super.key, this.petToEdit});

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
  File? _selectedImage;
  bool _isLoading = false;

  late final String _baseUrl;
  final List<String> _sizeOptions = ['Pequeno', 'Mediano', 'Grande'];
  final Map<int, String> _statusOptions = {
    0: 'Perdido',
    1: 'Adoptado', 
    2: 'Buscando familia'
  };

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
    
    // Si estamos editando, cargamos los datos existentes
    if (widget.petToEdit != null) {
      _nameController.text = widget.petToEdit!['name'] ?? '';
      _ageController.text = widget.petToEdit!['age'] ?? '';
      _breedController.text = widget.petToEdit!['breed'] ?? '';
      _selectedSize = widget.petToEdit!['size'];
      _detailsController.text = widget.petToEdit!['petDetails'] ?? '';
      _selectedStatus = widget.petToEdit!['statusAdoption'];
    } else {
      _selectedStatus = 2; // Default: Buscando familia
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final token = await _getToken();
    final userId = await _getUserId();

    if (token == null || userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final petData = {
        "name": _nameController.text,
        "age": _ageController.text,
        "breed": _breedController.text,
        "size": _selectedSize,
        "petDetails": _detailsController.text.isEmpty ? null : _detailsController.text,
        "userId": userId,
        "statusAdoption": _selectedStatus,
      };

      // Determinar si es creación o edición
      final isEditing = widget.petToEdit != null;
      final url = isEditing 
          ? "$_baseUrl/pets/${widget.petToEdit!['id']}/" 
          : "$_baseUrl/pets/";

      final response = isEditing
          ? await http.put(
              Uri.parse(url),
              headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer $token",
              },
              body: jsonEncode(petData),
            )
          : await http.post(
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

      // Subir imagen si existe
      if (_selectedImage != null) {
        final petId = isEditing 
            ? widget.petToEdit!['id'] 
            : jsonDecode(response.body)['id'];

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

        final imgResponse = await request.send();
        if (imgResponse.statusCode != 201) {
          throw Exception("Error al subir imagen");
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing 
              ? "Mascota actualizada exitosamente" 
              : "Mascota creada exitosamente"),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.petToEdit != null ? "Editar Mascota" : "Agregar Mascota"),
      ),
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

                // Campo Edad
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(labelText: "Edad*"),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Campo requerido";
                    if (value.length > 50) return "Máximo 50 caracteres";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

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
                  decoration: const InputDecoration(labelText: "Tamaño*"),
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

                // Selector de Imagen
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text("Seleccionar Imagen"),
                  onPressed: _pickImage,
                ),
                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Image.file(_selectedImage!, height: 100),
                  ),
                const SizedBox(height: 30),

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