import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:miauuic/screens/add_pet_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'custom_app_bar.dart';
import 'messages_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'comment_screen.dart';
import 'create_pet_screen.dart';

class LostPetsScreen extends StatefulWidget {
  final int? initialPostId;
  final bool isModal;
  const LostPetsScreen({super.key, this.initialPostId, this.isModal=false});

  @override
  _LostPetsScreenState createState() => _LostPetsScreenState();
}

class _LostPetsScreenState extends State<LostPetsScreen> {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';
  File? selectedImage;
  late final String apiUrl;
  late final String baseUrl;
  late final String mediaUrl;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    apiUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
    baseUrl = apiUrl;
    mediaUrl = dotenv.env['MEDIA_URL'] ?? 'http://192.168.1.133:8000';
    fetchData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
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

      // Obtener solo mascotas con statusAdoption = 0 (perdidas)
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

        setState(() {
          posts = processedPosts;
          isLoading = false;
        });

        if (widget.initialPostId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final index = posts.indexWhere((post) => post['id'] == widget.initialPostId);
            if (index != -1 && _scrollController.hasClients) {
              _scrollController.animateTo(
                index * 400.0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          });
        }
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

  Future<void> _createLostPetPost() async {
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
        final List<dynamic> userPets = jsonDecode(response.body)
            .where((pet) => pet['statusAdoption'] == 0 || pet['statusAdoption'] == 2)
            .toList();

        if (userPets.isEmpty) {
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

        await showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
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
                          onChanged: (value) => setState(() => selectedPetId = value),
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
                              setState(() {
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
                        if (selectedPetId == null || descriptionController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Completa todos los campos")),
                          );
                          return;
                        }

                        final selectedPet = userPets.firstWhere(
                          (pet) => pet['id'].toString() == selectedPetId,
                        );

                        // 1. Actualizar estado a perdido si no lo está
                        if (selectedPet['statusAdoption'] != 0) {
                          await http.put(
                            Uri.parse("$baseUrl/pets/${selectedPet['id']}/"),
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                            body: jsonEncode({
                              ...selectedPet,
                              "statusAdoption": 0,
                            }),
                          );
                        }

                        // 2. Crear el post
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
                          }),
                        );

                        if (postResponse.statusCode != 201) {
                          throw Exception("Error al crear post: ${postResponse.body}");
                        }

                        final postData = jsonDecode(postResponse.body);
                        final postId = postData['id'];

                        // 3. Subir imagen si existe
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

                        // 4. Enviar notificaciones (VERIFICAR QUE ESTA LLAMADA SE EJECUTE)
                        print("Enviando notificación para postId: $postId");
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
                          }),
                        );

                        print("Respuesta notificaciones: ${notifResponse.statusCode} - ${notifResponse.body}");

                        Navigator.pop(context);
                        await fetchData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Mascota reportada como perdida y notificaciones enviadas")),
                        );
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
      print("Error completo: $e");
    }
  }

  Future<void> _createPostForLostPet(int petId, String description) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    final int? userId = prefs.getInt('user_id');

    if (token == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 1. Crear el post
      final postResponse = await http.post(
        Uri.parse("$baseUrl/posts/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "title": "Mascota perdida",
          "description": description,
          "postDate": DateFormat('yyyy-MM-dd').format(DateTime.now()),
          "petId": petId,
          "userId": userId,
        }),
      );

      if (postResponse.statusCode != 201) {
        throw Exception("Error al crear post: ${postResponse.body}");
      }

      final postData = jsonDecode(postResponse.body);
      final postId = postData['id'];

      // 2. Subir imagen si existe
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

        final response = await request.send();

        if (response.statusCode != 201) {
          throw Exception("Error al subir imagen");
        }
      }

      // 3. Obtener el nombre real de la mascota para la notificación
      final petResponse = await http.get(
        Uri.parse("$baseUrl/pets/$petId/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (petResponse.statusCode != 200) {
        throw Exception("Error al obtener detalles de la mascota");
      }

      final petData = jsonDecode(petResponse.body);
      final petName = petData['name'];

      // 4. Enviar notificaciones a todos los usuarios
      final notifResponse = await http.post(
        Uri.parse("$baseUrl/notifications/send-lost-pet/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "post_id": postId,
          "pet_name": petName,
          "user_id": userId,
        }),
      );

      if (notifResponse.statusCode != 201) {
        print("Error en notificación: ${notifResponse.body}");
        // No es crítico, continuamos aunque falle la notificación
      }

      // 5. Actualizar la lista
      await fetchData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Publicación creada exitosamente")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
      print("Error creando publicación: $e");
    } finally {
      setState(() {
        isLoading = false;
        selectedImage = null;
      });
    }
  }
  Widget _buildPostCard(dynamic post) {
    final pet = post['pet'];
    final images = post['images'] as List<dynamic>;
    final user = post['user'];

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }
        
        final currentUserId = snapshot.data!.getInt('user_id');
        
        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: user != null && user['profilePhoto'] != null
                          ? NetworkImage("$mediaUrl${user['profilePhoto']}")
                          : const AssetImage("assets/images/default_profile.jpg") as ImageProvider,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      user != null ? "${user['name']} ${user['first_name']}" : "Usuario desconocido",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (images.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    itemBuilder: (context, imgIndex) {
                      return Image.network(
                        "$mediaUrl${images[imgIndex]['imgURL']}",
                        fit: BoxFit.cover,
                        width: MediaQuery.of(context).size.width,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(child: Icon(Icons.error, color: Colors.red)),
                          );
                        },
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet['name'] ?? "Nombre no disponible",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text("Edad: ${pet['age'] ?? "Desconocida"}", style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 5),
                    Text("Raza: ${pet['breed'] ?? "Desconocida"}", style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 5),
                    Text("Tamaño: ${pet['size'] ?? "Desconocido"}", style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 5),
                    Text(
                      "Lugar donde se perdió: ${pet['petDetails'] ?? "Sin detalles"}",
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Descripción: ${post['description'] ?? "Sin descripción"}",
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.comment, color: Colors.blue),
                          label: const Text("Comentar"),
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
                          label: const Text("Enviar mensaje"),
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
                      ],
                    ),
                    if (user != null && user['id'] == currentUserId)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
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
                              },
                            ),
                          ],
                        ),
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
        
        final availablePets = userPets.where((pet) => pet['status'] == 0).toList();
        
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

        await showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
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
                        if (selectedPetId == null || descriptionController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Debes seleccionar una mascota y escribir una descripción")),
                          );
                          return;
                        }

                        setState(() => isLoading = true);
                        Navigator.pop(context);

                        try {
                          // 1. Crear la publicación
                          final postResponse = await http.post(
                            Uri.parse("$baseUrl/posts/"),
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                            body: jsonEncode({
                              "title": "Mascota en adopción: ${availablePets.firstWhere((pet) => pet['id'].toString() == selectedPetId)['name']}",
                              "description": descriptionController.text,
                              "postDate": DateFormat('yyyy-MM-dd').format(DateTime.now()),
                              "petId": int.parse(selectedPetId!),
                              "userId": userId,
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

                          // 3. Obtener nombre de la mascota
                          final selectedPet = availablePets.firstWhere(
                            (pet) => pet['id'].toString() == selectedPetId
                          );
                          final petName = selectedPet['name'];

                          // 4. Enviar notificaciones a todos los usuarios
                          print("Enviando notificación para mascota en adopción");
                          final notifResponse = await http.post(
                            Uri.parse('$baseUrl/notifications/send-lost-pet/'),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer $token',
                            },
                            body: jsonEncode({
                              'post_id': postId,
                              'pet_name': petName,
                              'user_id': userId,
                            }),
                          );

                          print("Respuesta notificaciones: ${notifResponse.statusCode} - ${notifResponse.body}");

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("¡Publicación creada con éxito y notificaciones enviadas!")),
                          );
                          await fetchData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: ${e.toString()}")),
                          );
                          print("Error completo: $e");
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPostWithExistingPet,
        label: const Text("Reportar mascota perdida"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}