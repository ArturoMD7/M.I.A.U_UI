import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CommentScreen extends StatefulWidget {
  final int postId;

  const CommentScreen({Key? key, required this.postId}) : super(key: key);

  @override
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  List<dynamic> comments = [];
  TextEditingController commentController = TextEditingController();
  bool isLoading = true;
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    fetchComments();
  }

  Future<void> fetchComments() async {
    final String? token = prefs.getString('jwt_token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse(
<<<<<<< HEAD
          'http://137.131.25.37:8000/api/posts/${widget.postId}/comments/',
=======
          'http://192.168.1.95:8000/api/posts/${widget.postId}/comments/',
>>>>>>> 5328613d43e1403cf41d9b887c5b748aa19d85fc
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          comments = jsonDecode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar comentarios: $e')),
      );
    }
  }

  Future<void> addComment() async {
    if (commentController.text.isEmpty) return;

    final String? token = prefs.getString('jwt_token');
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse(
<<<<<<< HEAD
          'http://137.131.25.37:8000/api/posts/${widget.postId}/comments/',
=======
          'http://192.168.1.95:8000/api/posts/${widget.postId}/comments/',
>>>>>>> 5328613d43e1403cf41d9b887c5b748aa19d85fc
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'comment': commentController.text}),
      );

      if (response.statusCode == 201) {
        commentController.clear();
        fetchComments();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al enviar comentario: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comentarios')),
      body: Column(
        children: [
          Expanded(
            child:
<<<<<<< HEAD
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                      comment['userId']['profilePhoto'] ?? '',
                    ),
                  ),
                  title: Text(
                    '${comment['userId']['name']} ${comment['userId']['first_name']}',
                  ),
                  subtitle: Text(comment['comment']),
                );
              },
            ),
=======
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                              comment['userId']['profilePhoto'] ?? '',
                            ),
                          ),
                          title: Text(
                            '${comment['userId']['name']} ${comment['userId']['first_name']}',
                          ),
                          subtitle: Text(comment['comment']),
                        );
                      },
                    ),
>>>>>>> 5328613d43e1403cf41d9b887c5b748aa19d85fc
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un comentario...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: addComment),
              ],
            ),
          ),
        ],
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> 5328613d43e1403cf41d9b887c5b748aa19d85fc
