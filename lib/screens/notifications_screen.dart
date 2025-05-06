import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:miauuic/screens/adopt_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'lost_pets_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/post_detail_modal.dart';
import 'messages_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notifications = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String errorMessage = '';
  late String baseUrl;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/api';
    _fetchNotifications();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadMoreNotifications();
    }
  }

  Future<void> _showPostModal(BuildContext context, String postId, String notifType) async {
    final parsedPostId = int.tryParse(postId);
    if (parsedPostId == null) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    final mediaUrl = dotenv.env['MEDIA_URL'] ?? 'http://192.168.1.133:8000';

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión")),
      );
      return;
    }

    try {
      // 1. Obtener el post específico
      final postResponse = await http.get(
        Uri.parse("$baseUrl/posts/$parsedPostId/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (postResponse.statusCode != 200) {
        throw Exception("Error al obtener el post");
      }

      final postData = jsonDecode(postResponse.body);

      // 2. Obtener la mascota relacionada
      final petResponse = await http.get(
        Uri.parse("$baseUrl/pets/public/${postData['petId']}/"),
        headers: {"Authorization": "Bearer $token"},
      );

      // 3. Obtener imágenes del post
      final imgsResponse = await http.get(
        Uri.parse("$baseUrl/imgs-post/by-post/$parsedPostId/"),
        headers: {"Authorization": "Bearer $token"},
      );

      // 4. Obtener información del usuario
      final userResponse = await http.get(
        Uri.parse("$baseUrl/users/${postData['userId']}/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (petResponse.statusCode == 200 && 
          imgsResponse.statusCode == 200 && 
          userResponse.statusCode == 200) {
        final post = {
          ...postData,
          'pet': jsonDecode(petResponse.body),
          'images': jsonDecode(imgsResponse.body),
          'user': jsonDecode(userResponse.body),
        };

        // Mostrar el modal con el post completo
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: Text(notifType == 'Desaparecido_Alrededor' 
                      ? "Mascota Perdida" 
                      : "Mascota en Adopción"),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                body: PostDetailModal(
                  post: post,
                  mediaUrl: mediaUrl,
                  onMessagePressed: (userId) {
                    Navigator.pop(context); // Cerrar el modal
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessagesScreen(
                          initialRecipientId: userId,
                          initialRecipientName: post['user']['name'] ?? 'Usuario',
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      } else {
        throw Exception("Error al obtener datos relacionados");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar la publicación: ${e.toString()}")),
      );
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      final int? userId = prefs.getInt('user_id');

      if (token == null || userId == null) {
        setState(() {
          isLoading = false;
          errorMessage = "Debes iniciar sesión para ver notificaciones";
        });
        return;
      }

      final response = await http.get(
        Uri.parse("$baseUrl/notifications/user/$userId/"),
        headers: {"Authorization": "Bearer $token",
    "Accept-Charset": "utf-8",},
      );

      if (response.statusCode == 200) {
        final List<dynamic> newNotifications = jsonDecode(response.body);
        
        // Procesar notificaciones y eliminar duplicados
        final seenIds = <String>{};
        final processedNotifications = newNotifications
            .where((n) => seenIds.add(n['id'].toString())) // Elimina duplicados por ID
            .map((n) {
              return {
                'id': n['id'].toString(),
                'notifType': n['notifType'],
                'message': n['message'],
                'read': n['read'],
                'notiDate': n['notiDate'],
                'related_post_id': n['related_post'] != null 
                    ? n['related_post']['id']?.toString() 
                    : n['related_post_id']?.toString(),
              };
            }).toList();

        setState(() {
          notifications = processedNotifications;
          isLoading = false;
          isRefreshing = false;
          errorMessage = '';
        });
      } else {
        throw Exception("Error al cargar notificaciones: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isRefreshing = false;
        errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (isLoading || isRefreshing || notifications.isEmpty) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      final int? userId = prefs.getInt('user_id');

      if (token == null || userId == null) return;

      final response = await http.get(
        Uri.parse("$baseUrl/notifications/user/$userId/?limit=10&offset=${notifications.length}"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> newNotifications = jsonDecode(response.body);
        final processedNotifications = newNotifications.map((n) {
          return {
            'id': n['id'].toString(),
            'notifType': n['notifType'],
            'message': n['message'],
            'read': n['read'],
            'notiDate': n['notiDate'],
            'related_post_id': n['related_post_id']?.toString(),
          };
        }).toList();

        setState(() {
          notifications.addAll(processedNotifications);
        });
      }
    } catch (e) {
      print("Error cargando más notificaciones: $e");
    }
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      isRefreshing = true;
    });
    await _fetchNotifications();
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      if (token == null) return;

      final response = await http.put(
        Uri.parse("$baseUrl/notifications/mark-read/$notificationId/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          final index = notifications.indexWhere((n) => n['id'] == notificationId);
          if (index != -1) {
            notifications[index]['read'] = true;
          }
        });
      }
    } catch (e) {
      print("Error marcando como leída: $e");
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      if (token == null) return;

      final response = await http.delete(
        Uri.parse("$baseUrl/notifications/$notificationId/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 204) {
        setState(() {
          notifications.removeWhere((n) => n['id'] == notificationId);
        });
      }
    } catch (e) {
      print("Error eliminando notificación: $e");
    }
  }

  Widget _buildNotificationCard({
    required Map<String, dynamic> notification,
    required BuildContext context,
  }) {
    // Definir icono y color según el tipo de notificación
    IconData icon;
    Color iconColor;
    
    switch (notification['notifType']) {
      case 'Desaparecido_Alrededor':
        icon = Icons.pets;
        iconColor = Colors.orange;
        break;
      case 'Nueva_Mascota':
        icon = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'Comentario':
        icon = Icons.comment;
        iconColor = Colors.blue;
        break;
      case 'Mensaje':
        icon = Icons.message;
        iconColor = Colors.green;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.purple;
    }

    return Dismissible(
      key: Key(notification['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Eliminar notificación"),
            content: const Text("¿Estás seguro de que quieres eliminar esta notificación?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _deleteNotification(notification['id']);
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 3,
        color: notification['read'] ? Colors.white : Colors.blue[50],
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            _markAsRead(notification['id']);
            final postId = notification['related_post_id'];
            if (postId != null) {
              _showPostModal(context, postId, notification['notifType']);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 32, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['message'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: notification['read'] ? Colors.grey[800] : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(notification['notiDate']),
                        style: TextStyle(
                          color: notification['read'] ? Colors.grey : Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return DateFormat('dd MMM yyyy').format(dateTime);
      } else if (difference.inDays > 0) {
        return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'Hace unos momentos';
      }
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No hay notificaciones",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Cuando tengas notificaciones, aparecerán aquí",
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            errorMessage.isNotEmpty ? errorMessage : "Ocurrió un error",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchNotifications,
            child: const Text("Intentar de nuevo"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
                  ? _buildErrorState()
                  : notifications.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: notifications.length + 1,
                          itemBuilder: (context, index) {
                            if (index < notifications.length) {
                              return _buildNotificationCard(
                                notification: notifications[index],
                                context: context,
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: notifications.length % 10 == 0
                                      ? const CircularProgressIndicator()
                                      : const Text(
                                          "No hay más notificaciones",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                ),
                              );
                            }
                          },
                        ),
        ),
      ),
    );
  }
}