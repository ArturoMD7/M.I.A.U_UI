import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

const String baseUrl = "http://192.168.1.95:8000";

class MessagesScreen extends StatefulWidget {
  final int? initialRecipientId;
  final String? initialRecipientName;

  const MessagesScreen({
    Key? key,
    this.initialRecipientId,
    this.initialRecipientName,
  }) : super(key: key);

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<dynamic> chats = [];
  bool isLoading = true;
  bool isCreatingChat = false;
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    fetchChats().then((_) {
      if (widget.initialRecipientId != null) {
        _handleInitialRecipient();
      }
    });
  }

  Future<void> _handleInitialRecipient() async {
    final existingChat = chats.firstWhere(
      (chat) => chat['participants'].any(
        (user) => user['id'] == widget.initialRecipientId,
      ),
      orElse: () => null,
    );

    if (existingChat == null) {
      await _createChat(widget.initialRecipientId!);
    } else {
      _navigateToChat(existingChat);
    }
  }

  Future<void> _createChat(int recipientId) async {
    setState(() => isCreatingChat = true);
    final String? token = prefs.getString('jwt_token');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'participant_id': recipientId}),
      );

      if (response.statusCode == 201) {
        final newChat = jsonDecode(response.body);
        fetchChats().then((_) => _navigateToChat(newChat));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al crear chat: $e')));
    } finally {
      setState(() => isCreatingChat = false);
    }
  }

  void _navigateToChat(dynamic chatData) {
    final currentUserId = prefs.getInt('user_id');
    final otherUser = chatData['participants'].firstWhere(
      (user) => user['id'] != currentUserId,
      orElse: () => null,
    );

    if (otherUser != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => ChatScreen(
                chatId: chatData['id'],
                recipientName:
                    '${otherUser['name']} ${otherUser['first_name']}',
              ),
        ),
      );
    }
  }

  Future<void> fetchChats() async {
    final String? token = prefs.getString('jwt_token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chats/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          chats = jsonDecode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar chats: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCreatingChat) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchChats),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : chats.isEmpty
              ? const Center(child: Text('No tienes conversaciones'))
              : ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final currentUserId = prefs.getInt('user_id');
                  final otherUser = chat['participants'].firstWhere(
                    (user) => user['id'] != currentUserId,
                    orElse: () => null,
                  );

                  if (otherUser == null) return const SizedBox();

                  return ListTile(
                    leading:
                        otherUser['profilePhoto'] != null
                            ? ClipOval(
                              child: Image.network(
                                "$baseUrl${otherUser['profilePhoto']}",
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.person),
                                  );
                                },
                              ),
                            )
                            : CircleAvatar(
                              backgroundColor: Colors.grey[300],
                              child: const Icon(Icons.person),
                            ),
                    title: Text(
                      '${otherUser['name']} ${otherUser['first_name']}',
                    ),
                    subtitle: Text(
                      chat['last_message']?['content'] ?? 'No hay mensajes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing:
                        chat['unread_count'] > 0
                            ? CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Text(
                                chat['unread_count'].toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            )
                            : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ChatScreen(
                                chatId: chat['id'],
                                recipientName:
                                    '${otherUser['name']} ${otherUser['first_name']}',
                              ),
                        ),
                      ).then((_) => fetchChats());
                    },
                  );
                },
              ),
    );
  }
}
