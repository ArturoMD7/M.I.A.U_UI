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
    setState(() => _userState = prefs.getString('user_state'));
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
        Uri.parse('$baseUrl/pets/'),
        headers: {"Authorization": "Bearer $token"},
      );
      final postsRes = await http.get(
        Uri.parse('$baseUrl/posts/'),
        headers: {"Authorization": "Bearer $token"},
      );
      final imgsRes = await http.get(
        Uri.parse('$baseUrl/imgspost/'),
        headers: {"Authorization": "Bearer $token"},
      );
      final usersRes = await http.get(
        Uri.parse('$baseUrl/users/'),
        headers: {"Authorization": "Bearer $token"},
      );

      final pets = jsonDecode(petsRes.body)['data'] ?? [];
      final posts = jsonDecode(postsRes.body)['data'] ?? [];
      final imgs = jsonDecode(imgsRes.body)['data'] ?? [];
      final users = jsonDecode(usersRes.body)['data'] ?? [];

      final uidStr = prefs.getString('user_id');
      final int userId = int.tryParse(uidStr ?? '') ?? 0;

      debugPrint("userId: $userId");
      debugPrint("pets: $pets");

      _myPets = (pets).where((p) => p['userId'] == userId).toList();

      debugPrint("myPets: $_myPets");

      final processed =
          (posts)
              .map((post) {
                final petId = post['petId'];
                final pet = (pets).firstWhere(
                  (p) => p['id'] == petId,
                  orElse: () => null,
                );
                final postImgs =
                    (imgs).where((img) => img['idPost'] == post['id']).toList();
                final userIdPost = post['userId'];
                final user = (users).firstWhere(
                  (u) => u['id'] == userIdPost,
                  orElse: () => null,
                );
                return {...post, 'pet': pet, 'images': postImgs, 'user': user};
              })
              .where((p) => p['pet'] != null)
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
                (pet, type, description, images) =>
                    _createPost(pet, type, description, images),
          ),
    );
  }

  Future<void> _createPost(
    Map<String, dynamic> pet,
    String type,
    String? description,
    List<XFile> images,
  ) async {
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
        "state": prefs.getString('user_state') ?? '',
        "description":
            description ??
            (type == 'lost' ? 'Mascota perdida' : 'Mascota en adopción'),
        "city": prefs.getString('user_city') ?? '',
      };
      
      final postResponse = await apiService.post('/posts/', body: postBody);
      
      if (postResponse.success) {
        final postId = postResponse.data?['id'] ?? postResponse.data?['data']?['id'];
        
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
              http.MultipartFile.fromBytes('imgURL', bytes, filename: 'post_image_$i.jpg'),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(postResponse.message ?? "Error")));
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
          _buildHeader(),
          _buildFilterChips(),
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
    if (_posts.isEmpty)
      return EmptyStateWidget(
        icon: Icons.pets,
        title: 'No hay publicaciones',
        subtitle: 'Crea una publicación',
        actionText: 'Crear',
        onAction: _showCreatePostDialog,
      );
    return RefreshIndicator(
      onRefresh: fetchPosts,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppDimens.paddingLarge),
        itemCount: _posts.length,
        itemBuilder:
            (c, i) => _PostCard(
              post: _posts[i],
              onComment: () => _openComments(_posts[i]['id']),
              onMessage: () => _openMessage(_posts[i]['user']),
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
    if (uidStr == null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión')));
      return;
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (c) => MessagesScreen(
                initialRecipientId: u['id'],
                initialRecipientName: u['name'] ?? 'Usuario',
              ),
        ),
      );
    }
  }
}

class _PostCard extends StatelessWidget {
  final dynamic post;
  final VoidCallback onComment, onMessage;
  const _PostCard({
    required this.post,
    required this.onComment,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final pet = post['pet'];
    final user = post['user'];
    final images = post['images'] as List?;
    final mediaUrl = apiService.mediaUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.paddingLarge),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(AppDimens.paddingMedium),
              child: Row(
                children: [
                  UserAvatar(
                    profilePhoto: user['profilePhoto'],
                    name: '${user['name'] ?? ''} ${user['first_name'] ?? ''}',
                    size: AppDimens.avatarSmall,
                  ),
                  const SizedBox(width: AppDimens.paddingSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user['name'] ?? ''} ${user['first_name'] ?? ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        if (post['postDate'] != null)
                          Text(
                            DateFormat(
                              'dd MMM yyyy',
                            ).format(DateTime.parse(post['postDate'])),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (images != null && images.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder:
                    (c, i) => CachedNetworkImage(
                      imageUrl: '$mediaUrl${images[i]['imgURL']}',
                      width: MediaQuery.of(context).size.width - 32,
                      fit: BoxFit.cover,
                      placeholder:
                          (c, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      errorWidget:
                          (c, url, err) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.error),
                          ),
                    ),
              ),
            ),
          if (pet != null)
            Padding(
              padding: const EdgeInsets.all(AppDimens.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet['name'] ?? 'Sin nombre',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pet['breed'] ?? ''} - ${pet['age'] ?? ''}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Tamaño: ${pet['size'] ?? ''}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  if (post['city'] != null || post['state'] != null)
                    Text(
                      '${post['city'] ?? ''}, ${post['state'] ?? ''}',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color:
                            isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          if (post['description'] != null &&
              post['description'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingMedium,
              ),
              child: Text(
                post['description'],
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.paddingSmall),
            child: Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.comment, color: AppColors.primary),
                  label: const Text('Comentar'),
                  onPressed: onComment,
                ),
                TextButton.icon(
                  icon: const Icon(
                    Icons.message,
                    color: AppColors.adoptPetColor,
                  ),
                  label: const Text('Mensaje'),
                  onPressed: onMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final Color bgColor, textColor, subColor, handleColor;
  final List<dynamic> myPets;
  final Function(
    Map<String, dynamic> pet,
    String type,
    String? description,
    List<XFile> images,
  )
  onSelectPet;

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

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al tomar foto: $e')));
      }
    }
  }

  void _submitPost() {
    if (_selectedPet != null) {
      widget.onSelectPet(
        _selectedPet!,
        _postType,
        _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        _selectedImages,
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
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
          Expanded(
            child: ListView.builder(
              itemCount: widget.myPets.length,
              itemBuilder: (c, i) {
                final pet = widget.myPets[i];
                final selected = _selectedPet?['id'] == pet['id'];
                return ListTile(
                  leading:
                      pet['image'] != null && pet['image'].toString().isNotEmpty
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              pet['image'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
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
                  trailing:
                      selected
                          ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                          )
                          : null,
                  onTap: () => setState(() => _selectedPet = pet),
                );
              },
            ),
          ),
          if (_selectedPet != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _descriptionController,
                style: TextStyle(color: widget.textColor),
                decoration: InputDecoration(
                  hintText: 'Descripción (opcional)',
                  hintStyle: TextStyle(color: widget.subColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: widget.subColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                maxLines: 3,
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: _pickImages,
                  icon: Icon(
                    Icons.add_photo_alternate,
                    color: widget.textColor,
                  ),
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
                itemBuilder:
                    (ctx, i) => Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(
                                File(_selectedImages[i].path),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 10,
                          child: GestureDetector(
                            onTap:
                                () =>
                                    setState(() => _selectedImages.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_selectedPet != null) ...[
                  Text(
                    'Tipo de publicación',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _postType = 'lost'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _postType == 'lost'
                                    ? AppColors.lostPetColor
                                    : Colors.grey,
                          ),
                          icon: const Icon(Icons.search),
                          label: const Text('Perdida'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              () => setState(() => _postType = 'adoption'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _postType == 'adoption'
                                    ? AppColors.adoptPetColor
                                    : Colors.grey,
                          ),
                          icon: const Icon(Icons.pets),
                          label: const Text('Adopción'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Publicar'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
