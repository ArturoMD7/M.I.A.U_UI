import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';

const String baseUrl = "http://192.168.1.64:8000";

class LostPetsScreen extends StatefulWidget {
  const LostPetsScreen({super.key});

  @override
  _LostPetsScreenState createState() => _LostPetsScreenState();
}

class _LostPetsScreenState extends State<LostPetsScreen> {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';

  String? selectedSize;
  String? selectedBreed;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    const String postsUrl = "$baseUrl/api/posts/";
    const String petsUrl = "$baseUrl/api/pets/";
    const String imgsUrl = "$baseUrl/api/imgs-post/";
    const String usersUrl = "$baseUrl/api/users/";

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

        // Filtrar solo mascotas perdidas (statusAdoption = 0)
        final filteredPosts = postsData
            .where((post) {
          final petId = post['petId'];
          final pet = petsData.firstWhere(
                (pet) => pet['id'] == petId && pet['statusAdoption'] == 0,
            orElse: () => null,
          );
          return pet != null;
        })
            .map((post) {
          final petId = post['petId'];
          final pet = petsData.firstWhere((pet) => pet['id'] == petId);
          final postImages =
          imgsData.where((img) => img['idPost'] == post['id']).toList();
          final userId = post['userId'];
          final user = usersData.firstWhere((user) => user['id'] == userId, orElse: () => null);
          return {...post, 'pet': pet, 'images': postImages, 'user': user};
        })
            .toList();

        setState(() {
          posts = filteredPosts;
          isLoading = false;
        });
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
    const String petUrl = "$baseUrl/api/pets/";
    const String postUrl = "$baseUrl/api/posts/";
    const String imgUrl = "$baseUrl/api/imgs-post/";

    // Recuperar el token JWT y el ID del usuario autenticado
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    final int? userId = prefs.getInt('user_id'); // Recuperar el userId

    if (token == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No estás autenticado. Inicia sesión primero.")),
      );
      return;
    }

    setState(() {
      isLoading = true; // Activar indicador de carga
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
          "userId": userId, // Usar el ID del usuario autenticado
          "statusAdoption": 0, // Estado LOST
          "qrId": 1, // Asignar un código QR por defecto
        }),
      );

      if (petResponse.statusCode == 201) {
        final petData = jsonDecode(petResponse.body);
        final petId = petData['id'];

        // Formatear la fecha en YYYY-MM-DD
        final String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

        // Crear el post asociado a la mascota perdida
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
            "userId": userId, // Usar el ID del usuario autenticado
          }),
        );

        if (postResponse.statusCode == 201 && selectedImage != null) {
          final postData = jsonDecode(postResponse.body);
          final postId = postData['id'];

          // Subir la imagen asociada al post
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

          if (response.statusCode == 201) {
            print("Imagen subida exitosamente");
            fetchData(); // Actualizar la lista de publicaciones
          } else {
            final responseBody = await response.stream.bytesToString();
            print("Error al subir la imagen: ${response.statusCode}, $responseBody");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error al subir la imagen: $responseBody")),
            );
          }
        } else {
          print("Error en postResponse: ${postResponse.body}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al crear el post: ${postResponse.body}")),
          );
        }
      } else {
        print("Error en petResponse: ${petResponse.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al reportar la mascota: ${petResponse.body}")),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        isLoading = false; // Desactivar indicador de carga
      });
    }
  }

  // Selector de imagen desde galería o cámara
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
        return AlertDialog(
          title: const Text("Reportar mascota perdida"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nombre"),
                ),
                DropdownButton<String>(
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
                TextField(
                  controller: breedController,
                  decoration: const InputDecoration(labelText: "Raza"),
                ),
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
                    });
                  },
                ),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: "Lugar donde se perdió",
                  ),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: "Descripción"),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text("Seleccionar Imagen"),
                  onPressed: pickImage,
                ),
                if (selectedImage != null)
                  Image.file(selectedImage!, height: 100),
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
                    SnackBar(content: Text("Por favor, completa todos los campos")),
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
                  ? CircularProgressIndicator(color: Colors.white)
                  : const Text("Reportar"),
            ),
          ],
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
              padding: const EdgeInsets.all(10),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final pet = post['pet'];
                final images = post['images'] as List<dynamic>;
                final user = post['user'];

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mostrar el nombre y la foto del usuario
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: user != null && user['profilePhoto'] != null
                                  ? NetworkImage("$baseUrl${user['profilePhoto']}")
                                  : AssetImage("assets/images/default_profile.jpg") as ImageProvider,
                              radius: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              user != null ? "${user['name']} ${user['first_name']}" : "Usuario desconocido",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Mostrar las imágenes de la publicación
                      if (images.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (context, imgIndex) {
                              final imageUrl = "$baseUrl${images[imgIndex]['imgURL']}";
                              return Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: MediaQuery.of(context).size.width,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.red,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      // Resto de la información de la publicación
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
                                  icon: const Icon(
                                    Icons.comment,
                                    color: Colors.blue,
                                  ),
                                  label: const Text("Comentar"),
                                  onPressed: () {},
                                ),
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.message,
                                    color: Colors.green,
                                  ),
                                  label: const Text("Enviar mensaje"),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
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