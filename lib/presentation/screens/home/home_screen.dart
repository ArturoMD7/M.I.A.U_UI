import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:miauuic/core/constants/app_colors.dart';
import 'package:miauuic/core/constants/app_dimens.dart';
import 'package:miauuic/widgets/common/indicators.dart';
import 'package:miauuic/widgets/common/avatars.dart';
import 'package:miauuic/services/api_service.dart';
import 'package:miauuic/screens/comment_screen.dart';
import 'package:miauuic/screens/chat_screen.dart';
import 'package:miauuic/screens/messages_screen.dart';
import 'package:miauuic/screens/create_pet_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _posts = [];
  List<dynamic> _allPosts = [];
  List<dynamic> _myPets = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String? _userState;
  int _currentUserId = 0;
  late ScrollController _scrollController;
  bool _showFab = true;

  final Map<String, String> _filterOptions = {
    'all': 'Todos',
    'lost': 'Perdidas',
    'adoption': 'En Adopción',
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadData();
    fetchPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final dir = _scrollController.position.userScrollDirection;
    if (dir == ScrollDirection.reverse && _showFab) {
      setState(() => _showFab = false);
    } else if (dir == ScrollDirection.forward && !_showFab) {
      setState(() => _showFab = true);
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userState = prefs.getString('user_state');
      _currentUserId = int.tryParse(prefs.getString('user_id') ?? '') ?? 0;
    });
    await fetchPosts();
  }

  Future<void> fetchPosts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        setState(() => _isLoading = false);
        return;
      }

      final baseUrl = apiService.baseUrl;

      final petsRes = await http.get(
        Uri.parse('$baseUrl/pets/my-pets/'),
        headers: {"Authorization": "Bearer $token"},
      );
      final postsRes = await http.get(
        Uri.parse('$baseUrl/posts/'),
        headers: {"Authorization": "Bearer $token"},
      );

      final pets = jsonDecode(petsRes.body)['data'] ?? [];
      final postsRaw = jsonDecode(postsRes.body)['data'] ?? [];

      final uidStr = prefs.getString('user_id');
      final int userId = int.tryParse(uidStr ?? '') ?? 0;

      _myPets = (pets).where((p) => p['userId'] == userId).toList();

      final processed =
          (postsRaw)
              .map((post) {
                final pet = post['pet'] as Map<String, dynamic>?;
                final imagesFromPost = post['images'] as List<dynamic>?;

                if (pet == null) return null;

                return {
                  ...post,
                  'pet': pet,
                  'images':
                      imagesFromPost != null
                          ? imagesFromPost
                              .map<String>(
                                (img) => img['imgURL']?.toString() ?? '',
                              )
                              .toList()
                          : <String>[],
                  'user': {
                    'id': post['userId'],
                    'name': post['user_name'] ?? '',
                    'first_name': '',
                    'profilePhoto': post['user_profile_photo'],
                  },
                };
              })
              .where((p) => p != null)
              .toList();

      setState(() {
        _allPosts = processed;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    if (_selectedFilter == 'all') {
      _posts = _allPosts;
    } else if (_selectedFilter == 'lost') {
      _posts =
          _allPosts.where((p) => p['pet']?['statusAdoption'] == 0).toList();
    } else if (_selectedFilter == 'adoption') {
      _posts =
          _allPosts.where((p) => p['pet']?['statusAdoption'] == 2).toList();
    }
  }

  void _showCreatePostDialog() {
    fetchPosts();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _CreatePostSheet(
            bgColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
            textColor: isDark ? Colors.white : Colors.black87,
            subColor: isDark ? Colors.white70 : Colors.black54,
            handleColor: isDark ? Colors.white54 : Colors.grey,
            myPets: _myPets,
            onSelectPet:
                (pet, type, description, images, {lastLocation, lastSeen}) =>
                    _createPost(pet, type, description, images, lastLocation: lastLocation, lastSeen: lastSeen),
          ),
    );
  }

  Future<void> _createPost(
    Map<String, dynamic> pet,
    String type,
    String? description,
    List<XFile> images, {
    String? lastLocation,
    String? lastSeen,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userIdStr = prefs.getString('user_id');
    final userId = int.tryParse(userIdStr ?? '') ?? 0;

    if (token == null || userId == 0) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Debes iniciar sesión")));
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    try {
      final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final baseUrl = apiService.baseUrl;

      // Crear el post primero
      final postBody = {
        "petId": pet['id'],
        "userId": userId,
        "title": type == 'lost' ? 'Mascota perdida' : 'Mascota en adopción',
        "postDate": now,
        "state": lastSeen ?? prefs.getString('user_state') ?? '',
        "description":
            description ??
            (type == 'lost' ? 'Mascota perdida' : 'Mascota en adopción'),
        "city": lastLocation ?? prefs.getString('user_city') ?? '',
      };

      final postResponse = await apiService.post('/posts/', body: postBody);

      if (postResponse.success) {
        final postId =
            postResponse.data?['id'] ?? postResponse.data?['data']?['id'];

        // Subir imágenes como multipart
        if (postId != null && images.isNotEmpty) {
          for (var i = 0; i < images.length; i++) {
            final request = http.MultipartRequest(
              'POST',
              Uri.parse('$baseUrl/imgspost/'),
            );
            request.headers['Authorization'] = 'Bearer $token';
            request.fields['idPost'] = postId.toString();

            final bytes = await images[i].readAsBytes();
            request.files.add(
              http.MultipartFile.fromBytes(
                'imgURL',
                bytes,
                filename: 'post_image_$i.jpg',
              ),
            );

            final streamedResponse = await request.send();
            final response = await http.Response.fromStream(streamedResponse);

            if (response.statusCode != 201) {
              debugPrint("Error uploading image $i: ${response.body}");
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Publicación creada")));
          fetchPosts();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(postResponse.message ?? "Error")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _deletePost(int postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Eliminar publicación"),
            content: const Text("¿Estás seguro de eliminar esta publicación?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Eliminar"),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final result = await apiService.delete('/posts/$postId/');
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Publicación eliminada")),
          );
          fetchPosts();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? "Error al eliminar")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showFab 
                ? Column(
                    children: [
                      _buildHeader(),
                      _buildFilterChips(),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton:
          _showFab
              ? FloatingActionButton.extended(
                onPressed: _showCreatePostDialog,
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Publicar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              : null,
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: AppColors.primary,
    elevation: 0,
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(51),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.pets, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'M.I.A.U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Encuentra a tu mejor amigo',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const MessagesScreen()),
            ),
      ),
      IconButton(
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        onPressed: _showCreatePostDialog,
      ),
    ],
  );

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(AppDimens.paddingLarge),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
    ),
    child:
        _userState != null
            ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _userState!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            )
            : const SizedBox(),
  );

  Widget _buildFilterChips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingLarge,
        vertical: AppDimens.paddingMedium,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              _filterOptions.entries.map((e) {
                final selected = _selectedFilter == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      e.value,
                      style: TextStyle(
                        color:
                            selected
                                ? Colors.white
                                : (isDark
                                    ? Colors.white
                                    : AppColors.textPrimary),
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    backgroundColor:
                        isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    onSelected: (s) {
                      setState(() {
                        _selectedFilter = e.key;
                        _applyFilter();
                      });
                    },
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingIndicator();
    if (_posts.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.pets,
        title: 'No hay publicaciones',
        subtitle: 'Crea una publicación',
        actionText: 'Crear',
        onAction: _showCreatePostDialog,
      );
    }
    return RefreshIndicator(
      onRefresh: fetchPosts,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppDimens.paddingLarge),
        itemCount: _posts.length,
        itemBuilder:
            (c, i) => _PostCard(
              post: _posts[i],
              currentUserId: _currentUserId,
              onComment: () => _openComments(_posts[i]['id']),
              onMessage:
                  _posts[i]['userId'] == _currentUserId
                      ? null
                      : () => _openMessage(_posts[i]['user']),
              onDelete:
                  _posts[i]['userId'] == _currentUserId
                      ? () => _deletePost(_posts[i]['id'])
                      : null,
            ),
      ),
    );
  }

void _openComments(int id) => Navigator.push(
    context,
    MaterialPageRoute(builder: (c) => CommentScreen(postId: id)),
  );

  void _openMessage(dynamic u) async {
    final prefs = await SharedPreferences.getInstance();
    final uidStr = prefs.getString('user_id');
    final currentUserId = int.tryParse(uidStr ?? '') ?? 0;
    final token = prefs.getString('jwt_token');

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión')));
      }
      return;
    }

    final dynamic rawRecipientId = u['id'];
    if (rawRecipientId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo identificar al usuario')));
      }
      return;
    }
    final int recipientId = rawRecipientId is int ? rawRecipientId : int.tryParse(rawRecipientId.toString()) ?? 0;
    final rawName = '${u['name'] ?? ''} ${u['first_name'] ?? ''}'.trim();
    final recipientName = rawName.isEmpty ? 'Usuario' : rawName;

    if (recipientId == currentUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No puedes enviarte un mensaje a ti mismo')),
        );
      }
      return;
    }

    try {
      final chatsResponse = await apiService.get('/chats/');
      if (chatsResponse.success && chatsResponse.data != null) {
        List<dynamic> chats;
        if (chatsResponse.data is List) {
          chats = chatsResponse.data as List<dynamic>;
        } else if (chatsResponse.data!['data'] != null) {
          chats = chatsResponse.data!['data'] as List<dynamic>;
        } else {
          chats = [];
        }

        dynamic existingChat;
        try {
          existingChat = chats.firstWhere(
            (chat) {
              final participants = chat['participants'] as List<dynamic>?;
              if (participants == null) return false;
              return participants.any(
                (participant) {
                  final pid = participant['id'];
                  final int pIdInt = pid is int ? pid : int.tryParse(pid.toString()) ?? -1;
                  return pIdInt == recipientId;
                },
              );
            },
          );
        } catch (_) {
          existingChat = null;
        }

        if (existingChat != null) {
          final chatId = existingChat['id'] is int
              ? existingChat['id'] as int
              : int.tryParse(existingChat['id'].toString()) ?? 0;
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => ChatScreen(
                  chatId: chatId,
                  recipientName: recipientName,
                ),
              ),
            );
          }
          return;
        }
      }

      final createResponse = await http.post(
        Uri.parse('${apiService.baseUrl}/chats/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'participant_id': recipientId}),
      );

      if (createResponse.statusCode == 201 || createResponse.statusCode == 200) {
        final newChat = jsonDecode(createResponse.body);
        final chatId = newChat['id'] is int
            ? newChat['id'] as int
            : int.tryParse(newChat['id'].toString()) ?? 0;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => ChatScreen(
                chatId: chatId,
                recipientName: recipientName,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo iniciar la conversación')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _PostCard extends StatefulWidget {
  final dynamic post;
  final int currentUserId;
  final VoidCallback onComment;
  final VoidCallback? onMessage;
  final VoidCallback? onDelete;
  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.onComment,
    this.onMessage,
    this.onDelete,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final pet = widget.post['pet'];
    final user = widget.post['user'];
    final post = widget.post;
    final images = post['images'] as List?;
    final mediaUrl = apiService.mediaUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isLost = pet != null && pet['statusAdoption'] == 0;
    final badgeColor = isLost ? Colors.redAccent : AppColors.adoptPetColor;
    final badgeText = isLost ? 'Perdido' : 'En Adopción';

    // Fallback image logic
    List<dynamic> validImages = [];
    if (images != null && images.isNotEmpty) {
      validImages = List.from(images);
    } else if (pet != null && pet['image'] != null && pet['image'].toString().isNotEmpty) {
      validImages = [pet['image']];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    UserAvatar(
                      profilePhoto: user['profilePhoto'],
                      name: '${user['name'] ?? ''} ${user['first_name'] ?? ''}',
                      size: AppDimens.avatarSmall,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user['name'] ?? ''} ${user['first_name'] ?? ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          if (post['postDate'] != null)
                            Text(
                              DateFormat('dd MMM yyyy').format(DateTime.parse(post['postDate'])),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (validImages.isNotEmpty)
              Stack(
                children: [
                  SizedBox(
                    height: 350,
                    width: double.infinity,
                    child: PageView.builder(
                      itemCount: validImages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final imgUrl = validImages[index].toString();
                        return CachedNetworkImage(
                          imageUrl: imgUrl.startsWith('http')
                              ? imgUrl
                              : '$mediaUrl$imgUrl',
                          fit: BoxFit.cover,
                          placeholder: (c, url) => Container(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (c, url, err) => Container(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: const Icon(Icons.error, color: Colors.grey),
                          ),
                        );
                      }
                    )
                  ),
                  if (validImages.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(validImages.length, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 8 : 6,
                            height: _currentPage == index ? 8 : 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == index 
                                ? Colors.white 
                                : Colors.white.withAlpha(128),
                            ),
                          );
                        }),
                      ),
                    ),
                  if (pet != null)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else if (pet != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            if (pet != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet['name'] ?? 'Sin nombre',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.pets, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${pet['breed'] ?? ''}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.monitor_weight_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${pet['size'] ?? ''}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (post['city'] != null || post['state'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: isLost 
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (post['city'] != null && post['city'].isNotEmpty)
                                        Text(
                                          post['city'],
                                          style: TextStyle(fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.grey[600]),
                                        ),
                                      if (post['state'] != null && post['state'].isNotEmpty)
                                        Text(
                                          post['state'],
                                          style: TextStyle(fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.grey[600]),
                                        ),
                                    ],
                                  )
                                : Text(
                                    '${post['city'] != null && post['city'].isNotEmpty ? post['city'] + ', ' : ''}${post['state'] ?? ''}',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white60 : Colors.grey[600],
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (post['description'] != null && post['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(
                  post['description'],
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: isDark ? Colors.white70 : const Color(0xFF4A4A4A),
                  ),
                ),
              ),
            Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
            Container(
              color: isDark ? Colors.white.withAlpha(5) : Colors.grey[50],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.mode_comment_outlined, color: AppColors.primary, size: 20),
                    label: const Text('Comentar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    onPressed: widget.onComment,
                  ),
                  if (widget.onMessage != null)
                    TextButton.icon(
                      icon: const Icon(Icons.send_outlined, color: AppColors.primary, size: 20),
                      label: const Text('Mensaje', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      onPressed: widget.onMessage,
                    ),
                  if (widget.onDelete != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                      onPressed: widget.onDelete,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === CREATE POST SHEET ===
class _CreatePostSheet extends StatefulWidget {
  final Color bgColor, textColor, subColor, handleColor;
  final List<dynamic> myPets;
  final Function(
    Map<String, dynamic> pet,
    String type,
    String? description,
    List<XFile> images, {
    String? lastLocation,
    String? lastSeen,
  }) onSelectPet;

  const _CreatePostSheet({
    required this.bgColor,
    required this.textColor,
    required this.subColor,
    required this.handleColor,
    required this.myPets,
    required this.onSelectPet,
  });

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  Map<String, dynamic>? _selectedPet;
  String _postType = 'adoption';
  final TextEditingController _descriptionController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  // Variables para la localización dinámica y Fecha
  Map<String, dynamic>? _selectedLocationInfo;
  DateTime? _lastSeenDate;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage();
      if (images != null && images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: $e'))
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastSeenDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: widget.textColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _lastSeenDate) {
      setState(() {
        _lastSeenDate = picked;
      });
    }
  }

  void _submitPost() {
    if (_selectedPet != null) {
      String? finalLocation;
      String? finalDate;

      if (_postType == 'lost') {
        if (_selectedLocationInfo != null) {
          final loc = _selectedLocationInfo!;
          final city = (loc['ciudad'] != null && loc['ciudad'].toString().isNotEmpty) ? loc['ciudad'] : loc['municipio'];
          finalLocation = '${loc['colonia']}, $city, ${loc['estado']}';
        }
        if (_lastSeenDate != null) {
          finalDate = 'Vista el ${DateFormat('dd/MM/yyyy').format(_lastSeenDate!)}';
        }
      }

      widget.onSelectPet(
        _selectedPet!,
        _postType,
        _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        _selectedImages,
        lastLocation: finalLocation,
        lastSeen: finalDate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.myPets.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No tienes mascotas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea una mascota para publicar',
              style: TextStyle(color: widget.subColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const CreatePetScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Crear Mascota'),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Selecciona una mascota',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.myPets.length,
                  itemBuilder: (c, i) {
                    final pet = widget.myPets[i];
                    final selected = _selectedPet?['id'] == pet['id'];
                    return ListTile(
                      leading:
                          pet['image'] != null && pet['image'].toString().isNotEmpty
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: pet['image'].toString().startsWith('http')
                                      ? pet['image']
                                      : '${apiService.mediaUrl}${pet['image']}',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Container(
                                    width: 50, height: 50, color: Colors.grey[300],
                                    child: const Icon(Icons.pets),
                                  ),
                                ),
                              )
                              : Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[300],
                                child: const Icon(Icons.pets),
                              ),
                      title: Text(
                        pet['name'] ?? '',
                        style: TextStyle(color: widget.textColor),
                      ),
                      subtitle: Text(
                        '${pet['breed'] ?? ''} - ${pet['size'] ?? ''}',
                        style: TextStyle(color: widget.subColor),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () => setState(() => _selectedPet = pet),
                    );
                  },
                ),
              ),
              if (_selectedPet != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _postType = 'lost'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _postType == 'lost' ? AppColors.lostPetColor : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.search),
                          label: const Text('Perdida'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _postType = 'adoption'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _postType == 'adoption' ? AppColors.adoptPetColor : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.pets),
                          label: const Text('Adopción'),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _descriptionController,
                    style: TextStyle(color: widget.textColor),
                    decoration: InputDecoration(
                      hintText: 'Descripción (opcional)',
                      hintStyle: TextStyle(color: widget.subColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: widget.subColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ),
                if (_postType == 'lost') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (TextEditingValue textEditingValue) async {
                        if (textEditingValue.text.length < 3) {
                          return const Iterable<Map<String, dynamic>>.empty();
                        }
                        final response = await apiService.searchColony(textEditingValue.text);
                        if (response.success && response.data != null) {
                          return (response.data as List<dynamic>).map((e) => e as Map<String, dynamic>);
                        }
                        return const Iterable<Map<String, dynamic>>.empty();
                      },
                      displayStringForOption: (Map<String, dynamic> option) {
                        final city = (option['ciudad'] != null && option['ciudad'].toString().isNotEmpty) ? option['ciudad'] : option['municipio'];
                        return '${option['colonia']}, $city, ${option['estado']}';
                      },
                      onSelected: (Map<String, dynamic> selection) {
                        setState(() {
                          _selectedLocationInfo = selection;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onEditingComplete: onEditingComplete,
                          style: TextStyle(color: widget.textColor),
                          decoration: InputDecoration(
                            labelText: 'Buscar Colonia',
                            labelStyle: TextStyle(color: widget.subColor),
                            hintText: 'Escribe el nombre de tu colonia...',
                            hintStyle: TextStyle(color: widget.subColor.withAlpha(150)),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _selectedLocationInfo != null
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 32),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  final city = (option['ciudad'] != null && option['ciudad'].toString().isNotEmpty) ? option['ciudad'] : option['municipio'];
                                  return ListTile(
                                    title: Text(option['colonia'] ?? ''),
                                    subtitle: Text('$city, ${option['estado']} - CP: ${option['codigo_postal']}'),
                                    onTap: () {
                                      onSelected(option);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Última vez visto',
                          labelStyle: TextStyle(color: widget.subColor),
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _lastSeenDate != null
                              ? DateFormat('dd/MM/yyyy').format(_lastSeenDate!)
                              : 'Seleccionar fecha',
                          style: TextStyle(color: widget.textColor),
                        ),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _pickImages,
                        icon: Icon(Icons.add_photo_alternate, color: widget.textColor),
                        tooltip: 'Galería',
                      ),
                      IconButton(
                        onPressed: _takePhoto,
                        icon: Icon(Icons.camera_alt, color: widget.textColor),
                        tooltip: 'Cámara',
                      ),
                      Text(
                        '${_selectedImages.length} imagen(es)',
                        style: TextStyle(color: widget.subColor),
                      ),
                    ],
                  ),
                ),
                if (_selectedImages.isNotEmpty)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _selectedImages.length,
                      itemBuilder: (ctx, i) => Stack(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(File(_selectedImages[i].path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 10,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedImages.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Publicar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
