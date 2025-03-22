import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'custom_app_bar.dart';

class LostPetsScreen extends StatefulWidget {
  const LostPetsScreen({super.key});

  @override
  _LostPetsScreenState createState() => _LostPetsScreenState();
}

class _LostPetsScreenState extends State<LostPetsScreen> {
  List<dynamic> posts = []; // Lista para almacenar las publicaciones
  List<dynamic> pets = []; // Lista para almacenar las mascotas
  bool isLoading = true; // Indicador de carga
  String errorMessage = ''; // Mensaje de error

  @override
  void initState() {
    super.initState();
    fetchData(); // Llama a la función para obtener los datos al iniciar la pantalla
  }

  // Función para obtener publicaciones y mascotas desde el backend
  Future<void> fetchData() async {
    const String postsUrl =
        "http://192.168.1.95:8000/api/posts/"; // Ruta de la API para posts
    const String petsUrl =
        "http://192.168.1.95:8000/api/pets/"; // Ruta de la API para mascotas

    try {
      // Obtener las publicaciones
      final postsResponse = await http.get(Uri.parse(postsUrl));

      if (postsResponse.statusCode == 200) {
        // Si la solicitud es exitosa, parsea los datos de las publicaciones
        final List<dynamic> postsData = jsonDecode(postsResponse.body);

        // Obtener las mascotas
        final petsResponse = await http.get(Uri.parse(petsUrl));

        if (petsResponse.statusCode == 200) {
          // Si la solicitud es exitosa, parsea los datos de las mascotas
          final List<dynamic> petsData = jsonDecode(petsResponse.body);

          // Filtrar publicaciones para mostrar solo aquellas asociadas a mascotas sin familia
          final filteredPosts =
              postsData.where((post) {
                final petId = post['petId'];
                final pet = petsData.firstWhere(
                  (pet) => pet['id'] == petId,
                  orElse: () => null,
                );
                return pet != null && pet['statusAdoption'] == 0;
              }).toList();

          setState(() {
            posts = filteredPosts;
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            errorMessage = "Error al cargar las mascotas";
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Error al cargar las publicaciones";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error de conexión: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(),
              ) // Muestra un indicador de carga
              : posts.isEmpty
              ? Center(
                child: Text(
                  errorMessage.isEmpty
                      ? "No hay publicaciones cerca de tu ubicación"
                      : errorMessage,
                  style: const TextStyle(fontSize: 18),
                ),
              ) // Muestra un mensaje si no hay publicaciones
              : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['title'] ?? "Título no disponible",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                post['description'] ??
                                    "Descripción no disponible",
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navegar a la pantalla de creación de publicación
        },
        label: const Text("Perdí a mi mascota"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
