import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _bookmarkedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookmarkedPosts();
  }

  Future<void> _fetchBookmarkedPosts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // First, get all bookmarked post IDs for this user
      final bookmarksResponse = await _supabase
          .from('bookmarks')
          .select('post_id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (bookmarksResponse == null || bookmarksResponse.isEmpty) {
        setState(() {
          _bookmarkedPosts = [];
          _isLoading = false;
        });
        return;
      }

      // Extract post IDs from bookmarks
      final postIds = bookmarksResponse
          .map<int>((bookmark) => bookmark['post_id'] as int)
          .toList();

      // Fetch the actual post details from the posts table
      final postsResponse = await _supabase
          .from('posts')
          .select()
          .inFilter('id', postIds);

      // Combine bookmark info with post details
      final combinedData = bookmarksResponse.map((bookmark) {
        final post = postsResponse.firstWhere(
          (post) => post['id'] == bookmark['post_id'],
          orElse: () => <String, dynamic>{},
        );
        return {
          ...bookmark,
          'posts': post, // Keep the same structure as your original code
        };
      }).toList();

      setState(() {
        _bookmarkedPosts = combinedData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching bookmarks: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBookmark(int postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);

      // Refresh the list
      await _fetchBookmarkedPosts();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from saved')),
      );
    } catch (e) {
      print('Error removing bookmark: $e');
    }
  }
  
  void _handleItemTap(int postId) {
  showGeneralDialog(
    context: context,
    pageBuilder: (context, animation, secondaryAnimation) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Post Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildOptionItem(Icons.bookmark, 'Save Post', () {
                  Navigator.pop(context);
                  _addPostToBookmarks(postId);
                }),
                _buildOptionItem(Icons.share, 'Share Post', () {
                  Navigator.pop(context);
                  _sharePost(postId);
                }),
                _buildOptionItem(Icons.report, 'Report Post', () {
                  Navigator.pop(context);
                  _reportPost(postId);
                }),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    },
  );
}

Widget _buildOptionItem(IconData icon, String text, VoidCallback onTap) {
  return ListTile(
    leading: Icon(icon),
    title: Text(text),
    onTap: onTap,
  );
}

// Example methods that would be called
Future<void> _addPostToBookmarks(int postId) async {
  // Your bookmark logic here
  print('Bookmark post: $postId');
}

Future<void> _sharePost(int postId) async {
  // Your share logic here
  print('Share post: $postId');
}

Future<void> _reportPost(int postId) async {
  // Your report logic here
  print('Report post: $postId');
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Posts'),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_outlined, size: 20),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarkedPosts.isEmpty
              ? const Center(
                  child: Text(
                    'No saved posts yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookmarkedPosts.length,
                  itemBuilder: (context, index) {
                    final bookmark = _bookmarkedPosts[index];
                    final post = bookmark['posts'] as Map<String, dynamic>? ?? {};

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          post['claim'] ?? 'No title',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: post['risk_level'] != null
                            ? Text(
                                post['risk_level']!.length > 100
                                    ? '${post['risk_level']!.substring(0, 100)}...'
                                    : post['risk_level']!,
                                style: const TextStyle(color: Colors.grey),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.bookmark, color: Colors.white),
                          onPressed: () => _removeBookmark(post['id']),
                        ),
                        onTap: () {
                          _handleItemTap(post['id']);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}