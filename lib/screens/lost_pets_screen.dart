import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'custom_app_bar.dart';
import 'messages_screen.dart';
import 'comment_screen.dart';
import 'add_pet_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/postWidget.dart';

class LostPetsScreen extends StatefulWidget {
  final int? initialPostId;
  final bool isModal;
  const LostPetsScreen({super.key, this.initialPostId, this.isModal = false});

  @override
  _LostPetsScreenState createState() => _LostPetsScreenState();
}

class _LostPetsScreenState extends State<LostPetsScreen> {
  // Variables de estado
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';
  File? selectedImage;
  late String apiUrl;
  late String baseUrl;
  late String mediaUrl;
  final ScrollController _scrollController = ScrollController();
  bool _showFab = true; // Controla la visibilidad del FAB

  // Variables para ubicación
  List<String> estados = [];
  List<String> municipios = [];
  String? selectedEstado;
  String? selectedMunicipio;
  bool loadingEstados = false;
  bool loadingMunicipios = false;
  String? currentUserState;
  late Function(void Function()) _dialogSetState;

  @override
  void initState() {
    super.initState();
    apiUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
    baseUrl = apiUrl;
    mediaUrl = dotenv.env['MEDIA_URL'] ?? 'http://192.168.1.133:8000';

    // Configurar el listener para el scroll
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_showFab) setState(() => _showFab = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_showFab) setState(() => _showFab = true);
      }
    });

    _initializeData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

      debugPrint('Respuesta completa de estados: ${response.body}');

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
    } catch (e) {
      _dialogSetState(() {
        loadingMunicipios = false;
      });
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
      posts = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          errorMessage = "No estás autenticado. Inicia sesión primero.";
        });
        return;
      }

      final petsResponse = await http.get(
        Uri.parse("$baseUrl/filtered-pets/?status=0"),
        headers: {"Authorization": "Bearer $token"},
      );

      final postsResponse = await http.get(
        Uri.parse("$baseUrl/posts/"),
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

        if (!mounted) return;
        setState(() {
          if (currentUserState != null && currentUserState!.isNotEmpty) {
            posts = processedPosts.where((post) {
              final postState = post['state'] ?? post['pet']['state'] ?? '';
              return postState == currentUserState;
            }).toList();
          } else {
            posts = processedPosts;
          }
          isLoading = false;
        });
      } else {
        throw Exception("Error en las respuestas");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = "Error al cargar los datos: ${e.toString()}";
      });
    }
  }

  Future<void> _createLostPetPost() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getInt('user_id');

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

        final availablePets = userPets.where((pet) => pet['status'] == 0).toList();

        if (availablePets.isEmpty) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("No tienes mascotas registradas"),
              content: const Text("Registra una mascota primero para poder reportarla como perdida"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
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
              builder: (context, dialogSetState) {
                _dialogSetState = dialogSetState;

                return AlertDialog(
                  title: const Text("Reportar mascota perdida"),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedPetId,
                          hint: const Text("Selecciona una mascota"),
                          items: userPets.map((pet) {
                            return DropdownMenuItem<String>(
                              value: pet['id'].toString(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${pet['name']} (${pet['breed']})"),
                                  Text(
                                    "Estado: ${pet['status'] == 0 ? 'Perdida' : 'En adopción'}",
                                    style: TextStyle(
                                      color: pet['status'] == 0 ? Colors.red : Colors.blue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => dialogSetState(() => selectedPetId = value),
                        ),
                        const SizedBox(height: 20),

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
                            dialogSetState(() {
                              selectedEstado = value;
                              selectedMunicipio = null;
                              if (value != null) {
                                _loadMunicipios(value);
                              }
                            });
                          },
                        ),

                        const SizedBox(height: 10),

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
                              dialogSetState(() {
                                selectedMunicipio = newValue;
                              });
                            },
                          ),

                        const SizedBox(height: 20),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: "Detalles de la pérdida",
                            hintText: "¿Dónde y cuándo se perdió?",
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.image),
                          label: const Text("Agregar foto reciente"),
                          onPressed: () async {
                            final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              dialogSetState(() {
                                selectedImage = File(image.path);
                              });
                            }
                          },
                        ),
                        if (selectedImage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Image.file(selectedImage!, height: 100),
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
                          final selectedPet = userPets.firstWhere(
                                (pet) => pet['id'].toString() == selectedPetId,
                          );

                          final petUpdateData = {
                            ...selectedPet,
                            "statusAdoption": 0,
                            "state": selectedEstado,
                            "city": selectedMunicipio,
                            "petDetails": "Perdido en $selectedMunicipio, $selectedEstado. ${descriptionController.text}",
                          };

                          final petUpdateResponse = await http.put(
                            Uri.parse("$baseUrl/pets/${selectedPet['id']}/"),
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                            body: jsonEncode(petUpdateData),
                          );

                          if (petUpdateResponse.statusCode != 200) {
                            throw Exception("Error al actualizar mascota: ${petUpdateResponse.body}");
                          }

                          final postResponse = await http.post(
                            Uri.parse("$baseUrl/posts/"),
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                            body: jsonEncode({
                              "title": "Mascota perdida: ${selectedPet['name']}",
                              "description": descriptionController.text,
                              "postDate": DateFormat('yyyy-MM-dd').format(DateTime.now()),
                              "petId": selectedPet['id'],
                              "userId": userId,
                              "state": selectedEstado,
                              "city": selectedMunicipio,
                            }),
                          );

                          if (postResponse.statusCode != 201) {
                            throw Exception("Error al crear post: ${postResponse.body}");
                          }

                          final postData = jsonDecode(postResponse.body);
                          final postId = postData['id'];

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

                          final notifResponse = await http.post(
                            Uri.parse('$baseUrl/notifications/send-lost-pet/'),
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
                            const SnackBar(content: Text("Mascota reportada como perdida y notificaciones enviadas")),
                          );
                          await fetchData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: ${e.toString()}")),
                          );
                        } finally {
                          setState(() => isLoading = false);
                        }
                      },
                      child: const Text("Reportar"),
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

  Future<void> _deletePost(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión")),
      );
      return;
    }

    setState(() => isLoading = true);

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
      setState(() => isLoading = false);
    }
  }

  Widget _buildPostCard(dynamic post) {
    final pet = post['pet'];
    final images = post['images'] as List<dynamic>;
    final user = post['user'] as Map<String, dynamic>? ?? {};

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final currentUserId = snapshot.data!.getInt('user_id');

        return PostWidget(
          post: {
            ...post,
            'user_name': user['name'],
            'user_first_name': user['first_name'],
            'created_at': post['postDate'],
          },
          onDelete: user['id'] == currentUserId
              ? () async {
            final confirmed = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Eliminar publicación"),
                content: const Text("¿Estás seguro de que quieres eliminar esta publicación?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancelar"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              await _deletePost(post['id']);
            }
          }
              : null,
          onComment: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommentScreen(postId: post['id']),
              ),
            );
          },
          onMessage: () async {
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
            "Mascotas Perdidas",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (currentUserState != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Text(
                "Mostrando mascotas perdidas en $currentUserState",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                ? Center(
              child: Text(
                errorMessage.isEmpty ? "No hay mascotas perdidas reportadas" : errorMessage,
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
        onPressed: _createLostPetPost,
        label: const Text("Reportar mascota perdida"),
        icon: const Icon(Icons.add),
      )
          : null,
    );
  }
}