import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  late final String apiUrl;
  late final String baseUrl;

  @override
  void initState() {
    super.initState();
    apiUrl = dotenv.env['API_URL'] ?? '192.168.1.133:8000/';
    baseUrl = apiUrl;
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
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Creando chat...',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Mensajes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchChats,
            tooltip: 'Actualizar conversaciones',
          ),
        ],
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
        ),
      )
          : chats.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes conversaciones',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicia una nueva conversación',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : ListView.separated(
        itemCount: chats.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final chat = chats[index];
          final currentUserId = prefs.getInt('user_id');
          final otherUser = chat['participants'].firstWhere(
                (user) => user['id'] != currentUserId,
            orElse: () => null,
          );

          if (otherUser == null) return const SizedBox();

          final hasUnread = chat['unread_count'] > 0;

          return Container(
            color: hasUnread
                ? primaryColor.withOpacity(0.05)
                : backgroundColor,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: otherUser['profilePhoto'] != null
                  ? ClipOval(
                child: Image.network(
                  "$baseUrl${otherUser['profilePhoto']}",
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.grey[500],
                      ),
                    );
                  },
                ),
              )
                  : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.grey[500],
                ),
              ),
              title: Text(
                '${otherUser['name']} ${otherUser['first_name']}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: hasUnread
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                chat['last_message']?['content'] ?? 'No hay mensajes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasUnread ? textColor : Colors.grey[600],
                  fontWeight: hasUnread
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
              trailing: hasUnread
                  ? Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
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
                    builder: (context) => ChatScreen(
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
}