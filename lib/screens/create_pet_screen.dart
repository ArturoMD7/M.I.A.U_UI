import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/pet_provider.dart';
import 'package:miauuic/core/constants/app_colors.dart';

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
  
  DateTime? _birthDate;
  String? _legacyAge;

  bool get isEditing => widget.petToEdit != null;
  String get _baseUrl => apiService.baseUrl;

  final _sizeOptions = ['Pequeño', 'Mediano', 'Grande'];
  final _statusOptions = {0: 'Perdido', 1: 'Adoptado', 2: 'Buscando familia'};

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final pet = widget.petToEdit!;
      _nameController.text = pet['name'] ?? '';
      _breedController.text = pet['breed'] ?? '';
      _detailsController.text = pet['petDetails'] ?? '';
      _selectedSize = _sizeOptions.contains(pet['size']) ? pet['size'] : null;
      _selectedStatus = _statusOptions.containsKey(pet['statusAdoption']) ? pet['statusAdoption'] : 2;
      
      final ageVal = pet['age']?.toString();
      if (ageVal != null) {
        final parsed = DateTime.tryParse(ageVal);
        if (parsed != null) {
          _birthDate = parsed;
        } else {
          _legacyAge = ageVal;
        }
      }
    } else {
      _selectedStatus = 2;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_birthDate == null && _legacyAge == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debes seleccionar una fecha de nacimiento")));
      return;
    }
    if (_selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debes seleccionar un tamaño")));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getString('user_id');

    if (token == null || userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debes iniciar sesión")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = isEditing ? "$_baseUrl/pets/${widget.petToEdit!['id']}/" : "$_baseUrl/pets/";
      final request = http.MultipartRequest(isEditing ? 'PUT' : 'POST', Uri.parse(url));

      request.headers['Authorization'] = "Bearer $token";

      request.fields['name'] = _nameController.text;
      
      if (_birthDate != null) {
        // Enviar ISO8601 YYYY-MM-DD
        request.fields['age'] = DateFormat('yyyy-MM-dd').format(_birthDate!);
      } else {
        request.fields['age'] = _legacyAge!;
      }
      
      request.fields['breed'] = _breedController.text;
      request.fields['size'] = _selectedSize!;
      request.fields['userId'] = userId;
      request.fields['statusAdoption'] = _selectedStatus.toString();
      
      if (_detailsController.text.isNotEmpty) {
        request.fields['petDetails'] = _detailsController.text;
      }

      if (_imageBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('image', _imageBytes!, filename: 'pet_image.jpg'));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if ((isEditing && response.statusCode != 200) || (!isEditing && response.statusCode != 201)) {
        throw Exception("Error: ${response.body}");
      }

      try {
        if (mounted) {
          final petResult = await apiService.get('/pets/my-pets/');
          if (petResult.success && petResult.data != null) {
            List<dynamic> petsData;
            if (petResult.data is List) {
              petsData = petResult.data as List<dynamic>;
            } else if (petResult.data!['data'] != null) {
              petsData = petResult.data!['data'] as List<dynamic>;
            } else {
              petsData = [];
            }
            if (mounted) {
              final petProvider = Provider.of<PetProvider>(context, listen: false);
              petProvider.updatePetsFromServer(petsData);
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Mascota ${isEditing ? 'actualizada' : 'creada'} exitosamente")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Seleccionar Imagen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final image = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (image != null) {
      _imageBytes = await image.readAsBytes();
      if (mounted) setState(() {});
    }
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            ),
            dialogBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _legacyAge = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : AppColors.background;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final inputFill = isDark ? Colors.white.withAlpha(15) : Colors.grey[100];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(isEditing ? "Editar Mascota" : "Nueva Mascota", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Picker (Avatar style)
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, 5))
                            ],
                            border: Border.all(color: AppColors.primary.withAlpha(50), width: 4),
                          ),
                          child: _imageBytes != null
                              ? ClipOval(child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                              : Icon(Icons.pets, size: 60, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Name Field
                _buildTextField(
                  controller: _nameController,
                  label: 'Nombre de la mascota',
                  icon: Icons.badge,
                  textColor: textColor,
                  fillColor: inputFill!,
                  validator: (v) => (v == null || v.isEmpty) ? "Requerido" : (v.length > 30 ? "Máx 30" : null),
                ),
                const SizedBox(height: 20),

                // Birth Date Selector
                Text('Fecha de nacimiento', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectBirthDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _birthDate != null 
                                ? DateFormat('dd de MMMM, yyyy', 'es').format(_birthDate!) 
                                : (_legacyAge != null ? 'Registrado antes ($_legacyAge)' : 'Selecciona cuándo nació'),
                            style: TextStyle(color: (_birthDate != null || _legacyAge != null) ? textColor : subColor, fontSize: 16),
                          ),
                        ),
                        Icon(Icons.calendar_month, color: subColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Breed Field
                _buildTextField(
                  controller: _breedController,
                  label: 'Raza',
                  icon: Icons.pets,
                  textColor: textColor,
                  fillColor: inputFill,
                  validator: (v) => (v == null || v.isEmpty) ? "Requerido" : (v.length > 30 ? "Máx 30" : null),
                ),
                const SizedBox(height: 20),

                // Size ChoiceChips
                Text('Tamaño', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: _sizeOptions.map((size) {
                    final isSelected = _selectedSize == size;
                    return ChoiceChip(
                      label: Text(size),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedSize = size);
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      backgroundColor: inputFill,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Status ChoiceChips
                Text('Estado', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _statusOptions.entries.map((entry) {
                    final isSelected = _selectedStatus == entry.key;
                    Color activeColor;
                    if (entry.key == 0) activeColor = AppColors.lostPetColor; // Perdido
                    else if (entry.key == 1) activeColor = AppColors.adoptPetColor; // Adoptado
                    else activeColor = AppColors.warning; // Buscando

                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedStatus = entry.key);
                      },
                      selectedColor: activeColor,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      backgroundColor: inputFill,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Details Field
                _buildTextField(
                  controller: _detailsController,
                  label: 'Detalles adicionales',
                  icon: Icons.notes,
                  textColor: textColor,
                  fillColor: inputFill,
                  maxLines: 3,
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    shadowColor: AppColors.primary.withAlpha(100),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEditing ? "Actualizar Mascota" : "Guardar Mascota", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color textColor,
    required Color fillColor,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor),
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withAlpha(150)),
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 40 : 0),
          child: Icon(icon, color: AppColors.primary),
        ),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
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
