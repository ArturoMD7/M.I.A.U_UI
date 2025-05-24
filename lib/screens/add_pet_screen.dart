import 'package:flutter/material.dart';
import 'package:googleapis/eventarc/v1.dart';
import 'package:http/http.dart' as http;
import 'package:miauuic/services/pet_provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart' as prov;


const Color primaryColor = Color(0xFFD68F5E);

class AddPetScreen extends StatefulWidget {
  final Map<String, dynamic>? petToEdit;
  const AddPetScreen({super.key, this.petToEdit});

  @override
  _AddPetScreenState createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  String? _selectedSize;
  int? _selectedStatus;
  String? _selectedAge;
  String? _selectedType;
  bool _isLoading = false;

  late final String _baseUrl;
  final List<String> _sizeOptions = ['Pequeno', 'Mediano', 'Grande'];
  final Map<int, String> _statusOptions = {
    0: 'Perdido',
    1: 'Adoptado', 
    2: 'Buscando familia'
  };

  final Map<String, String> _ageOptions = {
    'Cachorro': 'Cachorro',
    'Joven': 'Joven', 
    'Adulto': 'Adulto'
  };
  final Map<String, String> _typeOptions = {
    'Perro': 'Perro',
    'Gato': 'Gato', 
    'Ave': 'Ave',
    'Roedor': 'Roedor',
    'Otro': 'Otro'
  };

@override
void initState() {
  super.initState();
  _baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
  
  if (widget.petToEdit != null) {
    _nameController.text = widget.petToEdit!['name'] ?? '';
    _selectedSize = widget.petToEdit!['size'];
    _detailsController.text = widget.petToEdit!['petDetails'] ?? '';
    _selectedStatus = widget.petToEdit!['statusAdoption'];
    
    // Manejo de la edad (convertir de número a texto si es necesario)
    if (widget.petToEdit!['age'] is int) {
      _selectedAge = {
        0: 'Cachorro',
        1: 'Joven',
        2: 'Adulto',
      }[widget.petToEdit!['age']] ?? 'Cachorro';
    } else {
      _selectedAge = widget.petToEdit!['age']?.toString() ?? 'Cachorro';
    }
    
    // Manejo del tipo (convertir de número a texto si es necesario)
    if (widget.petToEdit!['breed'] is int) {
      final breedIndex = widget.petToEdit!['breed'];
      _selectedType = _typeOptions.keys.toList().elementAtOrNull(breedIndex) ?? 'Perro';
    } else {
      _selectedType = widget.petToEdit!['breed']?.toString() ?? 'Perro';
    }
  } else {
    _selectedStatus = 2; // Default: Buscando familia
    _selectedAge = _ageOptions.keys.first; // Valor por defecto
    _selectedType = _typeOptions.keys.first; // Valor por defecto
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


  // En el método _submitForm de AddPetScreen
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
      "size": _selectedSize,
      "petDetails": _detailsController.text.isEmpty ? null : _detailsController.text,
      "userId": userId,
      "statusAdoption": _selectedStatus,
      "age": _selectedAge, // Enviamos directamente el texto
      "breed": _selectedType, // Enviamos directamente el texto
    };

    // Eliminar campos nulos
    petData.removeWhere((key, value) => value == null);

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

    final responseData = json.decode(response.body);
    
    // Actualizar el estado local
    final petProvider = prov.Provider.of<PetProvider>(context, listen: false);
    if (isEditing) {
      petProvider.updatePet(responseData);
    } else {
      petProvider.addPet(responseData);
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
        backgroundColor: primaryColor,
      ),
      
      
      
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
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

                // Dropdown de Edad
                DropdownButtonFormField<String>(
                  value: _selectedAge,
                  decoration: const InputDecoration(labelText: "Edad*"),
                  items: _ageOptions.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedAge = value),
                  validator: (value) => value == null ? "Selecciona una edad" : null,
                ),
                const SizedBox(height: 20),

                // Dropdown de Tipo
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: "Tipo de Mascota*"),
                  items: _typeOptions.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key.toString(),
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedType = value),
                  validator: (value) => value == null ? "Selecciona un tipo" : null,
                ),
                const SizedBox(height: 20),

                // Dropdown de Tamaño
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

                // Dropdown de Estado
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
                  validator: (value) => value == null ? "Selecciona un estado" : null,
                ),
                const SizedBox(height: 20),

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

                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
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
    _detailsController.dispose();
    super.dispose();
  }
}