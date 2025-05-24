import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

const Color primaryColor = Color(0xFFD68F5E);

void main() async {
  await dotenv.load(fileName: '.env');
  runApp(MaterialApp(home: RegisterScreen()));
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cpController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  final TextEditingController extNumberController = TextEditingController();
  final TextEditingController intNumberController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController neighborhoodController = TextEditingController();

  String? city;
  String? state;
  List<String> colonies = [];
  bool isLoading = false;
  bool isSearchingCP = false;
  bool cpValid = false;
  String? selectedColony;

  // Obtener variables de entorno
  String get apiUrl => dotenv.env['API_URL'] ?? 'http://192.168.1.131:8000';
  String get dipomexApiKey => dotenv.env['DIPOMEX_API_KEY'] ?? '';
  String get dipomexUrl => 'https://api.tau.com.mx/dipomex/v1/codigo_postal';

  Future<void> searchCP() async {
  final cp = cpController.text.trim();

  if (cp.isEmpty || cp.length != 5 || int.tryParse(cp) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ingresa un código postal válido (5 dígitos)')),
    );
    return;
  }

  setState(() {
    isSearchingCP = true;
    cpValid = false;
    city = null;
    state = null;
    colonies = [];
    selectedColony = null;
  });

  try {
    final url = Uri.parse('$dipomexUrl?cp=$cp');
    final response = await http.get(
      url,
      headers: {'APIKEY': dipomexApiKey},
    );

    print('--- RESPUESTA DIPOMEX ---');
    print(response.body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['error'] == false) {
        final cpData = data['codigo_postal'];
        setState(() {
          city = cpData['municipio'];
          state = cpData['estado'];
          // Modificación aquí para manejar correctamente la estructura de colonias
          colonies = (cpData['colonias'] as List).map<String>((colonia) {
            // Si la colonia es un String, lo usamos directamente
            if (colonia is String) {
              return colonia;
            }
            // Si es un objeto, extraemos el campo 'colonia'
            return colonia['colonia'] as String;
          }).toList();
          cpValid = true;
          
          // Actualizar los controladores de texto
          cityController.text = city ?? '';
          stateController.text = state ?? '';
        });

        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Datos encontrados'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ciudad: $city'),
                    Text('Estado: $state'),
                    const SizedBox(height: 10),
                    const Text('Colonias disponibles:', 
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...colonies.map((colonia) => Text('- $colonia')).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        }
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'No se encontró información válida.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de servidor: ${response.statusCode}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    setState(() => isSearchingCP = false);
  }
}
  Future<void> createUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!cpValid || selectedColony == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor verifica tu código postal y selecciona una colonia')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/users/signup/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': nameController.text,
          'first_name': firstNameController.text,
          'last_name': lastNameController.text, 
          'age': int.parse(ageController.text),
          'email': emailController.text,
          'password': passwordController.text,
          'phone_number': phoneController.text, 
          'street': streetController.text, 
          'neighborhood': selectedColony, 
          'cp': cpController.text, 
          'city': cityController.text, 
          'state': stateController.text, 
          'country': 'México',
        }),
      );

      print(response.body);

      if (response.statusCode == 201) {
        Navigator.pushNamed(context, '/');
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['message'] ?? 'Error al registrar')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro'), backgroundColor: primaryColor,),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField('Nombre*', nameController),
              _buildTextField('Apellido Paterno*', firstNameController),
              _buildTextField('Apellido Materno', lastNameController, required: false),
              _buildTextField('Edad*', ageController, keyboardType: TextInputType.number),
              _buildTextField('Email*', emailController, keyboardType: TextInputType.emailAddress),
              _buildTextField('Contraseña*', passwordController, obscureText: true),
              _buildTextField('Teléfono', phoneController, keyboardType: TextInputType.phone, required: false),
              
              // Sección de dirección con DIPOMEX
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: cpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Código Postal*',
                        border: const OutlineInputBorder(),
                        suffixIcon: cpValid 
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Campo obligatorio';
                        if (value.length != 5) return 'Deben ser 5 dígitos';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: isSearchingCP ? null : searchCP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: isSearchingCP 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Buscar CP'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              _buildReadOnlyFieldWithController('Ciudad', cityController),
              _buildReadOnlyFieldWithController('Estado', stateController),
              
              // Selector de colonias
              if (colonies.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedColony,
                  decoration: const InputDecoration(
                    labelText: 'Colonia*',
                    border: OutlineInputBorder(),
                  ),
                  items: colonies.map((String colony) {
                    return DropdownMenuItem<String>(
                      value: colony,
                      child: Text(colony),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedColony = newValue;
                      neighborhoodController.text = newValue ?? '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor selecciona una colonia';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 10),
              
              _buildTextField('Calle*', streetController),
              Row(
                children: [
                  Expanded(child: _buildTextField('Núm Ext*', extNumberController)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField('Núm Int', intNumberController, required: false)),
                ],
              ),
              
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : createUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: isLoading 
                    ? const CircularProgressIndicator()
                    : const Text('Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyFieldWithController(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          hintText: 'Sin datos',
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {
    bool obscureText = false,
    TextInputType? keyboardType,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required ? (value) {
          if (value == null || value.isEmpty) return 'Campo obligatorio';
          return null;
        } : null,
      ),
    );
  }
}