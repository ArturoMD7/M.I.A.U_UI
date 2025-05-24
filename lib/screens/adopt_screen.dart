import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:miauuic/screens/add_pet_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'messages_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'comment_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

const Color primaryColor = Color(0xFFD68F5E);

class AdoptScreen extends StatefulWidget {
  final int? initialPostId;
  final bool isModal;
  const AdoptScreen({super.key, this.initialPostId, this.isModal=false});

  @override
  _AdoptScreenState createState() => _AdoptScreenState();
}

class _AdoptScreenState extends State<AdoptScreen> {
  List<dynamic> posts = [];
  List<dynamic> allPosts = [];
  bool isLoading = true;
  String errorMessage = '';

  String? selectedSize;
  String? selectedAge;
  String? selectedBreed;
  File? selectedImage;

  // Variables para ubicación
  List<String> estados = [];
  List<String> municipios = [];
  String? selectedEstado;
  String? selectedMunicipio;
  bool loadingEstados = false;
  bool loadingMunicipios = false;
  String? currentUserState;
  late Function(void Function()) _dialogSetState;

  late final String apiUrl;
  late final String baseUrl;
  late final String mediaUrl;

  final ScrollController _scrollController = ScrollController();
  bool _showFab = true; // Controla la visibilidad del FAB

  @override
  void initState() {
    super.initState();
    apiUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
    baseUrl = apiUrl;
    mediaUrl = dotenv.env['MEDIA_URL'] ?? 'http://192.168.1.133:8000';

    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_showFab) setState(() => _showFab = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_showFab) setState(() => _showFab = true);
      }
    });

    _initializeData();

  }

  Future<void> _initializeData() async {
    await _loadUserLocation();
    await _loadEstados();
    await fetchData();
  }

  Future<void> _loadUserLocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserState = prefs.getString('user_state');
    });
  }

  Future<void> _loadEstados() async {
    setState(() => loadingEstados = true);

    try {
      final response = await http.get(
        Uri.parse('https://api.tau.com.mx/dipomex/v1/estados'),
        headers: {
          'APIKEY': dotenv.env['DIPOMEX_API_KEY'] ?? '',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<String> estadosTemp = [];

        if (data is Map && data['estados'] != null && data['estados'] is List) {
          estadosTemp = (data['estados'] as List).map<String>((estadoMap) {
            if (estadoMap is Map && estadoMap['ESTADO'] != null) {
              return estadoMap['ESTADO'].toString();
            }
            return '';
          }).where((estado) => estado.isNotEmpty).toList();
        }

        estadosTemp = estadosTemp.toSet().toList()..sort();

        setState(() {
          estados = estadosTemp;
          if (currentUserState != null && estados.contains(currentUserState)) {
            selectedEstado = currentUserState;
          } else {
            selectedEstado = null;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar estados: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    } finally {
      setState(() => loadingEstados = false);
    }
  }

  Future<void> _loadMunicipios(String estadoNombre) async {
    if (!mounted) return;
      _dialogSetState(() {
        loadingMunicipios = true;
        municipios = [];
        selectedMunicipio = null;
      });

    try {
      if (!mounted) return;
      _dialogSetState(() {
        loadingMunicipios = true;
        municipios = [];
        selectedMunicipio = null;
      });
      // 1. Obtener ID del estado
      final estadosResponse = await http.get(
        Uri.parse('https://api.tau.com.mx/dipomex/v1/estados'),
        headers: {'APIKEY': dotenv.env['DIPOMEX_API_KEY'] ?? ''},
      );

      if (estadosResponse.statusCode != 200) {
        throw Exception('Error al obtener estados: ${estadosResponse.statusCode}');
      }

      final estadosData = jsonDecode(estadosResponse.body);
      String? estadoId;

      if (estadosData is Map && estadosData['estados'] is List) {
        final listaEstados = estadosData['estados'] as List;
        final estadoEncontrado = listaEstados.firstWhere(
          (estado) => estado is Map && 
                     estado['ESTADO']?.toString().toUpperCase() == estadoNombre.toUpperCase(),
          orElse: () => null,
        );

        if (estadoEncontrado != null && estadoEncontrado is Map) {
          estadoId = estadoEncontrado['ESTADO_ID']?.toString();
        }
      }

      if (estadoId == null) {
        throw Exception('No se encontró ID para el estado $estadoNombre');
      }

      // 2. Obtener municipios
      final municipiosResponse = await http.get(
        Uri.parse('https://api.tau.com.mx/dipomex/v1/municipios?id_estado=$estadoId'),
        headers: {'APIKEY': dotenv.env['DIPOMEX_API_KEY'] ?? ''},
      );

      if (municipiosResponse.statusCode != 200) {
        throw Exception('Error al obtener municipios: ${municipiosResponse.statusCode}');
      }

      final municipiosData = jsonDecode(municipiosResponse.body);
      
      if (municipiosData['error'] == false && municipiosData['municipios'] is List) {
        final listaMunicipios = municipiosData['municipios'] as List;
        
        final municipiosTemp = listaMunicipios.map<String>((item) {
          if (item is Map && item['MUNICIPIO'] != null) {
            return item['MUNICIPIO'].toString();
          }
          return '';
        }).where((m) => m.isNotEmpty).toList();
        
        municipiosTemp.sort();

        _dialogSetState(() {
          municipios = municipiosTemp;
          loadingMunicipios = false;
        });
      } else {
        throw Exception('Error en respuesta de municipios: ${municipiosData['message']}');
      }


        // Verificar nuevamente antes de la última actualización
      if (!mounted) return;
      _dialogSetState(() {
        municipios = municipiosData;
        loadingMunicipios = false;
      });
    } catch (e) {
      if (!mounted) return;
      _dialogSetState(() {
        loadingMunicipios = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar municipios: $e')),
      );
    }
    
  }

  Future<void> fetchData() async {
     if (!mounted) return;
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

   

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = "No estás autenticado. Inicia sesión primero.";
        });
        return;
      }

      final postsResponse = await http.get(
        Uri.parse("$baseUrl/posts/"),
        headers: {"Authorization": "Bearer $token"},
      );

      final petsResponse = await http.get(
        Uri.parse("$baseUrl/filtered-pets/?status=2"),
        headers: {"Authorization": "Bearer $token"},
      );

      final imgsResponse = await http.get(
        Uri.parse("$baseUrl/imgs-post/"),
        headers: {"Authorization": "Bearer $token"},
      );

      final usersResponse = await http.get(
        Uri.parse("$baseUrl/users/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (postsResponse.statusCode == 200 &&
          petsResponse.statusCode == 200 &&
          imgsResponse.statusCode == 200 &&
          usersResponse.statusCode == 200) {
        final List<dynamic> postsData = jsonDecode(postsResponse.body);
        final List<dynamic> petsData = jsonDecode(petsResponse.body);
        final List<dynamic> imgsData = jsonDecode(imgsResponse.body);
        final List<dynamic> usersData = jsonDecode(usersResponse.body);

        final processedPosts = postsData.map((post) {
          final petId = post['petId'];
          final pet = petsData.firstWhere(
            (pet) => pet['id'] == petId,
            orElse: () => null,
          );
          final postImages = imgsData.where((img) => img['idPost'] == post['id']).toList();
          final userId = post['userId'];
          final user = usersData.firstWhere(
            (user) => user['id'] == userId,
            orElse: () => null,
          );
          return {
            ...post,
            'pet': pet,
            'images': postImages,
            'user': user,
          };
        }).where((post) => post['pet'] != null).toList();

        setState(() {
          allPosts = processedPosts;
          // Filtrar por ubicación si hay un estado seleccionado
          if (currentUserState != null && currentUserState!.isNotEmpty) {
            posts = applyFilters(processedPosts.where((post) {
              final postState = post['state'] ?? post['pet']['state'] ?? '';
              return postState == currentUserState;
            }).toList());
          } else {
            posts = applyFilters(processedPosts);
          }
          isLoading = false;
        });
      } else {
        throw Exception("Error al cargar los datos");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error de conexión: ${e.toString()}";
      });
    }
  }

  List<dynamic> applyFilters(List<dynamic> postsToFilter) {
    return postsToFilter.where((post) {
      final pet = post['pet'];
      
      if (selectedSize != null && pet['size'] != selectedSize) {
        return false;
      }
      
      if (selectedBreed != null && !pet['breed'].toLowerCase().contains(selectedBreed!.toLowerCase())) {
        return false;
      }
      
      if (selectedAge != null && !pet['age'].toLowerCase().contains(selectedAge!.toLowerCase()) ) {
        return false;
      }
      
      return true;
    }).toList();
  }

  Future<void> _deletePost(int postId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/posts/$postId/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Publicación eliminada")),
        );
        await fetchData();
      } else {
        throw Exception("Error al eliminar: ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _editPost(int postId, String currentDescription) async {
    final descriptionController = TextEditingController(text: currentDescription);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión")),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editar publicación"),
          content: TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: "Descripción",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (descriptionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("La descripción no puede estar vacía")),
                  );
                  return;
                }

                try {
                  final response = await http.put(
                    Uri.parse("$baseUrl/posts/$postId/"),
                    headers: {
                      "Content-Type": "application/json",
                      "Authorization": "Bearer $token",
                    },
                    body: jsonEncode({
                      "description": descriptionController.text,
                    }),
                  );

                  if (response.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Publicación actualizada")),
                    );
                    await fetchData();
                    Navigator.pop(context);
                  } else {
                    throw Exception("Error al actualizar: ${response.body}");
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createPostWithExistingPet() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    final int? userId = prefs.getInt('user_id');

    if (token == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión")),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/pets/user/$userId/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> userPets = jsonDecode(response.body);
        
        // Filtrar solo mascotas con statusAdoption = 2 (Buscando familia)
        final availablePets = userPets.where((pet) => pet['status'] == 2).toList();
        
        if (availablePets.isEmpty) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("No tienes mascotas disponibles"),
              content: const Text("No tienes mascotas con estado 'Buscando familia' para publicar.\n\nPuedes cambiar el estado de tus mascotas en la sección 'Mis Mascotas'."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddPetScreen()),
                    ).then((_) => fetchData());
                  },
                  child: const Text("Crear mascota"),
                ),
              ],
            ),
          );
          return;
        }

        String? selectedPetId;
        final descriptionController = TextEditingController();
        File? selectedImage;
        String? selectedEstado;
        String? selectedMunicipio;

        await showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                _dialogSetState = setState;
                
                return AlertDialog(
                  title: const Text("Publicar mascota en adopción"),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Mascotas disponibles para adopción:",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedPetId,
                          hint: const Text("Selecciona una mascota"),
                          items: availablePets.map((pet) {
                            return DropdownMenuItem<String>(
                              value: pet['id'].toString(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${pet['name']} - ${pet['breed']}"),
                                  Text("Edad: ${pet['age']}",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => selectedPetId = value),
                        ),
                        const SizedBox(height: 20),
                        
                        // Selector de estado
                        DropdownButtonFormField<String>(
                          value: selectedEstado,
                          hint: loadingEstados 
                              ? const Text("Cargando...")
                              : const Text("Selecciona estado"),
                          items: loadingEstados
                              ? []
                              : estados.map((estado) {
                                  return DropdownMenuItem<String>(
                                    value: estado,
                                    child: Text(estado),
                                  );
                                }).toList(),
                          onChanged: loadingEstados
                              ? null
                              : (value) {
                                  setState(() {
                                    selectedEstado = value;
                                    selectedMunicipio = null;
                                    if (value != null) {
                                      _loadMunicipios(value);
                                    }
                                  });
                                },
                        ),

                        const SizedBox(height: 10),

                        // Selector de municipio
                        if (selectedEstado != null)
                          DropdownButtonFormField<String>(
                            value: selectedMunicipio,
                            hint: loadingMunicipios
                                ? const Text('Cargando municipios...')
                                : const Text('Selecciona un municipio'),
                            items: loadingMunicipios || municipios.isEmpty
                                ? []
                                : municipios.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                            onChanged: loadingMunicipios || municipios.isEmpty
                                ? null
                                : (newValue) {
                                    setState(() {
                                      selectedMunicipio = newValue;
                                    });
                                  },
                          ),

                        const SizedBox(height: 20),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: "Descripción de la publicación",
                            border: OutlineInputBorder(),
                            hintText: "Describe a la mascota y las condiciones de adopción...",
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.image),
                          label: const Text("Seleccionar Imagen"),
                          onPressed: () async {
                            final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              setState(() {
                                selectedImage = File(image.path);
                              });
                            }
                          },
                        ),
                        if (selectedImage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              children: [
                                Image.file(selectedImage!, height: 100),
                                TextButton(
                                  onPressed: () => setState(() => selectedImage = null),
                                  child: const Text("Quitar imagen", 
                                    style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedPetId == null || 
                            descriptionController.text.isEmpty ||
                            selectedEstado == null ||
                            selectedMunicipio == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Completa todos los campos")),
                          );
                          return;
                        }

                        setState(() => isLoading = true);
                        Navigator.pop(context);

                        try {
                          final selectedPet = availablePets.firstWhere(
                            (pet) => pet['id'].toString() == selectedPetId
                          );

                          // 1. Crear la publicación
                          final postResponse = await http.post(
                            Uri.parse("$baseUrl/posts/"),
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                            body: jsonEncode({
                              "title": "Mascota en adopción: ${selectedPet['name']}",
                              "description": descriptionController.text,
                              "postDate": DateFormat('yyyy-MM-dd').format(DateTime.now()),
                              "petId": int.parse(selectedPetId!),
                              "userId": userId,
                              "state": selectedEstado,
                              "city": selectedMunicipio,
                            }),
                          );

                          if (postResponse.statusCode != 201) {
                            throw Exception("Error al crear publicación: ${postResponse.body}");
                          }

                          final postData = jsonDecode(postResponse.body);
                          final postId = postData['id'];

                          // 2. Subir imagen si se seleccionó
                          if (selectedImage != null) {
                            final request = http.MultipartRequest(
                              "POST", 
                              Uri.parse("$baseUrl/imgs-post/")
                            )
                              ..headers['Authorization'] = 'Bearer $token'
                              ..fields['idPost'] = postId.toString()
                              ..files.add(await http.MultipartFile.fromPath(
                                'imgURL',
                                selectedImage!.path,
                              ));

                            final imgResponse = await request.send();
                            if (imgResponse.statusCode != 201) {
                              throw Exception("Error al subir imagen");
                            }
                          }

                          // 3. Enviar notificaciones a todos los usuarios
                          final notifResponse = await http.post(
                            Uri.parse('$baseUrl/notifications/send-adoption-pet/'),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer $token',
                            },
                            body: jsonEncode({
                              'post_id': postId,
                              'pet_name': selectedPet['name'],
                              'user_id': userId,
                              'state': selectedEstado,
                              'city': selectedMunicipio,
                            }),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("¡Publicación creada y notificaciones enviadas!")),
                          );
                          await fetchData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: ${e.toString()}")),
                          );
                        } finally {
                          setState(() {
                            isLoading = false;
                            selectedImage = null;
                          });
                        }
                      },
                      child: const Text("Publicar"),
                    ),
                  ],
                );
              },
            );
          },
        );
      } else {
        throw Exception("Error al obtener mascotas: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Widget _buildPostCard(dynamic post) {
    final pet = post['pet'];
    final images = post['images'] as List<dynamic>;
    final user = post['user'];

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final currentUserId = snapshot.data!.getInt('user_id');

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          elevation: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user != null ? "${user['name']} ${user['first_name']}" : "Usuario",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (post['postDate'] != null)
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(post['postDate'])),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (user != null && user['id'] == currentUserId)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePost(post['id']),
                      ),
                  ],
                ),
              ),

              // Post content
              if (post['description'] != null && post['description'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(post['description']),
                ),

              // Pet info
              if (pet != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(
                        'Mascota: ${pet['name'] ?? 'No especificado'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Edad: ${pet['age'] ?? 'Desconocida'}'),
                      Text('Tipo: ${pet['breed'] ?? 'Desconocida'}'),
                      Text('Tamaño: ${pet['size'] ?? 'Desconocido'}'),
                      if (post['city'] != null || post['state'] != null)
                        Text(
                          'Ubicación: ${post['city'] ?? ''}, ${post['state'] ?? ''}',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),

              // Post images - Esta es la parte clave que cambiamos
              if (images.isNotEmpty)
                Column(
                  children: images.map((image) {
                    final imageUrl = "$mediaUrl${image['imgURL']}";
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: MediaQuery.of(context).size.width - 32,
                          height: MediaQuery.of(context).size.width * 0.8,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            width: MediaQuery.of(context).size.width - 32,
                            height: MediaQuery.of(context).size.width * 0.8,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            width: MediaQuery.of(context).size.width - 32,
                            height: MediaQuery.of(context).size.width * 0.8,
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.comment, color: Colors.blue),
                      label: const Text('Comentar'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentScreen(postId: post['id']),
                          ),
                        );
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.message, color: Colors.green),
                      label: const Text('Mensaje'),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        if (prefs.getInt('user_id') == null || prefs.getString('jwt_token') == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Debes iniciar sesión")),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MessagesScreen(
                              initialRecipientId: user['id'],
                              initialRecipientName: user['name'] ?? 'Usuario',
                            ),
                          ),
                        );
                      },
                    ),
                    if (user != null && user['id'] == currentUserId)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editPost(post['id'], post['description']),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            "Mascotas en Adopción",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (currentUserState != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Text(
                "Mostrando mascotas en adopción en $currentUserState",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 10,
              children: [
                DropdownButton<String>(
                  hint: const Text("Tamaño"),
                  value: selectedSize,
                  items: ["Pequeno", "Mediano", "Grande"].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedSize = newValue;
                      posts = applyFilters(allPosts);
                    });
                  },
                ),
                DropdownButton<String>(
                  hint: const Text("Edad"),
                  value: selectedAge,
                  items: ["Cachorro (0-1)", "Joven (2-6)", "Adulto (+6)"].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value.split(' ')[0],
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedAge = newValue;
                      posts = applyFilters(allPosts);
                    });
                  },
                ),
                DropdownButton<String>(
                  hint: const Text("Tipo"),
                  value: selectedBreed,
                  items: ["Perro", "Gato", "Roedor", "Ave", "Otro"].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedBreed = newValue;
                      posts = applyFilters(allPosts);
                    });
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedSize = null;
                      selectedAge = null;
                      selectedBreed = null;
                      posts = applyFilters(allPosts);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Limpiar filtros"),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                ? Center(
              child: Text(
                errorMessage.isEmpty ? "No hay mascotas que coincidan con los filtros" : errorMessage,
                style: const TextStyle(fontSize: 18),
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchData,
              child: ListView.builder(
                controller: _scrollController, 
                padding: const EdgeInsets.all(10),
                itemCount: posts.length,
                itemBuilder: (context, index) => _buildPostCard(posts[index]),
              ),
            ),
          ),
        ],
      ),
        floatingActionButton: _showFab
            ? FloatingActionButton.extended(
          backgroundColor: primaryColor,

          onPressed: _createPostWithExistingPet,
          label: const Text("Publicar mascota"),
          icon: const Icon(Icons.add),
        )
            : null,
    );
  }
}