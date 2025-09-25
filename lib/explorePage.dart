import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:newsgram/Widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add this package
import 'package:newsgram/displayPosts.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _explorePosts = [];
  bool _isLoading = true;
  int _currentPage = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchExplorePosts();
  }

Future<void> _fetchExplorePosts({bool loadMore = false}) async {
  try {
    if (!loadMore) {
      _currentPage = 0;
      _hasMore = true;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // First fetch posts
    final response = await _supabase
        .from('posts')
        .select('*')
        //.neq('user_id', userId)
        .order('created_at', ascending: false)
        .range(_currentPage * 20, (_currentPage + 1) * 20 - 1);

    if (response != null && response.isNotEmpty) {
      // Fetch user details for all posts
      final postUserIds = response.map((post) => post['user_id'] as String).toSet().toList();
      
      final usersResponse = await _supabase
          .from('user_profiles')
          .select('user_id, username, avatar_url')
          .inFilter('user_id', postUserIds);

      // Combine all data
      final combinedData = <Map<String, dynamic>>[];
      
      for (var post in response) {
        final user = usersResponse.firstWhere(
          (user) => user['user_id'] == post['user_id'],
          orElse: () => <String, dynamic>{},
        );
        
        final postId = post['id'].toString();
        
        // Fetch like count
        final likeCountResponse = await _supabase
            .from('likes')
            .select()
            .eq('post_id', postId);
        final likeCount = List<Map<String, dynamic>>.from(likeCountResponse).length;
        
        // Fetch comment count
        final commentCountResponse = await _supabase
            .from('comments')
            .select()
            .eq('post_id', postId);
        final commentCount = List<Map<String, dynamic>>.from(commentCountResponse).length;
        
        // Check if current user liked this post
        bool isLiked = false;
        if (userId != null) {
          final userLikeResponse = await _supabase
              .from('likes')
              .select()
              .eq('post_id', postId)
              .eq('user_id', userId)
              .maybeSingle();
          
          isLiked = userLikeResponse != null;
        }

        print("@@@@@@likesCount for post $postId: $likeCount");

        combinedData.add({
          ...post,
          'user': user,
          'likes_count': likeCount,
          'comments_count': commentCount,
          'is_liked': isLiked,
        });
      }

      setState(() {
        if (loadMore) {
          _explorePosts.addAll(combinedData);
        } else {
          _explorePosts = List<Map<String, dynamic>>.from(combinedData);
        }
        _currentPage++;
        _hasMore = response.length == 20;
        _isLoading = false;
      });
    } else {
      setState(() {
        _hasMore = false;
        _isLoading = false;
      });
    }
  } catch (e) {
    print('Error fetching explore posts: $e');
    setState(() => _isLoading = false);
  }
}

  void _likePost(int postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('likes').insert({
        'user_id': userId,
        'post_id': postId,
      });

      setState(() {
        // Update like count locally
        final index = _explorePosts.indexWhere((post) => post['id'] == postId);
        if (index != -1) {
          _explorePosts[index]['likes_count'] = (_explorePosts[index]['likes_count'] ?? 0) + 1;
          _explorePosts[index]['is_liked'] = true;
        }
      });
    } catch (e) {
      print('Error liking post: $e');
    }
  }

  void _unlikePost(int postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('likes')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);

      setState(() {
        final index = _explorePosts.indexWhere((post) => post['id'] == postId);
        if (index != -1) {
          _explorePosts[index]['likes_count'] = (_explorePosts[index]['likes_count'] ?? 1) - 1;
          _explorePosts[index]['is_liked'] = false;
        }
      });
    } catch (e) {
      print('Error unliking post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _explorePosts.isEmpty
              ? const Center(
                  child: Text(
                    'No posts to explore',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo is ScrollEndNotification &&
                        scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
                        _hasMore) {
                      _fetchExplorePosts(loadMore: true);
                    }
                    return false;
                  },
                  child: GridView.builder(
  padding: const EdgeInsets.all(1),
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    crossAxisSpacing: 1,
    mainAxisSpacing: 1,
    childAspectRatio: 0.8,
  ),
  itemCount: _explorePosts.length + (_hasMore ? 1 : 0),
  itemBuilder: (context, index) {
    if (index == _explorePosts.length) {
      return const Center(child: CircularProgressIndicator());
    }

    final post = _explorePosts[index];
    final imageUrl = post['media_url'] as String?;
    final isLiked = post['is_liked'] ?? false;
    final likesCount = post['likes_count'] ?? 0;
    print("@@@@@@likesCount: $likesCount");
    final commentsCount = post['comments_count'] ?? 0;
    
    // Safe check for multiple images
    final imageUrls = post['image_urls'] as List?;
    final hasMultipleImages = imageUrls != null && imageUrls.length > 1;

    return GestureDetector(
      onTap: () {
        _showPostDetail(context, post);
      },
      onDoubleTap: () {
        if (!isLiked) _likePost(post['id']);
      },
      child: Stack(
        children: [
          // Post image with safe null handling
          imageUrl != null && imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.error),
                  ),
                )
              : Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),

          // Multiple images indicator
          if (hasMultipleImages)
            const Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.layers,
                color: Colors.white,
                size: 16,
              ),
            ),

          // Like count and comment count overlay (only show if > 0)
          if (likesCount > 0 || commentsCount > 0)
            Positioned(
              bottom: 4,
              left: 4,
              child: Row(
                children: [
                  if (likesCount > 0) ...[
                    const Icon(Icons.favorite, size: 14, color: Colors.black),
                    const SizedBox(width: 2),
                    Text(
                      _formatCount(likesCount),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (likesCount > 0 && commentsCount > 0)
                    const SizedBox(width: 8),
                  if (commentsCount > 0) ...[
                    const Icon(Icons.comment, size: 14, color: Colors.black),
                    const SizedBox(width: 2),
                    Text(
                      _formatCount(commentsCount),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  },
),
                ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _showPostDetail(BuildContext context, Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return PostDetailSheet(
              post: post,
              scrollController: scrollController,
              onLike: _likePost,
              onUnlike: _unlikePost,
            );
          },
        );
      },
    );
  }
}

// Post Detail Bottom Sheet
class PostDetailSheet extends StatelessWidget {
  final Map<String, dynamic> post;
  final ScrollController scrollController;
  final Function(int) onLike;
  final Function(int) onUnlike;
  final SupabaseClient _supabase = Supabase.instance.client;

 PostDetailSheet({
    super.key,
    required this.post,
    required this.scrollController,
    required this.onLike,
    required this.onUnlike,
  });


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
    if (success && context.mounted) { // Check if context is still valid
      // No setState in StatelessWidget; you may trigger a callback or update parent if needed.
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

  @override
  Widget build(BuildContext context) {
    final imageUrl = post['media_url'] as String?;
    final isLiked = post['is_liked'] ?? false;
    final likesCount = post['likes_count'] ?? 0;
    final user = post['user'] as Map<String, dynamic>? ?? {};
    final username = user['username'] as String?;
    final avatarUrl = user['avatar_url'] as String?;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        color: Colors.black,
      ),
      child: Column(
        children: [
          // Header with user info
          ListTile(
            leading: CircleAvatar(
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(username ?? 'Unknown User'),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
               showMoreDialog(
                context,
                post['id'].toString(),
                post['user_id'],
                post['claim'],
                imageUrl.toString(),
                post['rating'] ?? 'Unrated',
                post['source'] ?? 'Unknown Source',
                post['evidence'],
                true
              );
              },
            ),
          ),

          // Post image
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.error, size: 50),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 50),
                          ),
                        ),
                ),
            
                Expanded(child: Text(post['claim']))
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.black,
                  ),
                  onPressed: () {
                    if (isLiked) {
                      onUnlike(post['id']);
                    } else {
                      onLike(post['id']);
                    }
                    Navigator.pop(context);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: () {
                    _buildCommentSheet(context, post['id']);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _buildShareSheet(context, post['id']);
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

}