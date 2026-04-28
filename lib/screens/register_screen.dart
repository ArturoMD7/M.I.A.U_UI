import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

const Color primaryColor = Color(0xFFD68F5E);

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

  String get apiUrl => apiService.baseUrl;
  String get zipCodeApiUrl => apiService.zipCodeApiUrl;

  Future<void> searchCP() async {
    final cp = cpController.text.trim();

    // Ocultar teclado al iniciar la búsqueda
    FocusManager.instance.primaryFocus?.unfocus();

    if (cp.isEmpty || cp.length != 5 || int.tryParse(cp) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un código postal válido (5 dígitos)'),
        ),
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
      cityController.clear();
      stateController.clear();
    });

    try {
      final url = Uri.parse('$zipCodeApiUrl/codigo-postal/$cp');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 20))
          .catchError((error) {
            throw 'Error de conexión: $error';
          });

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);

        // Accedemos a la llave 'data' según la estructura de la API
        final List<dynamic> dataList = decodedData['data'] ?? [];

        if (dataList.isNotEmpty) {
          setState(() {
            // Mapeo exacto de los campos de la API
            state = dataList[0]['d_estado'];

            // Si d_ciudad viene vacío, usamos D_mnpio (municipio)
            final String rawCity = dataList[0]['d_ciudad'] ?? '';
            city = rawCity.isNotEmpty ? rawCity : dataList[0]['D_mnpio'];

            // Extraemos las colonias de 'd_asenta'
            colonies =
                dataList.map<String>((item) {
                  return item['d_asenta'].toString();
                }).toList();

            cpValid = true;
            cityController.text = city ?? '';
            stateController.text = state ?? '';
          });

          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (_) => AlertDialog(
                    title: const Text('Datos encontrados'),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ciudad/Municipio: $city'),
                          Text('Estado: $state'),
                          const SizedBox(height: 10),
                          const Text(
                            'Selecciona tu colonia en el formulario.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Entendido'),
                      ),
                    ],
                  ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se encontró información para este código postal.',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error del servidor: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isSearchingCP = false);
    }
  }

  Future<void> createUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!cpValid || selectedColony == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor verifica tu código postal y selecciona una colonia',
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await apiService.post(
        '/users/',
        body: {
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
        },
        requiresAuth: false,
      );

      if (result.success) {
        Navigator.pushNamed(context, '/');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Error al registrar')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField('Nombre*', nameController),
              _buildTextField('Apellido Paterno*', firstNameController),
              _buildTextField(
                'Apellido Materno',
                lastNameController,
                required: false,
              ),
              _buildTextField(
                'Edad*',
                ageController,
                keyboardType: TextInputType.number,
              ),
              _buildTextField(
                'Email*',
                emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              _buildTextField(
                'Contraseña*',
                passwordController,
                obscureText: true,
              ),
              _buildTextField(
                'Teléfono',
                phoneController,
                keyboardType: TextInputType.phone,
                required: false,
              ),

              // Sección de dirección
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: cpController,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      decoration: InputDecoration(
                        labelText: 'Código Postal*',
                        border: const OutlineInputBorder(),
                        suffixIcon:
                            cpValid
                                ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                                : null,
                      ),
                      onChanged: (value) {
                        if (value.length == 5) {
                          searchCP();
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Campo obligatorio';
                        }
                        if (value.length != 5) return 'Deben ser 5 dígitos';
                        return null;
                      },
                    ),
                  ),
                  // const SizedBox(width: 10),
                  // ElevatedButton(
                  //   onPressed: isSearchingCP ? null : searchCP,
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: primaryColor,
                  //     foregroundColor: Colors.white,
                  //   ),
                  //   child:
                  //       isSearchingCP
                  //           ? const SizedBox(
                  //             width: 20,
                  //             height: 20,
                  //             child: CircularProgressIndicator(
                  //               strokeWidth: 2,
                  //               color: Colors.white,
                  //             ),
                  //           )
                  //           : const Text('Buscar CP'),
                  // ),
                ],
              ),
              const SizedBox(height: 10),

              _buildReadOnlyFieldWithController(
                'Ciudad/Municipio',
                cityController,
              ),
              _buildReadOnlyFieldWithController('Estado', stateController),

              // Selector de colonias
              if (colonies.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedColony,
                  isExpanded:
                      true, // Evita errores si el nombre de la colonia es muy largo
                  decoration: const InputDecoration(
                    labelText: 'Colonia*',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      colonies.map((String colony) {
                        return DropdownMenuItem<String>(
                          value: colony,
                          child: Text(colony, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    // Ocultar teclado al seleccionar colonia
                    FocusManager.instance.primaryFocus?.unfocus();

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
                  Expanded(
                    child: _buildTextField('Núm Ext*', extNumberController),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      'Núm Int',
                      intNumberController,
                      required: false,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : createUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                child:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'Registrarse',
                          style: TextStyle(fontSize: 16),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyFieldWithController(
    String label,
    TextEditingController controller,
  ) {
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
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
        validator:
            required
                ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obligatorio';
                  }
                  return null;
                }
                : null,
      ),
    );
  }
}
