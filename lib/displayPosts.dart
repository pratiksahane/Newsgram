import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:newsgram/accountPage.dart';
import 'package:newsgram/homepage.dart';
import 'package:newsgram/stories.dart';
import 'package:newsgram/userModel.dart';
//import 'package:newsgram/accountPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:newsgram/Widgets.dart';

class DisplayPosts extends StatefulWidget {
  const DisplayPosts({super.key});

  @override
  State<DisplayPosts> createState() => _DisplayPostsState();
}

class _DisplayPostsState extends State<DisplayPosts> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _fetchPosts();
  }

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*')
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        throw Exception("No posts found");
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      return [];
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _postsFuture = _fetchPosts();
    });
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
Future<String?> getUserName(user_id) async {
  final user = _supabase.auth.currentUser;
  if (user == null) return null;

  try {
    print("@@@@@@@here@@@@@@@");
    final response = await _supabase
        .from('user_profiles')
        .select('username')
        .eq('user_id', user_id).single();

    return response['username'] as String?;
  } catch (e) {
    debugPrint('Error fetching username: $e');
    return null;
  }
  }

  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
  try {
    final response = await _supabase
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return response;
  } catch (e) {
    print('Error fetching user profile: $e');
    return null;
  }
}

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshPosts,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Failed to load posts',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _refreshPosts,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final posts = snapshot.data ?? [];
          var user_id1;
          
          if (posts.isEmpty) {
            return const Center(
              child: Text(
                'No posts yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }
          

          return ListView.builder(
  padding: const EdgeInsets.all(8),
  itemCount: posts.length,
  itemBuilder: (context, index) {
    final post = posts[index];
    final evidence = post['evidence'] as Map<String, dynamic>? ?? {};
    final claims = evidence['claims'] as List<dynamic>? ?? [];
    final mediaUrl = post['media_url'] as String?;
    
    // Use FutureBuilder to fetch like data asynchronously
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchLikeData(post['id']),
      builder: (context, likeSnapshot) {
        var isLiked = likeSnapshot.data?['isLiked'] ?? false;
        var likeCount = likeSnapshot.data?['likeCount'] ?? 0;
        final user = getUserName(post['user_id']);
        
        return Card(
  margin: const EdgeInsets.only(bottom: 16),
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(0),
    side: const BorderSide(color: Colors.black12, width: 0.5),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header with user info and menu
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                final userModel = UserModel.fromProfile(post);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Accountpage(
                      searchUser: userModel,
                      isOwner: post['user_id'] == _supabase.auth.currentUser?.id,
                    ),
                  ),
                );
              },
              child: FutureBuilder<String?>(
                future: getUserName(post['user_id']),
                builder: (context, userSnapshot) {
                  return Row(
                    children: [
                      FutureBuilder<Map<String, dynamic>?>(
  future: _getUserProfile(post['user_id']),
  builder: (context, profileSnapshot) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[300],
      backgroundImage: profileSnapshot.data?['avatar_url'] != null
          ? CachedNetworkImageProvider(profileSnapshot.data?['avatar_url'])
          : null,
      child: profileSnapshot.data?['avatar_url'] == null
          ? Text(
              userSnapshot.data != null && userSnapshot.data!.isNotEmpty
                  ? userSnapshot.data![0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  },
),
                      const SizedBox(width: 8),
                      Text(
                        userSnapshot.connectionState == ConnectionState.waiting
                            ? 'Loading...'
                            : "${userSnapshot.data}" ?? 'unknown_user',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => showMoreDialog(
                context,
                post['id'].toString(),
                post['user_id'],
                claims.first['text'] ?? 'No claim',
                mediaUrl.toString(),
                post['rating'] ?? 'Unrated',
                post['source'] ?? 'Unknown Source',
                evidence,
                true
              ),
              child: const Icon(Icons.more_horiz, size: 24),
            ),
          ],
        ),
      ),

      // Media
      if (mediaUrl != null)
        SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.width,
          child: CachedNetworkImage(
            imageUrl: mediaUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.error, size: 40, color: Colors.grey),
            ),
          ),
        ),

      // Action buttons (Like, Comment, Share, Save)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
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
                    await _supabase
                        .from('likes')
                        .delete()
                        .eq('user_id', userId)
                        .eq('post_id', post['id']);
                  } else {
                    await _supabase
                        .from('likes')
                        .insert({
                          'user_id': userId,
                          'post_id': post['id'],
                          'created_at': DateTime.now().toIso8601String(),
                        });
                  }

                  setState(() {
                    isLiked = !isLiked;
                    likeCount = isLiked ? likeCount + 1 : likeCount - 1;
                  });
                } catch (e) {
                  print('Error liking post: $e');
                }
              },
              onDoubleTap: () {
                if (likeCount > 0) {
                  _showPostLikes(post['id']);
                }
              },
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 28,
                color: isLiked ? Colors.red : Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => _buildCommentSheet(context, post['id']),
              child: const Icon(Icons.chat_bubble_outline, size: 26),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => _buildShareSheet(context, post['id']),
              child: const Icon(Icons.send, size: 26),
            ),
            const Spacer(),
            GestureDetector(
  onTap: () => _addPostToBookmarks(post['id']),
  child: FutureBuilder(
    future: _isPostBookmarked(post['id']), // Check if bookmarked
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Icon(Icons.bookmark_border, size: 26);
      }
      
      final isBookmarked = snapshot.data ?? false;
      return Icon(
        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        size: 26,
        color: isBookmarked ? Colors.white : null, // Optional: change color when bookmarked
      );
    },
  ),
),
          ],
        ),
      ),

      // Likes count
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          '${likeCount.toString()} likes',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Claim text
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "${_supabase.auth.currentUser!.isAnonymous?"Not Verfied User":"Verfied User"} ",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              TextSpan(
                text: post['claim'] ?? 'No claim',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),

      // Risk level chip
      if (post['risk_level'] != null && post['risk_level'] != 'Unknown')
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Chip(
            backgroundColor: _getRiskColor(post['risk_level']).withOpacity(0.2),
            label: Text(
              'Risk: ${post['risk_level']}',
              style: TextStyle(
                color: _getRiskColor(post['risk_level']),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),

      // View all comments button
      if ((post['commentCount'] ?? 0) > 0)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: GestureDetector(
            onTap: () => _buildCommentSheet(context, post['id']),
            child: Text(
              'View all ${post['commentCount']} comments',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ),

      // Date
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          _formatDate(post['created_at']),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ),

      // Evidence summary (collapsible)
     Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  child: ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Evidence Summary',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          post['rating'] ?? 'No rating available',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      const SizedBox(height: 8),
      if (claims.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Key Claims:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              ...claims.take(2).map((claim) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${claim['text']}',
                  style: const TextStyle(fontSize: 13),
                ),
              )),
            ],
          ),
        ),
    ],
  ),
),
    ],
  ),
);
      },
    );
  },
);
        },
      ),
    );
  }

Future<bool> _isPostBookmarked(int postId) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return false;

  try {
    final existing = await _supabase
        .from('bookmarks')
        .select()
        .eq('user_id', userId)
        .eq('post_id', postId)
        .maybeSingle();

    return existing != null;
  } catch (e) {
    print('Error checking bookmark: $e');
    return false;
  }
}

Future<void> _addPostToBookmarks(int postId) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please login to bookmark posts')),
    );
    return;
  }

  try {
    // Check if already bookmarked
    final existing = await _supabase
        .from('bookmarks')
        .select()
        .eq('user_id', userId)
        .eq('post_id', postId)
        .maybeSingle();

    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post already bookmarked')),
      );
      return;
    }

    await _supabase.from('bookmarks').insert({
      'user_id': userId,
      'post_id': postId,
      'created_at': DateTime.now().toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post bookmarked')),
    );
  } catch (e) {
    print('Error bookmarking post: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error bookmarking post: $e')),
    );
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

void _showPostLikes(String postId) async {
  try {
    // Fetch likes for this post from the likes table
    final likesResponse = await _supabase
        .from('likes')
        .select('''
          id,
          user_id,
          created_at,
          user_profiles (username, avatar_url)
        ''')
        .eq('post_id', postId)
        .order('created_at', ascending: false);

    final likes = List<Map<String, dynamic>>.from(likesResponse);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Likes'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: likes.length,
            itemBuilder: (context, index) {
              final like = likes[index];
              final userProfile = like['user_profiles'] ?? {};
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: userProfile['avatar_url'] != null
                      ? CachedNetworkImageProvider(userProfile['avatar_url']!)
                      : null,
                  child: userProfile['avatar_url'] == null
                      ? Text(userProfile['username']?[0] ?? 'U')
                      : null,
                ),
                title: Text(userProfile['username'] ?? 'Unknown'),
                subtitle: Text(_formatDate(like['created_at'])),
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
  leading: const Icon(Icons.share),
  title: const Text('Share to your story'),
  onTap: () async {
    Navigator.pop(context);
    final success = await _addStory(context, postId);
    final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) =>Homepage(viewUser: _supabase.auth.currentUser)),
  );
  
  if (result == true) {
    setState(() {
      // Refresh stories list
    });
  }
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

Future<bool> _addStory(BuildContext context, int postId) async {
  final currentUserId = _supabase.auth.currentUser?.id;
  
  try {
    if (currentUserId == null) {
      if (context.mounted) { // Check if context is still valid
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to add story')),
        );
      }
      return false;
    }

    // Check if user already has an active story
    final existingStory = await _supabase
        .from('stories')
        .select()
        .eq('user_id', currentUserId)
        .gte('expires_at', DateTime.now().toIso8601String())
        .maybeSingle();

    if (existingStory != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have an active story')),
        );
      }
      return false;
    }

    // Get post details
    final postResponse = await _supabase
        .from('posts')
        .select('claim, media_url')
        .eq('id', postId)
        .single();

    final claim = postResponse['claim'] ?? 'Check out this post';
    final mediaUrl = postResponse['media_url'];

    // Create new story
    await _supabase.from('stories').insert({
      'user_id': currentUserId,
      'content': claim,
      'media_url': mediaUrl,
      'created_at': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story added successfully')),
      );
    }
    
    return true;
    
  } catch (e) {
    print('Error adding story: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding story: $e')),
      );
    }
    return false; // This was missing!
  }
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
}