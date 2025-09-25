import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:newsgram/messageSection.dart';
import 'package:newsgram/userModel.dart';
import 'package:newsgram/settingPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:newsgram/Widgets.dart';

class Accountpage extends StatefulWidget {
  
  final UserModel searchUser;  
  final bool isOwner;
  final int? initialPostId;
  const Accountpage({super.key, required this.isOwner,required this.searchUser,this.initialPostId,});

  @override
  State<Accountpage> createState() => _AccountpageState();
}

class _AccountpageState extends State<Accountpage> {


  var _postCount=0;
  var _followerCount = 0;
  var _followingCount = 0;
  String? _avatarUrl;
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _bio = TextEditingController();

  final List<String> allProfessions = [
    'Actor', 'Model', 'Designer', 'Developer', 'Photographer', 'Writer', 'Musician', 'Artist'
  ];
  List<String> selectedProfessions = [];

  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  int? _highlightedPostId;
  final GlobalKey _highlightedPostKey = GlobalKey();
  bool _shouldScrollToPost = false;
  final ImagePicker _picker = ImagePicker();
  final _supabase = Supabase.instance.client;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _highlightedPostId = widget.initialPostId;
    _shouldScrollToPost = _highlightedPostId != null;
    
    // Scroll to the post after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shouldScrollToPost && _highlightedPostKey.currentContext != null) {
        _scrollToHighlightedPost();
      }
    });
    if (widget.isOwner) {
      // Load current user's profile data
      _loadUserProfile();
      _loadPostCount(_supabase.auth.currentUser?.id ?? '');
       _loadFollowCounts(_supabase.auth.currentUser?.id ?? '');
       //_buildPosts(_supabase.auth.currentUser?.id ?? '');
      _buildPosts(_supabase.auth.currentUser?.id ?? '');
    } else if (widget.isOwner==false) {
      // Load the viewed user's profile data
      _loadOtherUserProfile(widget.searchUser!.id);
      _loadPostCount(widget.searchUser!.id);
      _loadFollowCounts(widget.searchUser.id);
      _buildPosts(widget.searchUser.id);
      _checkIfFollowing();
    }
    // _testUrlGeneration(); 
  }

   void _scrollToHighlightedPost() {
    final context = _highlightedPostKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      setState(() {
        _shouldScrollToPost = false; // Reset after scrolling
      });
    }
  }

  
  Future<void> _toggleFollow() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to follow')),
        );
        return;
      }

      if (_isFollowing) {
        // Unfollow
        await _supabase
            .from('followers')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', widget.searchUser.id);
        
        setState(() {
          _isFollowing = false;
          _followerCount--;
        });
      } else {
        // Follow
        await _supabase
            .from('followers')
            .insert({
              'follower_id': currentUserId,
              'following_id': widget.searchUser.id,
              'created_at': DateTime.now().toIso8601String(),
            });
        
        setState(() {
          _isFollowing = true;
          _followerCount++;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

    Future<void> _checkIfFollowing() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await _supabase
          .from('followers')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', widget.searchUser.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFollowing = response != null;
        });
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  Future<void> _loadPostCount(String userId) async {
  try {
    final countResponse = await _supabase
        .from('posts')
        .select()
        .eq('user_id', userId)
        .count(CountOption.exact);
    
    if (mounted) {
      setState(() {
        _postCount = countResponse.count ?? 0;
      });
    }
  } catch (e) {
    debugPrint('Error loading post count: $e');
  }
}

  Future<void> _loadFollowCounts(String userId) async {
    try {
      // Get follower count
      final followersResponse = await _supabase
          .from('followers')
          .select('*',)
          .eq('following_id', userId).count();

      // Get following count
      final followingResponse = await _supabase
          .from('followers')
          .select('*')
          .eq('follower_id', userId).count();

      if (mounted) {
        setState(() {
          _followerCount = followersResponse.count ?? 0;
          _followingCount = followingResponse.count ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading follow counts: $e');
    }
  }

    Future<void> _loadOtherUserProfile(String userId) async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _username.text = response['username'] ?? '';
          _name.text = response['name'] ?? '';
          _bio.text = response['bio'] ?? '';
          _avatarUrl = response['avatar_url'];
          selectedProfessions = List<String>.from(response['professions'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading other user profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _bio.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _username.text = response['username'] ?? '';
          _name.text = response['name'] ?? '';
          _bio.text = response['bio'] ?? '';
          _avatarUrl = response['avatar_url'];
          selectedProfessions = List<String>.from(response['professions'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

Future<void> _updateAvatar() async {
  final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
  if (pickedFile == null) return;
  
  setState(() => _isLoading = true);
  
  try {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    // Read file bytes
    final bytes = await pickedFile.readAsBytes();
    final fileExt = pickedFile.name.split('.').last.toLowerCase();
    
    // Create filename similar to your manual upload
    final fileName = '${user.id}_avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    
    print('🎯 Target filename: $fileName');
    print('📦 File size: ${bytes.length} bytes');
    
    // Upload file (NO leading slash in filename)
    await _supabase.storage
        .from('avatars')
        .uploadBinary(
          fileName, // Just the filename, no path prefix
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$fileExt',
            cacheControl: '3600',
            upsert: true,
          ),
        );
    
    print('✅ File uploaded successfully');
    
    // Get the public URL - this should match your manual upload format
    final String publicUrl = _supabase.storage
        .from('avatars')
        .getPublicUrl(fileName);
    
    print('🔗 Generated URL: $publicUrl');
    
    // The URL should look like:
    // https://khusmzcejezstsngqhhs.supabase.co/storage/v1/object/public/avatars/filename.jpeg
    // NOT: https://khusmzcejezstsngqhhs.supabase.co/storage/v1/object/public/avatars//filename.jpeg
    
    // Update database - include username or use update instead of upsert
    final response = await _supabase
        .from('user_profiles')
        .update({
          'avatar_url': publicUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id)
        .select();
        
    print('💾 Database updated: $response');
    
    // Update UI with cache-busted URL
    if (mounted) {
      final cacheBustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _avatarUrl = cacheBustedUrl;
      });
      
      // Clear image cache
      NetworkImage(publicUrl).evict();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Avatar updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
    
  } catch (e, stackTrace) {
    print('❌ Error details: $e');
    print('📋 Stack trace: $stackTrace');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

// Debug function to test the URL generation
// void _testUrlGeneration() {
//   final testFileName = 'test_image.jpeg';
//   final url = _supabase.storage.from('avatars').getPublicUrl(testFileName);
//   print('🧪 Test URL: $url');
  
//   // This should output:
//   // https://khusmzcejezstsngqhhs.supabase.co/storage/v1/object/public/avatars/test_image.jpeg
//   // NOT: https://khusmzcejezstsngqhhs.supabase.co/storage/v1/object/public/avatars//test_image.jpeg
// }

  Future<void> _saveProfile() async {
    if (_username.text.isEmpty || _name.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username and Name are required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _supabase.from('user_profiles').upsert({
        'user_id': user.id,
        'username': _username.text.trim(),
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'professions': selectedProfessions,
        'updated_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

Future<Widget> _buildPosts(String user_id) async {
  final user = _supabase.auth.currentUser;
  if (user == null) return const Center(child: Text('Please sign in'));

  try {
    final response = await _supabase
        .from('posts')
        .select()
        .eq('user_id', user_id)
        .order('created_at', ascending: false);

    if (response.isEmpty) {
      return const Center(child: Text('No posts yet'));
    }

    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: response.length,
      itemBuilder: (context, index) {
        final post = response[index];
        final postId = post['id'] as int?; // Changed to int
        final claim = post['claim'] as String? ?? 'No claim text';
        final rating = post['rating'] as String? ?? 'Unrated';
        final mediaUrl = post['media_url'] as String? ?? '';
  //       bool isLiked = post['isLiked'] ?? false;
  //       int likeCount = 0;
  //        final currentUserId = _supabase.auth.currentUser?.id;
  // final likesString = post['Likes'] as String? ?? '';
  // final likesList = likesString.isNotEmpty ? likesString.split(',') : [];
  
  // isLiked = currentUserId != null && likesList.contains(currentUserId);
  // likeCount = likesList.length;
        final source = _getSource(post);

        // Check if this is the post we want to highlight
        final bool isHighlighted = postId == _highlightedPostId;
        String post_id=postId.toString();
        return GestureDetector(
          onTap: () {
            showMoreDialog(context,post_id,post['user_id'], post['claim'], mediaUrl, rating, source, post['evidence'],false);
          },
          child: FutureBuilder<Map<String, dynamic>>(
            future: _fetchLikeData(post['id']),
      builder: (context, likeSnapshot) {
        final isLiked = likeSnapshot.data?['isLiked'] ?? false;
        final likeCount = likeSnapshot.data?['likeCount'] ?? 0;
        //final user = getUserName(post['user_id']);
      
            return Card(
              key: isHighlighted ? _highlightedPostKey : null,
              //margin: const EdgeInsets.all(8),
              color: isHighlighted ? const Color.fromARGB(255, 0, 0, 0) : null,
              elevation: isHighlighted ? 4 : 1,
              child: ListTile(
                title: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(claim, style: TextStyle(fontSize: 20)),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mediaUrl.isNotEmpty && (mediaUrl.startsWith('http') || mediaUrl.startsWith('https')))
                     Padding(
                       padding: const EdgeInsets.only(bottom: 12, left: 8),
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(8),
                         child: SizedBox(
                           width: double.infinity,
                           height: 200,
                           child: CachedNetworkImage(
                             imageUrl: mediaUrl,
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
                       ),
                     ),
                    const SizedBox(height: 6),
                    Text('Source: $source', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                    children:[
            
                       GestureDetector(
                              onTap: () async {
                                try {
                                  final userId = _supabase.auth.currentUser?.id;
                                  if (userId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please login to like posts')),
                                    );
                                    return;
                                  }
            
                                  if (isLiked) {
                                    // Unlike - remove from likes table
                                    await _supabase
                                        .from('likes')
                                        .delete()
                                        .eq('user_id', userId)
                                        .eq('post_id', post['id']);
            
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Removed like')),
                                    );
                                  } else {
                                    // Like - add to likes table
                                    await _supabase
                                        .from('likes')
                                        .insert({
                                          'user_id': userId,
                                          'post_id': post['id'],
                                          'created_at': DateTime.now().toIso8601String(),
                                        });
            
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Liked post')),
                                    );
                                  }
            
                                  // Refresh the like data
                                  final newLikeData = await _fetchLikeData(post['id']);
                                  // You might want to use a state management solution here
                                  // For now, we'll just rebuild the widget
                                  setState(() {});
                                } catch (e) {
                                  print('Error liking post: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: ${e.toString()}')),
                                  );
                                }
                              },
                              onDoubleTap: () {
                                if (likeCount > 0) {
                                  _showPostLikes(post['id']);
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    size: 20,
                                    color: isLiked ? const Color.fromARGB(255, 249, 116, 106) : null,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    likeCount.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLiked ? const Color.fromARGB(255, 249, 116, 106) : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _buildCommentSheet(context, post['id']);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.comment_outlined, size: 20),
                            // SizedBox(width: 4),
                            // Text(
                            //   (post['comment_count'] ?? "").toString(),
                            //   style: TextStyle(fontSize: 12),
                            // ),
                          ],
                        )
                        ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _buildShareSheet(context, post['id']);
                        },
                        child: Icon(Icons.share_outlined, size: 20)
                        ),
                    ],
                  ),
                       
                  ],
                ),
              ),
            );
      }
          ),
        );
      },
    );
  } catch (e, stack) {
    debugPrint('Error loading posts: $e\n$stack');
    return const Center(child: Text('Error loading posts'));
  }
}

Future<Map<String, dynamic>> _fetchLikeData(dynamic postId) async {
  try {
    final currentUserId = _supabase.auth.currentUser?.id;
    final postIdStr = postId.toString(); // Convert to string
    
    // Fetch like count from likes table
    final likeCountResponse = await _supabase
        .from('likes')
        .select()
        .eq('post_id', postIdStr); // Use string version

    final likeCount = List<Map<String, dynamic>>.from(likeCountResponse).length;
    
    // Check if current user liked this post
    bool isLiked = false;
    if (currentUserId != null) {
      final userLikeResponse = await _supabase
          .from('likes')
          .select()
          .eq('post_id', postIdStr) // Use string version
          .eq('user_id', currentUserId)
          .maybeSingle();

      isLiked = userLikeResponse != null;
    }
    
    return {
      'isLiked': isLiked,
      'likeCount': likeCount,
    };
  } catch (e) {
    print('Error fetching like data: $e');
    return {'isLiked': false, 'likeCount': 0};
  }
}

void _showPostLikes(String likesString) async {
  final _supabase = Supabase.instance.client;
  
  try {
    final likedUserIds = likesString.isNotEmpty ? likesString.split(',') : [];
    
    if (likedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No likes yet')),
      );
      return;
    }

    // Fetch user profiles for those who liked
    final usersResponse = await _supabase
        .from('user_profiles')
        .select('user_id, username, avatar_url')
        .inFilter('user_id', likedUserIds);

    final users = List<Map<String, dynamic>>.from(usersResponse);

    // Show likes dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liked by'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  foregroundImage: user['avatar_url'] != null
                      ? NetworkImage(user['avatar_url'])
                      : null,
                  child: user['avatar_url'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(user['username'] ?? 'Unknown User'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

  } catch (e) {
    print('Error fetching likes: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading likes: ${e.toString()}')),
    );
  }
}

void _buildShareSheet(BuildContext context, int postId) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Post',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Link'),
              onTap: () {
                // Implement copy link functionality
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share via chats'),
              onTap: () {
                Navigator.pop(context);
                _buildShareUserSheet(context, postId);
                //
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    },
  );
} 

Future<void> _shareWithUser(BuildContext context, int postId, String targetUserId) async {
  final _supabase = Supabase.instance.client;
  final currentUserId = _supabase.auth.currentUser?.id;

  try {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to share')),
      );
      return;
    }

    // Get post details
    final postResponse = await _supabase
        .from('posts')
        .select('claim')
        .eq('id', postId)
        .single();

    final claim = postResponse['claim'] ?? 'Check out this post';
    
    // Create message with post reference
    await _supabase.from('messages').insert({
      'sender_id': currentUserId,
      'receiver_id': targetUserId,
      'text': 'Shared post: $claim',
      'post_id': postId,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post shared successfully')),
    );
  } catch (e) {
    print('Error sharing post: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error sharing: $e')),
    );
  }
}


void _buildShareUserSheet(BuildContext context, int postId) {
  final _supabase = Supabase.instance.client;
  final currentUserId = _supabase.auth.currentUser?.id;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                const Text(
                  'Share with Followers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchFollowers(currentUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Expanded(
                        child: Center(
                          child: Text('Error: ${snapshot.error}'),
                        ),
                      );
                    }

                    final followers = snapshot.data ?? [];

                    if (followers.isEmpty) {
                      return const Expanded(
                        child: Center(
                          child: Text(
                            'No followers yet. When people follow you, they will appear here.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return Expanded(
                      child: ListView.builder(
                        itemCount: followers.length,
                        itemBuilder: (context, index) {
                          final follower = followers[index];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: follower['avatar_url'] != null
                                    ? NetworkImage(follower['avatar_url'])
                                    : null,
                                child: follower['avatar_url'] == null
                                    ? Text(follower['username']?.toString().substring(0, 1).toUpperCase() ?? 'U')
                                    : null,
                              ),
                              title: Text(
                                follower['username'] ?? 'Unknown User',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(follower['name'] ?? ''),
                              trailing: ElevatedButton(
                                onPressed: () => _shareWithUser(context, postId, follower['user_id']), // Use 'user_id'
                                child: const Text('Share'),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<List<Map<String, dynamic>>> _fetchFollowers(String? userId) async {
  final _supabase = Supabase.instance.client;
  
  if (userId == null) return [];

  try {
    print('Fetching followers for user: $userId');
    
    // Step 1: Get follower IDs from followers table
    final followersResponse = await _supabase
        .from('followers')
        .select('follower_id')
        .eq('following_id', userId) // People who follow me
        .order('created_at', ascending: false);

    print('Raw followers response: $followersResponse');
    
    final followerIds = followersResponse.map((f) => f['follower_id'] as String).toList();
    
    if (followerIds.isEmpty) {
      print('No followers found');
      return [];
    }

    print('Follower IDs: $followerIds');
    
    // Step 2: Get user profiles for these follower IDs
    final usersResponse = await _supabase
        .from('user_profiles')
        .select('*')
        .inFilter('user_id', followerIds);

    print('User profiles response: $usersResponse');
    
    return List<Map<String, dynamic>>.from(usersResponse);
    
  } catch (e) {
    print('Error fetching followers: $e');
    return [];
  }
}

void _buildCommentSheet(BuildContext context, int postId) {
  final _supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();

  Future<List<Map<String, dynamic>>> _fetchComments(int postId) async {
  final _supabase = Supabase.instance.client;
  
  try {
    print('Fetching comments for post: $postId');
    
    final response = await _supabase
        .from('comments')
        .select('''
          id,
          user_id,
          post_id,
          comment,
          created_at,
          updated_at,
          user_profiles!comments_user_id_fkey (username, avatar_url, name)
        ''')
        .eq('post_id', postId)
        .order('created_at', ascending: false);

    print('Raw response: $response');
    
    if (response != null && response is List) {
      print('Found ${response.length} comments');
      for (var comment in response) {
        print('Comment: ${comment['comment']}');
        print('User profile: ${comment['user_profiles']}');
      }
    }

    return List<Map<String, dynamic>>.from(response ?? []);
  } catch (e) {
    print('Error fetching comments: $e');
    print('Error details: ${e.toString()}');
    return [];
  }
}
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Comments List
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchComments(postId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error loading comments: ${snapshot.error}'),
                        );
                      }

                      final comments = snapshot.data ?? [];

                      if (comments.isEmpty) {
                        return const Center(
                          child: Text(
                            'No comments yet. Be the first to comment!',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final userProfile = comment['user_profiles'] as Map<String, dynamic>? ?? {};
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: CircleAvatar(
                                backgroundImage: userProfile['avatar_url'] != null
                                    ? NetworkImage(userProfile['avatar_url'])
                                    : null,
                                child: userProfile['avatar_url'] == null
                                    ? Text(userProfile['username']?.toString().substring(0, 1).toUpperCase() ?? 'U')
                                    : null,
                              ),
                              title: Text(
                                userProfile['username'] ?? 'Unknown User',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment['comment']),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(comment['created_at']),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                
                // Comment Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final commentText = _commentController.text.trim();
                        if (commentText.isEmpty) return;

                        try {
                          final userId = _supabase.auth.currentUser?.id;
                          if (userId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please login to comment')),
                            );
                            return;
                          }

                          await _supabase.from('comments').insert({
                            'user_id': userId,
                            'post_id': postId,
                            'comment': commentText,
                            'created_at': DateTime.now().toIso8601String(),
                          });

                          // First get the current comment count
final response = await _supabase
    .from('posts')
    .select('commentCount')
    .eq('id', postId)
    .single();

final currentCount = (response['commentCount'] as int?) ?? 0;
final newCount = currentCount + 1;

// Then update with the new value
await _supabase
    .from('posts')
    .update({
      'commentCount': newCount
    })
    .eq('id', postId);

                          _commentController.clear();
                          setState(() {}); // Refresh comments
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Comment added')),
                          );
                        } catch (e) {
                          print('Error adding comment: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}

String _formatDate(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return DateFormat('MMM dd, yyyy').format(date);
  } catch (e) {
    return dateString;
  }
}

  String _getSource(dynamic post) {
    try {
      final evidence = post['evidence'];
      if (evidence is Map &&
          evidence['sources'] is List &&
          evidence['sources'].isNotEmpty) {
        return evidence['sources'][0]['name'] ?? 'Unknown';
      }
    } catch (_) {}
    return 'Unknown';
  }

  Color _getRatingColor(String? rating) {
    final lower = rating?.toLowerCase() ?? '';
    if (lower.contains('true')) return Colors.green;
    if (lower.contains('false')) return Colors.red;
    if (lower.contains('mixed') || lower.contains('partly')) return Colors.amber;
    if (lower.contains('misleading') || lower.contains('unverified')) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final displayName = _username.text.isNotEmpty
        ? _username.text
        : user?.email?.split('@').first ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline),
            const SizedBox(width: 8),
            Text(displayName),
          ],
        ),
        actions: [
          if (widget.isOwner)  // Only show settings for own profile
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Settingpage()),
              ),
            ),
        ],
      ),
      body: _isLoading
        ? Container(color:Colors.black,child: const Center(child: CircularProgressIndicator()))
        : widget.isOwner ? Container(color: Colors.black,child: _buildCurrentUserProfile()) : Container(color: Colors.black,child: _buildOtherUserProfile()),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }


  Widget _buildOtherUserProfile() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _avatarUrl != null
                      ? NetworkImage(_avatarUrl!)
                      : const NetworkImage('https://www.gravatar.com/avatar/?d=mp'),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn(_postCount.toString(), 'Posts'),
                      GestureDetector(onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BuildFollowList(widget.searchUser.id, "Followers")),
                        );
                      },child: _buildStatColumn(_followerCount.toString(), 'Followers')),
                      GestureDetector(onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) =>BuildFollowList(widget.searchUser.id,"Following")),
                        );
                      },child: _buildStatColumn(_followingCount.toString(), 'Following')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(_name.text, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(selectedProfessions.join(" | ")),
            const SizedBox(height: 8),
            Text(_bio.text),
            const SizedBox(height: 16),
           Row(
  children: [
    Expanded(
      child: Container(
        height: 40, // Fixed height
        child: OutlinedButton(
          onPressed: _isLoading ? null : _toggleFollow,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _isFollowing ? "Following" : "Follow",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: Container(
        height: 40, // Same height as follow button
        child: ElevatedButton(
          onPressed: () {
            print("@@@@here in account page:${widget.searchUser.username}");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>MessageSection(
                  receiverId: widget.searchUser.id,
                  receiverName:_name.text,
                  receiverAvatarUrl: _avatarUrl ?? '',
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text("Message"),
        ),
      ),
    ),
  ],
),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text("Posts", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            FutureBuilder(
              future: _buildPosts(widget.searchUser.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return snapshot.data ?? const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
  }
 Widget _buildCurrentUserProfile() {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _updateAvatar,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: _avatarUrl != null
                      ? NetworkImage(_avatarUrl!)
                      : const NetworkImage('https://www.gravatar.com/avatar/?d=mp'),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(_postCount.toString(), 'Posts'),
                    GestureDetector(onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BuildFollowList(_supabase.auth.currentUser!.id, "Followers")),
                      );
                    },child: _buildStatColumn(_followerCount.toString(), 'Followers')),
                    GestureDetector(onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BuildFollowList(_supabase.auth.currentUser!.id, "Following")),
                      );
                    },child: _buildStatColumn(_followingCount.toString(), 'Following')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(_name.text, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(selectedProfessions.join(" | ")),
          const SizedBox(height: 8),
          Text(_bio.text),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showEditDialog(context),
              child: const Text("Edit Profile"),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text("Your Posts", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          FutureBuilder(
            future: _buildPosts(_supabase.auth.currentUser?.id??''),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return snapshot.data ?? const SizedBox();
            },
          ),
        ],
      ),
    ),
  );
}
  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Edit Profile"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(autofocus: false,controller: _username, decoration: const InputDecoration(labelText: "Username")),
                  TextField(autofocus: false,controller: _name, decoration: const InputDecoration(labelText: "Name")),
                  TextField(autofocus: false,controller: _bio, decoration: const InputDecoration(labelText: "Bio")),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _updateAvatar, child: const Text("Change Avatar")),
                  ExpansionTile(
                    title: const Text("Professions"),
                    children: allProfessions.map((profession) {
                      return CheckboxListTile(
                        title: Text(profession),
                        value: selectedProfessions.contains(profession),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selectedProfessions.add(profession);
                            } else {
                              selectedProfessions.remove(profession);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  await _saveProfile();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<Widget> _loadFollowers(BuildContext context,String userId) async {
  try {
    final response = await Supabase.instance.client
        .from('followers')
        .select()
        .eq('following_id', userId)
        .order('created_at', ascending: false);

    if (response.isEmpty) {
      return const Center(child: Text('No followers yet'));
    }

    // Get all follower user profiles in a single query for better performance
    final followerIds = response.map((follower) => follower['follower_id']).toList();
    
    final userProfiles = await Supabase.instance.client
        .from('user_profiles')
        .select('user_id, username, avatar_url')
        .inFilter('user_id', followerIds);

    // Create a map for quick lookup
    final profileMap = <String, Map<String, dynamic>>{};
    for (final profile in userProfiles) {
      profileMap[profile['user_id']] = profile;
    }

    return ListView.builder(
      itemCount: response.length,
      itemBuilder: (context, index) {
        final follower = response[index];
        final profile = profileMap[follower['follower_id']];
        
        return ListTile(
          leading: profile?['avatar_url'] != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(profile!['avatar_url']),
                )
              : const CircleAvatar(
                  child: Icon(Icons.person),
                ),
          title: Text(profile?['username'] ?? 'Unknown User'),
          subtitle: Text(
            DateTime.parse(follower['created_at']).toString().split('.')[0],
          ),
          onTap: () {
           Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Accountpage(
                  isOwner: false,
                  searchUser: UserModel(
                    id: follower['follower_id'],
                    username: profile?['username'] ?? 'Unknown',
                    avatarUrl: profile?['avatar_url'] ?? '',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } catch (e) {
    debugPrint('Error loading followers: $e');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Error loading followers: $e'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class BuildFollowList extends StatefulWidget {
  final String searchUser;
  final String type;
  
  const BuildFollowList(this.searchUser, this.type, {super.key});

  @override
  State<BuildFollowList> createState() => _BuildFollowListState();
}

class _BuildFollowListState extends State<BuildFollowList> {
  late Future<Widget> _followersFuture;

  @override
  void initState() {
    super.initState();
    _followersFuture = _loadFollowers(context,widget.searchUser);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.black,
        child: FutureBuilder<Widget>(
          future: _followersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _followersFuture = _loadFollowers(context,widget.searchUser);
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            
            return snapshot.data ?? const Center(child: Text('No data available'));
          },
        ),
      ),
    );
  }
}