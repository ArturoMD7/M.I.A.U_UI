import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:miauuic/screens/chat_screen.dart';

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
  String? neighborhood;
  bool isLoading = false;
  bool isSearchingCP = false;
  bool cpValid = false;

  // Obtener variables de entorno
  String get apiUrl => dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000';
  String get copomexToken => dotenv.env['COPOMEX_TOKEN'] ?? '';
  String get copomexUrl => dotenv.env['COPOMEX_URL'] ?? 'https://api.copomex.com/query';

  Future<void> searchCP() async {
  final cp = cpController.text.trim();

  if (cp.isEmpty || cp.length != 5 || int.tryParse(cp) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ingresa un código postal válido (5 dígitos)')),
    );
    return;
  }

  setState(() {
    isSearchingCP = true;
    cpValid = false;
    city = null;
    state = null;
    neighborhood = null;
  });

  late String tokenCopo = dotenv.env['COPOMEX_TOKEN'] ?? 'pruebas';

  try {
    final url = Uri.parse('https://api.copomex.com/query/info_cp/$cp?token=$tokenCopo');
    final response = await http.get(url);

    print('--- RESPUESTA COPOMEX ---');
    print(response.body);

    if (response.statusCode == 200) {
      final List<dynamic> dataList = jsonDecode(response.body);

      if (dataList.isNotEmpty) {
        final firstResponse = dataList.firstWhere(
          (element) => element['error'] == false,
          orElse: () => null,
        );

        if (firstResponse != null) {
          final resp = firstResponse['response'];

          setState(() {
            city = resp['municipio'] ?? resp['ciudad'];
            state = resp['estado'];
            neighborhood = dataList.map((e) => e['response']['asentamiento']).join(', ');
            cpValid = true;
          });

          if (mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('Datos encontrados'),
                content: Text('Ciudad: $city\nEstado: $state\nColonias: $neighborhood'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cerrar'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se encontró información válida.')),
      );
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

Future<void> _tryNonSimplifiedCP() async {
  try {
    final response = await http.get(
      Uri.parse('$copomexUrl/info_cp/${cpController.text}?token=$copomexToken'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> dataList = jsonDecode(response.body);
      if (dataList.isNotEmpty && dataList[0]['error'] == false) {
        // Procesar respuesta no simplificada (array de colonias)
        final asentamientos = dataList.map<String>((item) =>
            item['response']['asentamiento'].toString()).toList();

        setState(() {
          city = dataList[0]['response']['municipio'] ?? dataList[0]['response']['ciudad'];
          state = dataList[0]['response']['estado'];
          neighborhood = asentamientos.join(', ');
          cpValid = true;

          cityController.text = city ?? '';
          stateController.text = state ?? '';
          neighborhoodController.text = neighborhood ?? '';
        });

      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al procesar la respuesta del CP: $e')),
    );
  }
}

  Future<void> createUser() async {
  if (!_formKey.currentState!.validate()) return;
  if (!cpValid) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Por favor verifica tu código postal')),
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
        'last_name': lastNameController.text, // Optional in model
        'age': int.parse(ageController.text),
        'email': emailController.text,
        'password': passwordController.text,
        'phone_number': phoneController.text, // Optional in model
        'street': streetController.text, // Maps to address in REQUIRED_FIELDS but optional in model
        'neighborhood': neighborhoodController.text, // Optional in model
        'cp': cpController.text, // Optional in model
        'city': cityController.text, // Optional in model
        'state': stateController.text, // Optional in model
        'country': 'México', // Default value in model
        // Fields not included in the model:
        // 'ext_number', 'int_number' - these should probably be part of the 'street' or 'address' field
      }),
    );

    if (response.statusCode == 201) {
      Navigator.pushNamed(context, '/login');
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
      appBar: AppBar(title: Text('Registro')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
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
              
              // Sección de dirección con COPOMEX
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: cpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Código Postal*',
                        border: OutlineInputBorder(),
                        suffixIcon: cpValid 
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : null,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Campo obligatorio';
                        if (value.length != 5) return 'Deben ser 5 dígitos';
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: isSearchingCP ? null : searchCP,
                    child: isSearchingCP 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Buscar CP'),
                  ),
                ],
              ),
              SizedBox(height: 10),
              
              _buildReadOnlyFieldWithController('Ciudad', cityController),
              _buildReadOnlyFieldWithController('Estado', stateController),
              _buildReadOnlyFieldWithController('Colonia', neighborhoodController),

              
              _buildTextField('Calle*', streetController),
              Row(
                children: [
                  Expanded(child: _buildTextField('Núm Ext*', extNumberController)),
                  SizedBox(width: 10),
                  Expanded(child: _buildTextField('Núm Int', intNumberController, required: false)),
                ],
              ),
              
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : createUser,
                child: isLoading 
                    ? CircularProgressIndicator()
                    : Text('Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyFieldWithController(String label, TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
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
      padding: EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: required ? (value) {
          if (value == null || value.isEmpty) return 'Campo obligatorio';
          return null;
        } : null,
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}