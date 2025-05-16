import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color primaryColor = Color(0xFFD68F5E);
const Color backgroundColor = Colors.white;
const Color textColor = Colors.black;
const Color accentColor = Colors.blue;

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String recipientName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.recipientName,
  });

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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.recipientName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                image: const DecorationImage(
                  image: AssetImage('assets/chat_bg.png'), // Opcional: fondo de chat
                  fit: BoxFit.cover,
                  opacity: 0.05,
                ),
              ),
              child: isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
                  : messages.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.message_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay mensajes aún',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Envía el primer mensaje',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message['sender']['id'] == prefs.getInt('user_id');
                  return MessageBubble(
                    message: message['content'],
                    isMe: isMe,
                    timestamp: message['timestamp'],
                    isFirst: index == 0 || messages[index-1]['sender']['id'] != message['sender']['id'],
                    isLast: index == messages.length-1 || messages[index+1]['sender']['id'] != message['sender']['id'],
                  );
                },
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: messageController,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: messageController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                          onPressed: () => messageController.clear(),
                        )
                            : null,
                      ),
                      onSubmitted: (_) => sendMessage(),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isSending ? Icons.hourglass_top : Icons.send,
                      color: Colors.white,
                    ),
                    onPressed: isSending ? null : sendMessage,
                  ),
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
  final bool isFirst;
  final bool isLast;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.timestamp,
    this.isFirst = true,
    this.isLast = true,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateTime.parse(timestamp);
    final timeString = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 8 : 2,
        bottom: isLast ? 8 : 2,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isMe ? primaryColor : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isMe ? 16 : (isFirst ? 16 : 4)),
                    topRight: Radius.circular(isMe ? (isFirst ? 16 : 4) : 16),
                    bottomLeft: Radius.circular(isMe ? 16 : (isLast ? 16 : 4)),
                    bottomRight: Radius.circular(isMe ? (isLast ? 16 : 4) : 16),
                  ),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: isMe ? Colors.white : textColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                child: Text(
                  timeString,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}