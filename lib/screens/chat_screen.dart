import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String recipientName;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.recipientName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> messages = [];
  TextEditingController messageController = TextEditingController();
  bool isLoading = true;
  bool isSending = false;
  late SharedPreferences prefs;
  final ScrollController _scrollController = ScrollController();

  late final String apiUrl;
  late final String baseUrl;

  @override
  void initState() {
    super.initState();
    apiUrl = dotenv.env['API_URL'] ?? '192.168.1.133:8000/';
    baseUrl = "$apiUrl/chats";
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    await fetchMessages();
  }

  Future<void> fetchMessages() async {
    final String? token = prefs.getString('jwt_token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/${widget.chatId}/messages/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          messages = jsonDecode(response.body);
          isLoading = false;
        });
        _scrollToBottom(); // Desplazar hacia abajo al cargar los mensajes
      }
    } catch (e) {
      _showError('Error al cargar mensajes');
    }
  }

  Future<void> sendMessage() async {
    if (messageController.text.isEmpty) return;

    final String? token = prefs.getString('jwt_token');
    if (token == null) return;

    setState(() => isSending = true);
    final message = messageController.text;
    messageController.clear();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/${widget.chatId}/messages/create/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': message}),
      );

      if (response.statusCode == 201) {
        await fetchMessages();
        await _markMessagesAsRead();
      }
    } catch (e) {
      _showError('Error al enviar mensaje');
      messageController.text = message;
    } finally {
      setState(() => isSending = false);
    }
  }

  Future<void> _markMessagesAsRead() async {
    final String? token = prefs.getString('jwt_token');
    if (token == null) return;

    await http.put(
      Uri.parse('$baseUrl/${widget.chatId}/mark-read/'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.recipientName)),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message['sender']['id'] == prefs.getInt('user_id');
                      return MessageBubble(
                        message: message['content'],
                        isMe: isMe,
                        timestamp: message['timestamp'],
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
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String timestamp;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}
