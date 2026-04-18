import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

const Color primaryColor = Color(0xFFD0894B);
const Color cardColor = Colors.white;
const Color textPrimary = Color(0xFF2D2D2D);
const Color textSecondary = Color(0xFF757575);

class PostWidget extends StatelessWidget {
  final Map<String, dynamic> post;
  final Function()? onDelete;
  final Function()? onComment;
  final Function()? onMessage;
  final VoidCallback? onTap;

  const PostWidget({
    super.key,
    required this.post,
    this.onDelete,
    this.onComment,
    this.onMessage,
    this.onTap,
  });

  String _getFullName() {
    final name = post['user_name'] ?? post['user']?['name'] ?? '';
    final firstName =
        post['user_first_name'] ?? post['user']?['first_name'] ?? '';
    return '$name $firstName'.trim();
  }

  String _getImageUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) {
      return '';
    }
    if (relativeUrl.startsWith('http')) {
      return relativeUrl;
    }
    return apiService.getFullMediaUrl(relativeUrl);
  }

  @override
  Widget build(BuildContext context) {
    final postImages = post['images'] as List<dynamic>? ?? [];
    final pet = post['pet'] as Map<String, dynamic>? ?? {};
    final user = post['user'] as Map<String, dynamic>?;
    final profilePicture = user?['profile_picture'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: primaryColor.withAlpha(26),
                    backgroundImage:
                        profilePicture != null
                            ? NetworkImage(_getImageUrl(profilePicture))
                            : null,
                    child:
                        profilePicture == null
                            ? const Icon(
                              Icons.person,
                              color: primaryColor,
                              size: 22,
                            )
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getFullName().isNotEmpty
                              ? _getFullName()
                              : 'Usuario',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: textSecondary.withAlpha(179),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(
                                post['created_at'] ?? post['postDate'],
                              ),
                              style: TextStyle(
                                color: textSecondary.withAlpha(179),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (post['state'] != null ||
                                post['city'] != null) ...[
                              Icon(
                                Icons.location_on,
                                size: 12,
                                color: primaryColor.withAlpha(179),
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  _getLocation(),
                                  style: TextStyle(
                                    color: primaryColor.withAlpha(179),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(),
                ],
              ),
            ),
            if (post['description'] != null && post['description'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  post['description'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: textPrimary,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (pet.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildPetInfo(pet),
              ),
            ],
            if (postImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildImages(postImages, context),
            ],
            const SizedBox(height: 8),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                    icon: Icons.comment_outlined,
                    label: 'Comentar',
                    onTap: onComment,
                    color: Colors.blue,
                  ),
                  _buildActionButton(
                    icon: Icons.message_outlined,
                    label: 'Mensaje',
                    onTap: onMessage,
                    color: Colors.green,
                  ),
                  if (onDelete != null)
                    _buildActionButton(
                      icon: Icons.delete_outline,
                      label: 'Eliminar',
                      onTap: onDelete,
                      color: Colors.red,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = post['pet']?['status'] ?? post['status'];
    if (status == null) return const SizedBox.shrink();

    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 0:
        color = Colors.red;
        text = 'Perdido';
        icon = Icons.search;
        break;
      case 1:
        color = Colors.green;
        text = 'Adoptado';
        icon = Icons.home;
        break;
      case 2:
        color = Colors.orange;
        text = 'Adopción';
        icon = Icons.favorite;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetInfo(Map<String, dynamic> pet) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.pets, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet['name'] ?? 'Mascota',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _buildPetTag(pet['breed'] ?? '', Icons.category),
                    const SizedBox(width: 8),
                    _buildPetTag(pet['age'] ?? '', Icons.cake),
                    const SizedBox(width: 8),
                    _buildPetTag(pet['size'] ?? '', Icons.straighten),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetTag(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: textSecondary),
        const SizedBox(width: 2),
        Text(text, style: const TextStyle(fontSize: 11, color: textSecondary)),
      ],
    );
  }

  Widget _buildImages(List<dynamic> images, BuildContext context) {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: images.length,
        controller: PageController(viewportFraction: 0.92),
        itemBuilder: (context, index) {
          final imageUrl = _getImageUrl(images[index]['imgURL']);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 40),
                      ),
                    ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return 'Hace ${difference.inDays}d';
      } else {
        return DateFormat('dd MMM').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  String _getLocation() {
    final city = post['city'];
    final state = post['state'];
    if (city != null && state != null) {
      return '$city, $state';
    }
    return state ?? city ?? '';
  }
}
