import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'chat_screen.dart';
import 'comment_screen.dart';
import 'messages_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LostPetsScreen extends StatefulWidget {
  final int? initialPostId;
  const LostPetsScreen({super.key, this.initialPostId});

  @override
  _LostPetsScreenState createState() => _LostPetsScreenState();
}

class _LostPetsScreenState extends State<LostPetsScreen> {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';
  File? selectedImage;
  late SharedPreferences prefs;
  late final String apiUrl;
  late final String baseUrl;
  late final String mediaUrl;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    apiUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
    baseUrl = "$apiUrl";
    mediaUrl = dotenv.env['MEDIA_URL'] ?? 'http://192.168.1.133:8000';
    _initPrefs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    fetchData();
  }

  Future<void> fetchData() async {
    String postsUrl = "$baseUrl/posts/";
    String petsUrl = "$baseUrl/filtered-pets/?status=0";
    String imgsUrl = "$baseUrl/imgs-post/";
    String usersUrl = "$baseUrl/users/";

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = "No estás autenticado. Inicia sesión primero.";
      });
      return;
    }

    try {
      final postsResponse = await http.get(
        Uri.parse(postsUrl),
        headers: {"Authorization": "Bearer $token"},
      );

      final petsResponse = await http.get(
        Uri.parse(petsUrl),
        headers: {"Authorization": "Bearer $token"},
      );

      final imgsResponse = await http.get(
        Uri.parse(imgsUrl),
        headers: {"Authorization": "Bearer $token"},
      );

      final usersResponse = await http.get(
        Uri.parse(usersUrl),
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

        final filteredPosts = postsData.where((post) {
          final petId = post['petId'];
          final pet = petsData.firstWhere(
            (pet) => pet['id'] == petId && pet['statusAdoption'] == 0,
            orElse: () => null,
          );
          return pet != null;
        }).map((post) {
          final petId = post['petId'];
          final pet = petsData.firstWhere((pet) => pet['id'] == petId);
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
        }).toList();

        setState(() {
          posts = filteredPosts;
          isLoading = false;
        });

        // Scroll to initial post after data is loaded
        if (widget.initialPostId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final index = posts.indexWhere((post) => post['id'] == widget.initialPostId);
            if (index != -1 && _scrollController.hasClients) {
              _scrollController.animateTo(
                index * 400.0, // Approximate height of each post card
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Error al cargar los datos";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error de conexión: $e";
      });
    }
  }

  Future<void> reportLostPet(
    String name,
    String age,
    String breed,
    String size,
    String details,
    String description,
  ) async {
    String petUrl = "$baseUrl/pets/";
    String postUrl = "$baseUrl/posts/";
    String imgUrl = "$baseUrl/imgs-post/";

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    final int? userId = prefs.getInt('user_id');

    if (token == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No estás autenticado. Inicia sesión primero.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Crear la mascota perdida
      final petResponse = await http.post(
        Uri.parse(petUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "name": name,
          "age": age,
          "breed": breed,
          "size": size,
          "petDetails": details,
          "userId": userId,
          "statusAdoption": 0,
          "qrId": 1,
        }),
      );

      if (petResponse.statusCode != 201) {
        throw Exception("Error al crear mascota: ${petResponse.body}");
      }

      final petData = jsonDecode(petResponse.body);
      final petId = petData['id'];

      // Formatear la fecha
      final String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Crear el post
      final postResponse = await http.post(
        Uri.parse(postUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "title": "Mascota perdida: $name",
          "description": description,
          "postDate": formattedDate,
          "petId": petId,
          "userId": userId,
        }),
      );

      if (postResponse.statusCode != 201) {
        throw Exception("Error al crear post: ${postResponse.body}");
      }

      final postData = jsonDecode(postResponse.body);
      final postId = postData['id'];

      // Enviar notificación a todos los usuarios
      try {
        final notificationResponse = await http.post(
          Uri.parse("$baseUrl/notifications/send-lost-pet/"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "post_id": postId,
            "pet_name": name,
            "user_id": userId,
          }),
        );

        if (notificationResponse.statusCode != 201) {
          print("Error al enviar notificaciones: ${notificationResponse.body}");
        }
      } catch (e) {
        print("Error enviando notificaciones: $e");
      }

      // Subir la imagen si existe
      if (selectedImage != null) {
        final request = http.MultipartRequest("POST", Uri.parse(imgUrl))
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['idPost'] = postId.toString()
          ..files.add(
            await http.MultipartFile.fromPath(
              'imgURL',
              selectedImage!.path,
            ),
          );

        final response = await request.send();

        if (response.statusCode != 201) {
          final responseBody = await response.stream.bytesToString();
          throw Exception("Error al subir imagen: $responseBody");
        }
      }

      // Actualizar la lista
      await fetchData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Mascota reportada exitosamente")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      print("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
        selectedImage = null;
      });
    }
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  void showReportLostPetModal() {
    TextEditingController nameController = TextEditingController();
    TextEditingController breedController = TextEditingController();
    TextEditingController detailsController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    String? selectedSize;
    String? selectedAge;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Reportar mascota perdida"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Nombre"),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      hint: const Text("Edad"),
                      value: selectedAge,
                      items: ["Cachorro", "Joven", "Adulto"].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          selectedAge = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: breedController,
                      decoration: const InputDecoration(labelText: "Raza"),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
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
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: detailsController,
                      decoration: const InputDecoration(
                        labelText: "Lugar donde se perdió",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: "Descripción"),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text("Seleccionar Imagen"),
                      onPressed: pickImage,
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
                    if (nameController.text.isEmpty ||
                        selectedAge == null ||
                        breedController.text.isEmpty ||
                        selectedSize == null ||
                        detailsController.text.isEmpty ||
                        descriptionController.text.isEmpty ||
                        selectedImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Por favor, completa todos los campos"),
                        ),
                      );
                      return;
                    }

                    await reportLostPet(
                      nameController.text,
                      selectedAge!,
                      breedController.text,
                      selectedSize!,
                      detailsController.text,
                      descriptionController.text,
                    );
                    Navigator.pop(context);
                  },
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Reportar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPostCard(dynamic post) {
    final pet = post['pet'];
    final images = post['images'] as List<dynamic>;
    final user = post['user'];

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
                      : const AssetImage("assets/images/default_profile.jpg")
                          as ImageProvider,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  user != null
                      ? "${user['name']} ${user['first_name']}"
                      : "Usuario desconocido",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                  final imageUrl = "$mediaUrl${images[imgIndex]['imgURL']}";
                  return Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.red),
                        ),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Edad: ${pet['age'] ?? "Desconocida"}",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  "Raza: ${pet['breed'] ?? "Desconocida"}",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  "Tamaño: ${pet['size'] ?? "Desconocido"}",
                  style: const TextStyle(fontSize: 14),
                ),
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
                            builder: (context) => CommentScreen(
                              postId: post['id'],
                            ),
                          ),
                        );
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.message, color: Colors.green),
                      label: const Text("Enviar mensaje"),
                      onPressed: () async {
                        final String? token = prefs.getString('jwt_token');
                        final int? userId = prefs.getInt('user_id');

                        if (token == null || userId == null || user == null) {
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
                              initialRecipientName:
                                  '${user['name']} ${user['first_name']}',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                    ? Center(
                        child: Text(
                          errorMessage.isEmpty
                              ? "No hay mascotas perdidas cerca de tu ubicación"
                              : errorMessage,
                          style: const TextStyle(fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(10),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          return _buildPostCard(posts[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showReportLostPetModal,
        label: const Text("Perdí a mi mascota"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}