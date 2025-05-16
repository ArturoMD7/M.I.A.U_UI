import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class PostWidget extends StatelessWidget {
  final Map<String, dynamic> post;
  final Function()? onDelete;
  final Function()? onComment;
  final Function()? onMessage;

  const PostWidget({
    super.key,
    required this.post,
    this.onDelete,
    this.onComment,
    this.onMessage,
  });

  String _getFullName() {
    final name = post['user_name'] ?? '';
    final firstName = post['user_first_name'] ?? '';
    return '$name $firstName'.trim();
  }

  String _getImageUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) {
      return '';
    }
    
    // Si la URL ya es completa (comienza con http), usarla directamente
    if (relativeUrl.startsWith('http')) {
      return relativeUrl;
    }
    
    // Si la URL es relativa, construirla con la URL base
    final baseUrl = dotenv.env['MEDIA_URL'] ?? dotenv.env['API_URL'] ?? '';
    
    // Manejar correctamente las barras en las URLs
    if (baseUrl.endsWith('/') && relativeUrl.startsWith('/')) {
      return baseUrl + relativeUrl.substring(1);
    } else if (!baseUrl.endsWith('/') && !relativeUrl.startsWith('/')) {
      return '$baseUrl/$relativeUrl';
    } else {
      return baseUrl + relativeUrl;
    }
  }
  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = _getImageUrl(post['user_profile_photo']);
    final postImages = post['images'] as List<dynamic>? ?? [];
    final pet = post['pet'] as Map<String, dynamic>? ?? {};

   return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: profilePhotoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(
                          profilePhotoUrl,
                          headers: const {"Cache-Control": "no-cache"},
                        )
                      : const AssetImage("assets/images/default_profile.jpg") as ImageProvider,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFullName().isNotEmpty ? _getFullName() : 'Usuario',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (post['created_at'] != null)
                        Text(
                          _formatDate(post['created_at']),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Post content
          if (post['description'] != null && post['description'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(post['description']),
            ),

          // Pet info
          if (pet.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Text(
                    'Mascota: ${pet['name'] ?? 'No especificado'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Edad: ${pet['age'] ?? 'Desconocida'}'),
                  Text('Raza: ${pet['breed'] ?? 'Desconocida'}'),
                  Text('Tamaño: ${pet['size'] ?? 'Desconocido'}'),
                  if (post['city'] != null || post['state'] != null)
                    Text(
                      'Ubicación: ${post['city'] ?? ''}, ${post['state'] ?? ''}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),

          // Post images
          if (postImages.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: postImages.length,
                itemBuilder: (context, index) {
                  final imageUrl = _getImageUrl(postImages[index]['imgURL']);
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.comment, color: Colors.blue),
                  label: const Text('Comentar'),
                  onPressed: onComment,
                ),
                if (onMessage != null)
                  TextButton.icon(
                    icon: const Icon(Icons.message, color: Colors.green),
                    label: const Text('Mensaje'),
                    onPressed: onMessage,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }
}