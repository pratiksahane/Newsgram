import 'package:flutter/material.dart';
import 'package:newsgram/storyViewer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class Stories extends StatefulWidget {
  const Stories({super.key});

  @override
  State<Stories> createState() => _StoriesState();
}

class _StoriesState extends State<Stories> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _storiesFuture; // Use Future instead of List

  @override
  void initState() {
    super.initState();
    _storiesFuture = _fetchAllStories(); // Initialize Future
  }

  // Convert to return Future instead of void
  Future<List<Map<String, dynamic>>> _fetchAllStories() async {
    try {
      // Fetch all active stories with user profiles
      final storiesResponse = await _supabase
          .from('stories')
          .select('''
            *,
            user_profiles!stories_user_id_fkey (username, avatar_url)
          ''')
          .gte('expires_at', DateTime.now().toIso8601String())
          .eq('is_archived', false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(storiesResponse);
    } catch (e) {
      print('Error fetching stories: $e');
      throw e; // Throw error to be handled by FutureBuilder
    }
  }

  // Add refresh method for RefreshIndicator
  Future<void> _refreshStories() async {
    setState(() {
      _storiesFuture = _fetchAllStories();
    });
    setState(() {}); // Trigger UI update
  }

  void _viewStory(int index, List<Map<String, dynamic>> stories) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewer(
          stories: stories,
          initialIndex: index,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchUserProfile(String? userId) async {
    if (userId == null) return null;
    
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('username, avatar_url')
          .eq('user_id', userId)
          .single();
      
      return response;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  void _showCreateStoryOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Create story from gallery'),
              onTap: () {
                Navigator.pop(context);
                // _createStoryFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Create story with camera'),
              onTap: () {
                Navigator.pop(context);
                // _createStoryWithCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshStories, // Add RefreshIndicator
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _storiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 120,
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Container(
              height: 120,
              child: Center(child: Text('Error: ${snapshot.error}')),
            );
          }

          final stories = snapshot.data ?? [];
          if (stories.isEmpty) {

            final currentUser = _supabase.auth.currentUser;
            final currentUserId = currentUser?.id;

            // return Container(
            //   height: 120,
            //   margin: const EdgeInsets.symmetric(vertical: 8),
            //   child: Center(
            //     child: Text(
            //       'No stories available',
            //       style: TextStyle(color: Colors.grey[600]),
            //     ),
            //   ),
            // );
            
            return Container(
              height: 120,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _fetchUserProfile(currentUserId),
                builder: (context, snapshot) {
                  final userProfile = snapshot.data;
                  final avatarUrl = userProfile?['avatar_url'];
                  final username = userProfile?['username'] ?? 'Your Story';
                  
                  return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Your Story Circle
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          _showCreateStoryOptions();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  // User Avatar
                                  CircleAvatar(
                                    radius: 38,
                                    backgroundColor: Colors.grey[300],
                                    foregroundImage: avatarUrl != null 
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null
                                        ? const Icon(Icons.person, size: 30, color: Colors.grey)
                                        : null,
                                  ),
                                  // Add Story Icon
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Username
                              SizedBox(
                                width: 70,
                                child: Text(
                                  username,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }
          
          return Container(
            height: 120,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: stories.length,
                itemBuilder: (context, index) {
                  final story = stories[index];
                  final userProfile = story['user_profiles'] as Map<String, dynamic>? ?? {};
                  final username = userProfile['username'] ?? 'Unknown';
                  final avatarUrl = userProfile['avatar_url'];
              
                  return GestureDetector(
                    onTap: () => _viewStory(index, stories),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          // Story circle with gradient border
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.purple, Colors.pink, Colors.orange],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 35,
                                foregroundImage: avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                backgroundColor: Colors.grey[200],
                                child: avatarUrl == null
                                    ? const Icon(Icons.person, size: 24)
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Username
                          SizedBox(
                            width: 70,
                            child: Text(
                              username.length > 8 ? '${username.substring(0, 8)}...' : username,
                              style: const TextStyle(fontSize: 15),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}