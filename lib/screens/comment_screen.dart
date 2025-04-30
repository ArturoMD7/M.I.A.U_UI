import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CommentScreen extends StatefulWidget {
  final int postId; // Recibe el ID del post

  const CommentScreen({super.key, required this.postId});

  @override
  _CommentScreenState createState() => _CommentScreenState();
}



class _CommentScreenState extends State<CommentScreen> {
  late SharedPreferences prefs;
  late String apiUrl;
  bool isLoading = true;
  List<dynamic> comments = [];
  String errorMessage = '';
  TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    prefs = await SharedPreferences.getInstance(); // Inicializa SharedPreferences
    apiUrl = dotenv.env['API_URL'] ?? "192.168.1.133:8000"; // URL de la API
    _loadComments();
  }


  // Cargar los comentarios del post
  Future<void> _loadComments() async {
    final token = prefs.getString('jwt_token');
    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = "No estás autenticado. Inicia sesión primero.";
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/comments/?postId=${widget.postId}'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> commentsData = jsonDecode(response.body);
        setState(() {
          comments = commentsData;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Error al cargar los comentarios";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error de conexión: $e";
      });
    }
  }

  // Enviar un nuevo comentario
  Future<void> _sendComment(String commentText) async {
    final token = prefs.getString('jwt_token');
    final userId = prefs.getInt('user_id');
    if (token == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/comments/'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "comment": commentText,
          "postId": widget.postId,
          "userId": userId,
        }),
      );

      if (response.statusCode == 201) {
        _loadComments(); // Recargar los comentarios
        commentController.clear(); // Limpiar el campo de texto
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al enviar comentario")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Comentarios")),
      body: Column(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : comments.isEmpty
                  ? Center(
                      child: Text(
                        errorMessage.isEmpty
                            ? "No hay comentarios aún"
                            : errorMessage,
                        style: const TextStyle(fontSize: 18),
                      ),
                    )
                  : Expanded(
                      child: ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return ListTile(
                            title: Text(comment['user'] != null && comment['user']['name'] != null
                              ? comment['user']['name']
                              : "Usuario desconocido"),


                            subtitle: Text(comment['comment']),
                          );
                        },
                      ),
                    ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      hintText: "Escribe un comentario...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (commentController.text.isNotEmpty) {
                      _sendComment(commentController.text);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
