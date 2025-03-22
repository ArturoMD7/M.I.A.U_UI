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
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Agregar Mascota")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Nombre"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Ingresa el nombre de la mascota";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _ageController,
                decoration: InputDecoration(labelText: "Edad"),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Ingresa la edad de la mascota";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _breedController,
                decoration: InputDecoration(labelText: "Raza"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Ingresa la raza de la mascota";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _sizeController,
                decoration: InputDecoration(labelText: "Tamaño"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Ingresa el tamaño de la mascota";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _detailsController,
                decoration: InputDecoration(labelText: "Detalles"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Ingresa detalles adicionales";
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final token = await getToken();
                    if (token == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "No se encontró un token de autenticación.",
                          ),
                        ),
                      );
                      return;
                    }

                    final petData = {
                      'name': _nameController.text,
                      'age': int.parse(_ageController.text),
                      'breed': _breedController.text,
                      'size': _sizeController.text,
                      'petDetails': _detailsController.text,
                      'statusAdoption': 0, // Valor por defecto
                      'userId':
                          1, // Asignar un ID de usuario por defecto (debes ajustar esto)
                      'qrId':
                          1, // Asignar un ID de código QR por defecto (debes ajustar esto)
                    };

                    final petProvider = Provider.of<PetProvider>(
                      context,
                      listen: false,
                    );
                    await petProvider.addPet(petData, token);

                    Navigator.pop(context); // Regresar a la pantalla anterior
                  }
                },
                child: Text("Guardar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
