import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import '../services/api_service.dart';

const Color primaryColor = Color(0xFFD68F5E);
const Color backgroundColor = Colors.white;
const Color textColor = Colors.black;
const Color accentColor = Colors.blue;

class MessagesScreen extends StatefulWidget {
  final int? initialRecipientId;
  final String? initialRecipientName;

  const MessagesScreen({
    super.key,
    this.initialRecipientId,
    this.initialRecipientName,
  });

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<dynamic> chats = [];
  bool isLoading = true;
  bool isCreatingChat = false;
  late SharedPreferences prefs;

  String get baseUrl => apiService.baseUrl;

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
        Uri.parse('$baseUrl/chats/'),
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
        Uri.parse('$baseUrl/chats/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> parsedChats;
        if (decoded is List) {
          parsedChats = decoded;
        } else if (decoded is Map<String, dynamic> &&
            decoded.containsKey('data')) {
          parsedChats = (decoded['data'] as List<dynamic>?) ?? [];
        } else {
          parsedChats = [];
        }
        setState(() {
          chats = parsedChats;
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
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              Text(
                'Creando chat...',
                style: TextStyle(color: textColor, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mensajes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Tus conversaciones',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchChats,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
              : chats.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: chats.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final currentUserId = int.tryParse(
                    prefs.getString('user_id') ?? '',
                  );
                  final otherUser = chat['participants'].firstWhere(
                    (user) => user['id'] != currentUserId,
                    orElse: () => null,
                  );

                  if (otherUser == null) return const SizedBox();

                  final hasUnread = chat['unread_count'] > 0;

                  return Container(
                    color:
                        hasUnread ? primaryColor.withAlpha(13) : Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withAlpha(26),
                        ),
                        child:
                            otherUser['profilePhoto'] != null
                                ? ClipOval(
                                  child: Image.network(
                                    "$baseUrl${otherUser['profilePhoto']}",
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: primaryColor,
                                      );
                                    },
                                  ),
                                )
                                : const Icon(Icons.person, color: primaryColor),
                      ),
                      title: Text(
                        '${otherUser['name']} ${otherUser['first_name']}',
                        style: TextStyle(
                          color: textColor,
                          fontWeight:
                              hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        chat['last_message']?['content'] ?? 'No hay mensajes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasUnread ? textColor : Colors.grey[600],
                          fontWeight:
                              hasUnread ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      trailing:
                          hasUnread
                              ? Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    chat['unread_count'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 64,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No tienes conversaciones',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inicia una nueva conversación',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF757575)),
            ),
          ],
        ),
      ),
    );
  }
}
