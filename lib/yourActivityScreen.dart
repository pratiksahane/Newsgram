// lib/screens/your_activity_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class YourActivityScreen extends StatefulWidget {
  const YourActivityScreen({super.key});

  @override
  State<YourActivityScreen> createState() => _YourActivityScreenState();
}

class _YourActivityScreenState extends State<YourActivityScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _stories = [];
  List<Map<String, dynamic>> _likes = [];
  List<Map<String, dynamic>> _comments = [];
  
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchUserActivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() => _selectedTab = _tabController.index);
    }
  }

  Future<void> _fetchUserActivity() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Fetch all data in parallel
      await Future.wait([
        _fetchPosts(userId),
        _fetchStories(userId),
        _fetchLikes(userId),
        _fetchComments(userId),
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activity: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchPosts(String userId) async {
    try {
      // First get posts
      final postsResponse = await _supabase
          .from('posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final posts = List<Map<String, dynamic>>.from(postsResponse);
      
      // Get like counts for each post
      for (var post in posts) {
        try {
          final postIdStr = post['id'].toString(); // Convert to string
          
          final likesResponse = await _supabase
              .from('likes')
              .select()
              .eq('post_id', postIdStr); // Changed to 'pont_id'
          
          final commentsResponse = await _supabase
              .from('comments')
              .select()
              .eq('post_id', postIdStr);
          
          // Get user profile for the post
          final userResponse = await _supabase
              .from('user_profiles')
              .select()
              .eq('user_id', post['user_id'])
              .maybeSingle()
              .onError((error, stackTrace) => null);

          post['likes_count'] = List<Map<String, dynamic>>.from(likesResponse).length;
          post['comments_count'] = List<Map<String, dynamic>>.from(commentsResponse).length;
          post['user_profile'] = userResponse;
          
        } catch (e) {
          print('Error processing post ${post['id']}: $e');
          // Set default values if there's an error
          post['likes_count'] = 0;
          post['comments_count'] = 0;
          post['user_profile'] = null;
        }
      }
      
      setState(() => _posts = posts);
    } catch (e) {
      print('Error fetching posts: $e');
      setState(() => _posts = []);
    }
  }

  Future<void> _fetchStories(String userId) async {
    try {
      final response = await _supabase
          .from('stories')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final stories = List<Map<String, dynamic>>.from(response);
      
      // Get view counts for each story
      for (var story in stories) {
        try {
          final viewsResponse = await _supabase
              .from('story_views')
              .select()
              .eq('story_id', story['id']);
          
          // Get user profile for the story
          final userResponse = await _supabase
              .from('user_profiles')
              .select()
              .eq('user_id', story['user_id'])
              .maybeSingle()
              .onError((error, stackTrace) => null);

          story['views_count'] = List<Map<String, dynamic>>.from(viewsResponse).length;
          story['user_profile'] = userResponse;
        } catch (e) {
          print('Error processing story ${story['id']}: $e');
          story['views_count'] = 0;
          story['user_profile'] = null;
        }
      }
      
      setState(() => _stories = stories);
    } catch (e) {
      print('Error fetching stories: $e');
      setState(() => _stories = []);
    }
  }

Future<void> _fetchLikes(String userId) async {
  try {
    final response = await _supabase
        .from('likes')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final likes = List<Map<String, dynamic>>.from(response);
    
    // Get post details for each like
    for (var like in likes) {
      if (like['post_id'] != null) {
        try {
          final postIdStr = like['post_id'].toString();
          
          final postResponse = await _supabase
              .from('posts')
              .select()
              .eq('id', postIdStr)
              .eq('user_id', userId)
              .maybeSingle()
              .onError((error, stackTrace) => null);
          
          if (postResponse != null) {
            // Get like count for this post
            final likesResponse = await _supabase
                .from('likes')
                .select()
                .eq('post_id', postIdStr);
            
            // Get comments count for this post
            final commentsResponse = await _supabase
                .from('comments')
                .select()
                .eq('post_id', postIdStr);
            
            final userResponse = await _supabase
                .from('user_profiles')
                .select()
                .eq('user_id', postResponse['user_id'])
                .maybeSingle()
                .onError((error, stackTrace) => null);
            
            // Add the calculated counts to the post data
            like['target'] = {
              ...postResponse,
              'likes_count': List<Map<String, dynamic>>.from(likesResponse).length,
              'comments_count': List<Map<String, dynamic>>.from(commentsResponse).length,
            };
            like['target_type'] = 'post';
            like['target_user'] = userResponse;
          }
        } catch (e) {
          print('Error fetching target for like: $e');
          like['target'] = null;
        }
      }
    }
    
    // Remove likes where target doesn't exist
    likes.removeWhere((like) => like['target'] == null);
    
    setState(() => _likes = likes);
  } catch (e) {
    print('Error fetching likes: $e');
    setState(() => _likes = []);
  }
}

Future<void> _fetchComments(String userId) async {
  try {
    final response = await _supabase
        .from('comments')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final comments = List<Map<String, dynamic>>.from(response);
    
    // Get post details and user profiles for each comment
    for (var comment in comments) {
      try {
        final postIdStr = comment['post_id'].toString(); // Convert to string
        
        final postResponse = await _supabase
            .from('posts')
            .select()
            .eq('id', postIdStr)
            .maybeSingle()
            .onError((error, stackTrace) => null);
        
        final userResponse = await _supabase
            .from('user_profiles')
            .select()
            .eq('user_id', comment['user_id'])
            .maybeSingle()
            .onError((error, stackTrace) => null);
        
        if (postResponse != null) {
          // Get like count for this post
          final likesResponse = await _supabase
              .from('likes')
              .select()
              .eq('post_id', postIdStr);
          
          // Get comments count for this post
          final commentsResponse = await _supabase
              .from('comments')
              .select()
              .eq('post_id', postIdStr);

          final postUserResponse = await _supabase
              .from('user_profiles')
              .select()
              .eq('user_id', postResponse['user_id'])
              .maybeSingle()
              .onError((error, stackTrace) => null);

          // Add the calculated counts to the post data
          comment['post'] = {
            ...postResponse,
            'likes_count': List<Map<String, dynamic>>.from(likesResponse).length,
            'comments_count': List<Map<String, dynamic>>.from(commentsResponse).length,
          };
          comment['user_profile'] = userResponse;
          comment['post_user_profile'] = postUserResponse;
        }
      } catch (e) {
        print('Error processing comment ${comment['id']}: $e');
        comment['post'] = null;
        comment['user_profile'] = null;
        comment['post_user_profile'] = null;
      }
    }
    
    // Remove comments where post doesn't exist
    comments.removeWhere((comment) => comment['post'] == null);
    
    setState(() => _comments = comments);
  } catch (e) {
    print('Error fetching comments: $e');
    setState(() => _comments = []);
  }
}

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 30) {
        return DateFormat('MMM d, yyyy').format(date);
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Activity'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_outlined, size: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Posts', icon: Icon(Icons.grid_on)),
            Tab(text: 'Stories', icon: Icon(Icons.circle)),
            Tab(text: 'Likes', icon: Icon(Icons.favorite)),
            Tab(text: 'Comments', icon: Icon(Icons.comment)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                _buildStoriesTab(),
                _buildLikesTab(),
                _buildCommentsTab(),
              ],
            ),
    );
  }

  Widget _buildPostsTab() {
    if (_posts.isEmpty) {
      return _buildEmptyState('No posts yet', Icons.grid_on);
    }

    return RefreshIndicator(
      onRefresh: _fetchUserActivity,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostItem(post);
        },
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () => _showPostDetails(post),
      child: Stack(
        children: [
          post['media_url'] != null
              ? CachedNetworkImage(
                  imageUrl: post['media_url']!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(color: Colors.grey[300]),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                )
              : Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.description, color: Colors.grey),
                ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Row(
              children: [
                const Icon(Icons.favorite, size: 12, color: Colors.white),
                const SizedBox(width: 2),
                Text(
                  '${post['likes_count'] ?? 0}',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.comment, size: 12, color: Colors.white),
                const SizedBox(width: 2),
                Text(
                  '${post['comments_count'] ?? 0}',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesTab() {
    if (_stories.isEmpty) {
      return _buildEmptyState('No stories yet', Icons.circle);
    }

    return RefreshIndicator(
      onRefresh: _fetchUserActivity,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stories.length,
        itemBuilder: (context, index) {
          final story = _stories[index];
          return _buildStoryItem(story);
        },
      ),
    );
  }

  Widget _buildStoryItem(Map<String, dynamic> story) {
    final userProfile = story['user_profile'] ?? {};
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: userProfile['avatar_url'] != null
              ? CachedNetworkImageProvider(userProfile['avatar_url']!)
              : null,
          child: userProfile['avatar_url'] == null
              ? Text(userProfile['username']?[0] ?? 'U')
              : null,
        ),
        title: Text(
          userProfile['username'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${story['views_count'] ?? 0} views • ${_formatDate(story['created_at'])}',
        ),
        trailing: story['is_video'] == true
            ? const Icon(Icons.videocam, color: Colors.blue)
            : const Icon(Icons.image, color: Colors.green),
        onTap: () => _showStoryDetails(story),
      ),
    );
  }

  Widget _buildLikesTab() {
    if (_likes.isEmpty) {
      return _buildEmptyState('No likes yet', Icons.favorite_border);
    }

    return RefreshIndicator(
      onRefresh: _fetchUserActivity,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _likes.length,
        itemBuilder: (context, index) {
          final like = _likes[index];
          return _buildLikeItem(like);
        },
      ),
    );
  }

Widget _buildLikeItem(Map<String, dynamic> like) {
  final target = like['target'] ?? {};
  final targetUser = like['target_user'] ?? {};
  final targetType = like['target_type'] ?? 'post';
  
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: CircleAvatar(
        backgroundImage: targetUser['avatar_url'] != null
            ? CachedNetworkImageProvider(targetUser['avatar_url']!)
            : null,
        child: targetUser['avatar_url'] == null
            ? Text(targetUser['username']?[0] ?? 'U')
            : null,
      ),
      title: Text(
        targetUser['username'] ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Liked ${targetType == 'post' ? 'Post' : 'Story'} • ${_formatDate(like['created_at'])}',
      ),
      trailing: targetType == 'post'
          ? const Icon(Icons.grid_on, color: Colors.blue)
          : const Icon(Icons.circle, color: Colors.purple),
      onTap: () {
        if (targetType == 'post') {
          // Pass the complete target data which should include the calculated counts
          _showPostDetails(target);
        } else {
          _showStoryDetails(target);
        }
      },
    ),
  );
}

  Widget _buildCommentsTab() {
    if (_comments.isEmpty) {
      return _buildEmptyState('No comments yet', Icons.comment);
    }

    return RefreshIndicator(
      onRefresh: _fetchUserActivity,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _comments.length,
        itemBuilder: (context, index) {
          final comment = _comments[index];
          return _buildCommentItem(comment);
        },
      ),
    );
  }

Widget _buildCommentItem(Map<String, dynamic> comment) {
  final userProfile = comment['user_profile'] ?? {};
  final postUserProfile = comment['post_user_profile'] ?? {};
  final post = comment['post'] ?? {};
  
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: CircleAvatar(
        backgroundImage: userProfile['avatar_url'] != null
            ? CachedNetworkImageProvider(userProfile['avatar_url']!)
            : null,
        child: userProfile['avatar_url'] == null
            ? Text(userProfile['username']?[0] ?? 'U')
            : null,
      ),
      title: Text(
        userProfile['username'] ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment['comment'] ?? 'No comment text'),
          const SizedBox(height: 4),
          Text(
            'On ${postUserProfile['username'] != null ? "${postUserProfile['username']}'s post" : "a post"} • ${_formatDate(comment['created_at'])}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      onTap: () => _showPostDetails(post),
    ),
  );
}

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _fetchUserActivity,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

void _showPostDetails(Map<String, dynamic> post) async {
  // First check if the post already has the calculated counts
  if (post['likes_count'] == null || post['comments_count'] == null) {
    // If not, fetch the complete post data
    try {
      final postIdStr = post['id'].toString();
      final postResponse = await _supabase
          .from('posts')
          .select()
          .eq('id', postIdStr)
          .single();

      if (postResponse != null) {
        // Get like count from likes table
        final likesResponse = await _supabase
            .from('likes')
            .select()
            .eq('post_id', postIdStr);
        
        // Get comments count from comments table
        final commentsResponse = await _supabase
            .from('comments')
            .select()
            .eq('post_id', postIdStr);
        
        post['likes_count'] = List<Map<String, dynamic>>.from(likesResponse).length;
        post['comments_count'] = List<Map<String, dynamic>>.from(commentsResponse).length;
      }
    } catch (e) {
      print('Error fetching post details: $e');
      // Set default values if there's an error
      post['likes_count'] = post['likes_count'] ?? 0;
      post['comments_count'] = post['comments_count'] ?? 0;
    }
  }

  if (!mounted) return;
  
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Post Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (post['media_url'] != null && post['media_url'].isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: CachedNetworkImage(
                    imageUrl: post['media_url']!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.error, size: 50),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post['claim'] != null && post['claim'].isNotEmpty)
                      Text(
                        post['claim'],
                        style: const TextStyle(fontSize: 16),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Likes: ${post['likes_count'] ?? 0}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Comments: ${post['comments_count'] ?? 0}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Posted: ${_formatDate(post['created_at'])}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  void _showStoryDetails(Map<String, dynamic> story) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Story Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (story['media_url'] != null)
              story['is_video'] == true
                  ? const Icon(Icons.videocam, size: 64, color: Colors.blue)
                  : CachedNetworkImage(
                      imageUrl: story['media_url']!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Icon(Icons.error, size: 50),
                      ),
                    ),
            const SizedBox(height: 12),
            Text(
              'Views: ${story['views_count'] ?? 0}',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'Created: ${_formatDate(story['created_at'])}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (story['expires_at'] != null)
              Text(
                'Expires: ${_formatDate(story['expires_at'])}',
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}