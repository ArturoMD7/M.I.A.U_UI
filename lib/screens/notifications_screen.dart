import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'lost_pets_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
        Uri.parse("$baseUrl/notifications/user/$userId/?limit=10"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> newNotifications = jsonDecode(response.body);
        setState(() {
          notifications = newNotifications;
          isLoading = false;
          isRefreshing = false;
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
        setState(() {
          notifications.addAll(newNotifications);
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
            
            if (notification['related_post_id'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LostPetsScreen(
                    initialPostId: notification['related_post_id'],
                  ),
                ),
              );
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
            errorMessage,
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
      appBar: CustomAppBar(), // Usamos tu CustomAppBar sin parámetros
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