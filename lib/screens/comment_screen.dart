import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

const Color primaryColor = Color(
  0xFFD0894B,
); // Color marrón claro similar al de la imagen
const Color iconColor = Colors.black;

class CommentScreen extends StatefulWidget {
  final int postId;

  const CommentScreen({super.key, required this.postId});

  @override
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  late SharedPreferences prefs;
  bool isLoading = true;
  List<dynamic> comments = [];
  String errorMessage = '';
  TextEditingController commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    prefs = await SharedPreferences.getInstance();
    _loadComments();
  }

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
      final result = await apiService.get(
        '/comments/',
        queryParams: {'post': widget.postId.toString()},
      );

      if (result.success && result.data != null) {
        List<dynamic> commentsData;
        if (result.data is List) {
          commentsData = result.data as List<dynamic>;
        } else if (result.data!['data'] != null) {
          commentsData = result.data!['data'] as List<dynamic>;
        } else {
          commentsData = [];
        }
        setState(() {
          comments = commentsData;
          isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = result.message ?? "Error al cargar los comentarios";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error de conexión: $e";
      });
    }
  }

  Future<void> _sendComment(String commentText) async {
    final token = prefs.getString('jwt_token');
    final userId = prefs.getString('user_id');
    if (token == null || userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Debes iniciar sesión")));
      return;
    }

    try {
      final result = await apiService.post(
        '/comments/',
        body: {"comment": commentText, "postId": widget.postId},
      );

      if (result.success) {
        _loadComments();
        commentController.clear();
        FocusScope.of(context).unfocus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? "Error al enviar comentario"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Comentarios"),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Column(
        children: [
          isLoading
              ? const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
              )
              : comments.isEmpty
              ? Expanded(
                child: Center(
                  child: Text(
                    errorMessage.isEmpty
                        ? "No hay comentarios aún"
                        : errorMessage,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
              )
              : Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final user = comment['user'] as Map<String, dynamic>?;
                    final userName =
                        user != null
                            ? '${user['name'] ?? ''} ${user['first_name'] ?? ''}'
                                .trim()
                            : "Usuario desconocido";

                    final commentDate =
                        comment['created_at'] != null
                            ? DateTime.parse(comment['created_at'])
                            : null;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: primaryColor.withOpacity(
                                    0.2,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: iconColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (commentDate != null)
                                      Text(
                                        _formatDate(commentDate),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(comment['comment'] ?? ''),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: "Escribe un comentario...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        _sendComment(text);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      if (commentController.text.isNotEmpty) {
                        _sendComment(commentController.text);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}
