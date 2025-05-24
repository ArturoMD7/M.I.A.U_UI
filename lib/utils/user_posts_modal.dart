import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserPostsModal extends StatefulWidget {
  const UserPostsModal({super.key});

  @override
  _UserPostsModalState createState() => _UserPostsModalState();
}

const Color primaryColor = Color(
  0xFFD0894B,
); // Color marrón claro similar al de la imagen
const Color iconColor = Colors.black;

class _UserPostsModalState extends State<UserPostsModal> {
  List<dynamic> allPosts = [];
  List<dynamic> displayedPosts = [];
  bool isLoading = true;
  String errorMessage = '';
  late String baseUrl;
  late String mediaUrl;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
    mediaUrl = dotenv.env['MEDIA_URL'] ?? 'http://192.168.1.133:8000';
    _fetchUserPosts();
  }

  Future<void> _fetchUserPosts() async {
  setState(() {
    isLoading = true;
    errorMessage = '';
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getInt('user_id');

    if (token == null || userId == null) {
      throw Exception("Debes iniciar sesión");
    }

    final response = await http.get(
      Uri.parse("$baseUrl/user/posts/"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      // Asegurar la conversión a Map<String, dynamic>
      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Convertir las listas a los tipos correctos
      final List<dynamic> postsList = data['posts'] as List<dynamic>;
      final List<dynamic> petsList = data['pets'] as List<dynamic>;
      final List<dynamic> imagesList = data['images'] as List<dynamic>;

      // Combinar los datos con conversión explícita de tipos
      final List<Map<String, dynamic>> combinedPosts = postsList.map<Map<String, dynamic>>((post) {
        final Map<String, dynamic> postMap = post as Map<String, dynamic>;
        final Map<String, dynamic>? pet = petsList.firstWhere(
          (pet) => (pet as Map<String, dynamic>)['id'] == postMap['petId'],
          orElse: () => null,
        );
        
        final List<Map<String, dynamic>> postImages = imagesList.where(
          (img) => (img as Map<String, dynamic>)['idPost'] == postMap['id']
        ).cast<Map<String, dynamic>>().toList();

        return {
          ...postMap,
          'pet': pet,
          'images': postImages,
        };
      }).toList();

      setState(() {
        allPosts = combinedPosts;
        _filterPosts(0);
        isLoading = false;
      });
    } else {
      throw Exception("Error al cargar publicaciones: ${response.statusCode}");
    }
  } catch (e) {
    setState(() {
      isLoading = false;
      errorMessage = e.toString();
    });
  }
}

  void _filterPosts(int tabIndex) {
    setState(() {
      _currentTabIndex = tabIndex;
      switch (tabIndex) {
        case 0: // Todas
          displayedPosts = allPosts;
          break;
        case 1: // Perdidas
          displayedPosts = allPosts.where((post) => post['postType'] == 'lost').toList();
          break;
        case 2: // Adopción
          displayedPosts = allPosts.where((post) => post['postType'] == 'adoption').toList();
          break;
      }
    });
  }

  Future<void> _deletePost(int postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      
      if (token == null) {
        throw Exception("No autenticado");
      }
      
      final response = await http.delete(
        Uri.parse("$baseUrl/posts/$postId/"),
        headers: {"Authorization": "Bearer $token"},
      );
      
      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Publicación eliminada")),
        );
        await _fetchUserPosts(); // Recargar la lista
      } else {
        throw Exception("Error al eliminar: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> post) {
    // Asegurarse de que 'pet' es Map<String, dynamic>
    final Map<String, dynamic> pet = post['pet'] as Map<String, dynamic>;
    
    // Asegurarse de que 'images' es List<Map<String, dynamic>>
    final List<Map<String, dynamic>> images = (post['images'] as List<dynamic>).cast<Map<String, dynamic>>();
    
    final bool isLostPet = post['postType'] == 'lost';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          // Aquí podrías navegar a una pantalla de detalle si lo deseas
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imágenes (si existen)
            if (images.isNotEmpty)
              SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: "$mediaUrl${images[index]['imgURL']}",
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.error)),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLostPet ? Colors.orange.withOpacity(0.8) : Colors.green.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isLostPet ? "Perdida" : "Adopción",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 150,
                color: Colors.grey[200],
                child: Center(
                  child: Icon(
                    isLostPet ? Icons.pets : Icons.favorite,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pet['name'] ?? "Sin nombre",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Eliminar publicación"),
                              content: const Text("¿Estás seguro de que quieres eliminar esta publicación?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Cancelar"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deletePost(post['id']);
                                  },
                                  child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.pets, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        pet['breed'] ?? 'Raza desconocida',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.cake, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        pet['age'] ?? 'Edad desconocida',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post['description'] ?? "Sin descripción",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "Publicado el ${post['postDate']?.split('T')[0] ?? 'fecha desconocida'}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: const Text("Mis Publicaciones"),
          bottom: TabBar(
            labelColor: Colors.white,
            onTap: _filterPosts,
            tabs: const [
              Tab(text: "Todas"),
              Tab(text: "Perdidas"),
              Tab(text: "Adopción"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchUserPosts,
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? Center(child: Text(errorMessage))
                : displayedPosts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _currentTabIndex == 0
                                  ? "No tienes publicaciones"
                                  : _currentTabIndex == 1
                                      ? "No tienes mascotas perdidas"
                                      : "No tienes mascotas en adopción",
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchUserPosts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: displayedPosts.length,
                          itemBuilder: (context, index) {
                            return _buildPostCard(context, displayedPosts[index]);
                          },
                        ),
                      ),
      ),
    );
  }
}