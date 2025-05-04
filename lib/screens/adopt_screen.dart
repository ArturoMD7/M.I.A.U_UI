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

class AdoptScreen extends StatefulWidget {
  const AdoptScreen({super.key});

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

  late final String apiUrl;
  late final String baseUrl;
  late final String mediaUrl;

  @override
  void initState() {
    super.initState();
    apiUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
    baseUrl = apiUrl;
    mediaUrl = dotenv.env['MEDIA_URL'] ?? 'http://192.168.1.133:8000';
    fetchData();
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
          posts = applyFilters(processedPosts);
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
      
      if (selectedAge != null) {
        final ageStr = pet['age'].toLowerCase();
        final age = int.tryParse(ageStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        
        if (selectedAge == 'Cachorro' && (age < 0 || age > 1)) {
          return false;
        } else if (selectedAge == 'Joven' && (age < 2 || age > 6)) {
          return false;
        } else if (selectedAge == 'Adulto' && age <= 6) {
          return false;
        }
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
                          // Crear la publicación
                          final postResponse = await http.post(
                            Uri.parse("$baseUrl/posts/"),
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                            body: jsonEncode({
                              "title": "Mascota en adopción",
                              "description": descriptionController.text,
                              "postDate": DateFormat('yyyy-MM-dd').format(DateTime.now()),
                              "petId": int.parse(selectedPetId!),
                              "userId": userId,
                            }),
                          );

                          if (postResponse.statusCode == 201) {
                            // Subir imagen si se seleccionó
                            if (selectedImage != null) {
                              final postData = jsonDecode(postResponse.body);
                              final postId = postData['id'];

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

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("¡Publicación creada con éxito!")),
                            );
                            await fetchData();
                          } else {
                            throw Exception("Error al crear publicación: ${postResponse.body}");
                          }
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
        if (!snapshot.hasData) {
          return const SizedBox(); // O algún widget de carga
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
                      post['description'] ?? "Sin detalles adicionales",
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
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editPost(post['id'], post['description']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletePost(post['id']),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 10,
              children: [
                DropdownButton<String>(
                  hint: const Text("Tamaño"),
                  value: selectedSize,
                  items: ["Pequeño", "Mediano", "Grande"].map((String value) {
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
                  hint: const Text("Raza"),
                  value: selectedBreed,
                  items: ["Labrador", "Siamés", "Golden Retriever", "Persa", "Mestizo"].map((String value) {
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
        label: const Text("Publicar mascota"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}