import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'custom_app_bar.dart';

class AdoptScreen extends StatefulWidget {
  const AdoptScreen({super.key});

  @override
  _AdoptScreenState createState() => _AdoptScreenState();
}

class _AdoptScreenState extends State<AdoptScreen> {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';

  String? selectedSize;
  String? selectedAge;
  String? selectedBreed;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    const String postsUrl = "http://192.168.1.95:8000/api/posts/";
    const String petsUrl = "http://192.168.1.95:8000/api/pets/";
    const String imgsUrl = "http://192.168.1.95:8000/api/imgs-post/";

    try {
      final postsResponse = await http.get(Uri.parse(postsUrl));
      final petsResponse = await http.get(Uri.parse(petsUrl));
      final imgsResponse = await http.get(Uri.parse(imgsUrl));

      if (postsResponse.statusCode == 200 &&
          petsResponse.statusCode == 200 &&
          imgsResponse.statusCode == 200) {
        final List<dynamic> postsData = jsonDecode(postsResponse.body);
        final List<dynamic> petsData = jsonDecode(petsResponse.body);
        final List<dynamic> imgsData = jsonDecode(imgsResponse.body);

        final filteredPosts =
            postsData
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
                      imgsData
                          .where((img) => img['idPost'] == post['id'])
                          .toList();
                  return {...post, 'pet': pet, 'images': postImages};
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

  void showPublishPetModal() {
    TextEditingController nameController = TextEditingController();
    TextEditingController ageController = TextEditingController();
    TextEditingController breedController = TextEditingController();
    TextEditingController detailsController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    String? selectedSize;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Publicar mascota en adopción"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nombre"),
                ),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Edad"),
                ),
                TextField(
                  controller: breedController,
                  decoration: const InputDecoration(labelText: "Raza"),
                ),
                DropdownButton<String>(
                  hint: const Text("Tamaño"),
                  value: selectedSize,
                  items:
                      ["Pequeño", "Mediano", "Grande"].map((String value) {
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
                    labelText: "Detalles adicionales",
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
                await publishPet(
                  nameController.text,
                  int.tryParse(ageController.text) ?? 0,
                  breedController.text,
                  selectedSize ?? "Desconocido",
                  detailsController.text,
                  descriptionController.text,
                );
                Navigator.pop(context);
              },
              child: const Text("Publicar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> publishPet(
    String name,
    int age,
    String breed,
    String size,
    String details,
    String description,
  ) async {
    const String petUrl = "http://192.168.1.95:8000/api/pets/";
    const String postUrl = "http://192.168.1.95:8000/api/posts/";
    const String imgUrl = "http://192.168.1.95:8000/api/imgs-post/";

    try {
      final petResponse = await http.post(
        Uri.parse(petUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "age": age,
          "breed": breed,
          "size": size,
          "petDetails": details,
          "userId": 1,
          "statusAdoption": 0,
          "qrId": 1,
        }),
      );

      if (petResponse.statusCode == 201) {
        final petData = jsonDecode(petResponse.body);
        final petId = petData['id'];

        final postResponse = await http.post(
          Uri.parse(postUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "title": "Mascota en adopción: $name",
            "description": description,
            "postDate": DateTime.now().toIso8601String(),
            "petId": petId,
            "userId": 1,
          }),
        );

        if (postResponse.statusCode == 201 && selectedImage != null) {
          final postData = jsonDecode(postResponse.body);
          final postId = postData['id'];

          final request =
              http.MultipartRequest("POST", Uri.parse(imgUrl))
                ..fields['idPost'] = postId.toString()
                ..files.add(
                  await http.MultipartFile.fromPath(
                    'imgURL',
                    selectedImage!.path,
                  ),
                );

          await request.send();
          fetchData();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Función para aplicar los filtros
  void applyFilters() {
    setState(() {
      isLoading = true;
    });

    fetchData().then((_) {
      setState(() {
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            "Adopta una mascota",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 10,
              children: [
                DropdownButton<String>(
                  hint: const Text("Tamaño"),
                  value: selectedSize,
                  items:
                      ["Pequeño", "Mediano", "Grande"].map((String value) {
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
                DropdownButton<String>(
                  hint: const Text("Edad"),
                  value: selectedAge,
                  items:
                      ["Cachorro", "Joven", "Adulto"].map((String value) {
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
                DropdownButton<String>(
                  hint: const Text("Raza"),
                  value: selectedBreed,
                  items:
                      ["Labrador", "Siamés", "Golden Retriever"].map((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedBreed = newValue;
                    });
                  },
                ),
                ElevatedButton(
                  onPressed: applyFilters,
                  child: const Text("Aplicar filtros"),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                isLoading
                    ? const Center(
                      child: CircularProgressIndicator(),
                    ) // Muestra un indicador de carga
                    : posts.isEmpty
                    ? Center(
                      child: Text(
                        errorMessage.isEmpty
                            ? "No hay publicaciones disponibles para adopción"
                            : errorMessage,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ) // Muestra un mensaje si no hay publicaciones
                    : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final pet = post['pet'];
                        final images = post['images'] as List<dynamic>;

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (images.isNotEmpty)
                                SizedBox(
                                  height: 200,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: images.length,
                                    itemBuilder: (context, imgIndex) {
                                      final imageUrl =
                                          images[imgIndex]['imgURL'];
                                      return Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        width:
                                            MediaQuery.of(context).size.width,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
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
                                      post['description'] ??
                                          "Sin detalles adicionales",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
        onPressed: showPublishPetModal,
        label: const Text("Publicar mascota en adopción"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
