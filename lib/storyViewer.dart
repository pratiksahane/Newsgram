import 'package:flutter/material.dart';
import 'package:newsgram/accountPage.dart';
import 'package:newsgram/userModel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class StoryViewer extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const StoryViewer({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  final _supabase = Supabase.instance.client;
  late Timer _storyTimer;
  late AnimationController _progressController;
  final Duration _storyDuration = const Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    )..addListener(() {
        setState(() {});
      });
    
    _startTimer();
  }

  @override
  void dispose() {
    _storyTimer.cancel();
    _progressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _progressController.reset();
    _progressController.forward();
    
    _storyTimer = Timer(_storyDuration, () {
      _nextStory();
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _pauseTimer() {
    _storyTimer.cancel();
    _progressController.stop();
  }

  void _resumeTimer() {
    final remaining = _storyDuration * (1 - _progressController.value);
    _storyTimer = Timer(remaining, _nextStory);
    _progressController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Story content
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: (index) {
              _storyTimer.cancel();
              setState(() {
                _currentIndex = index;
              });
              _startTimer();
            },
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              final userProfile = story['user_profiles'] as Map<String, dynamic>? ?? {};
              final username = userProfile['username'] ?? 'Unknown';
              final mediaUrl = story['media_url'];
              final content = story['content'];

              return GestureDetector(
                onTapDown: (_) => _pauseTimer(),
                onTapUp: (_) => _resumeTimer(),
                onLongPress: () => _pauseTimer(),
                onLongPressEnd: (_) => _resumeTimer(),
                child: Container(
                  color: Colors.black,
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (mediaUrl != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.network(
                            mediaUrl,
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.6,
                            fit: BoxFit.contain,
                          ),
                        ),
                      if (content != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Top bar with user info and progress
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Progress indicators with animation
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: List.generate(widget.stories.length, (index) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Stack(
                            children: [
                              // Background
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[600],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // Progress
                              if (index == _currentIndex)
                                AnimatedBuilder(
                                  animation: _progressController,
                                  builder: (context, child) {
                                    return FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _progressController.value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else if (index < _currentIndex)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                // User info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        foregroundImage: NetworkImage(
                          widget.stories[_currentIndex]['user_profiles']?['avatar_url'] ?? '',
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          final userId = widget.stories[_currentIndex]['user_id'];
                          Navigator.pushReplacement(context, MaterialPageRoute(
                            builder: (context) => Accountpage(isOwner: _supabase.auth.currentUser!.id==userId, searchUser: UserModel(
                    id: userId,
                    username:  widget.stories[_currentIndex]['user_profiles']?['username'] ?? 'Unknown',
                    avatarUrl: widget.stories[_currentIndex]['user_profiles']?['avatar_url'] ?? '',
                  ),),
                          ));
                        },
                        child: Text(
                          widget.stories[_currentIndex]['user_profiles']?['username'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Story timer indicator
                      Text(
                        '${(_storyDuration.inSeconds - (_progressController.value * _storyDuration.inSeconds)).ceil()}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Close button
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // Like and Reply buttons at the bottom
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Like button
                _buildLikeButton(),
                const SizedBox(width: 20),
                // Reply button
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Reply',
                  onTap: () {
                    _handleReply(widget.stories[_currentIndex]['id']);
                  },
                ),
                _buildActionButton(icon: Icons.more_vert, label: "Settings", onTap: (){
                  _buildsettingsSheet(context,widget.stories[_currentIndex]['id']);
                })
              ],
            ),
          ),

          // Navigation controls - Left side for previous
          Positioned(
            left: 0,
            top: 100,
            bottom: 100,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.3,
              child: GestureDetector(
                onTap: _previousStory,
                onLongPress: () => _pauseTimer(),
                onLongPressEnd: (_) => _resumeTimer(),
              ),
            ),
          ),

          // Navigation controls - Right side for next
          Positioned(
            right: 0,
            top: 100,
            bottom: 100,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.3,
              child: GestureDetector(
                onTap: _nextStory,
                onLongPress: () => _pauseTimer(),
                onLongPressEnd: (_) => _resumeTimer(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _buildsettingsSheet(BuildContext context, int storyId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
  leading: const Icon(Icons.delete, color: Colors.red),
  title: const Text('Delete Story', style: TextStyle(color: Colors.red)),
  onTap: () async {
    Navigator.pop(context); // Close the menu immediately
    
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to delete story')),
      );
      return;
    }

    // Show confirmation dialog
    final bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text('Are you sure you want to delete this story? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmDelete) {
      await _deleteStory(storyId, currentUserId);
    }
  },
),
            ListTile(
              leading: const Icon(Icons.highlight),
              title: const Text('Add to highlights'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to highlights')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Close'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStory(int storyId, String currentUserId) async {
  try {
    // First verify the user owns the story before deleting
    final storyResponse = await _supabase
        .from('stories')
        .select('user_id, media_url')
        .eq('id', storyId)
        .single();

    if (storyResponse['user_id'] != currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own stories')),
      );
      return;
    }

    // Delete from database
    await _supabase
        .from('stories')
        .delete()
        .eq('id', storyId)
        .eq('user_id', currentUserId);

    // Optional: Delete associated media file from storage
    final mediaUrl = storyResponse['media_url'];
    if (mediaUrl != null) {
      try {
        final fileName = mediaUrl.split('/').last;
        await _supabase.storage.from('stories').remove([fileName]);
      } catch (e) {
        print('Error deleting media file: $e');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story deleted successfully')),
    );

    // Navigate back if this was the last story
    if (widget.stories.length == 1) {
      Navigator.pop(context);
    } else {
      // Remove from current list and update UI
      setState(() {
        widget.stories.removeWhere((story) => story['id'] == storyId);
      });
    }

  } catch (e) {
    print('Error deleting story: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error deleting story: ${e.toString()}')),
    );
  }
}
  // Action button widget
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        _pauseTimer();
        onTap();
        _resumeTimer();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle like action
  void _handleLike(int storyId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to like stories')),
      );
      return;
    }

    try {
      final storyResponse = await _supabase
          .from('stories')
          .select('likes')
          .eq('id', storyId)
          .single();

      final currentLikes = storyResponse['likes'] as String? ?? '';
      final likesList = currentLikes.isNotEmpty ? currentLikes.split(',') : [];
      
      if (likesList.contains(currentUserId)) {
        likesList.remove(currentUserId);
      } else {
        likesList.add(currentUserId);
      }

      final newLikes = likesList.join(',');
      await _supabase
          .from('stories')
          .update({'likes': newLikes})
          .eq('id', storyId);

      setState(() {
        final updatedStory = Map<String, dynamic>.from(widget.stories[_currentIndex]);
        updatedStory['likes'] = newLikes;
        widget.stories[_currentIndex] = updatedStory;
      });

    } catch (e) {
      print('Error liking story: $e');
    }
  }

  Widget _buildLikeButton() {
    final currentStory = widget.stories[_currentIndex];
    final currentLikes = currentStory['likes'] as String? ?? '';
    final likesList = currentLikes.isNotEmpty ? currentLikes.split(',') : [];
    final currentUserId = _supabase.auth.currentUser?.id;
    final isLiked = currentUserId != null && likesList.contains(currentUserId);
    final likeCount = likesList.length;

    return GestureDetector(
      onTap: () {
        _pauseTimer();
        _handleLike(currentStory['id']);
        _resumeTimer();
      },
      onDoubleTap: () {
        _pauseTimer();
        if (likeCount > 0) {
          _showLikes(currentStory['id']);
        }
        _resumeTimer();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              likeCount > 0 ? likeCount.toString() : 'Like',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLikes(int storyId) async {
    try {
      final storyResponse = await _supabase
          .from('stories')
          .select('likes')
          .eq('id', storyId)
          .single();

      final likesString = storyResponse['likes'] as String? ?? '';
      final likedUserIds = likesString.isNotEmpty ? likesString.split(',') : [];
      
      if (likedUserIds.isEmpty) return;

      final usersResponse = await _supabase
          .from('user_profiles')
          .select('user_id, username, avatar_url')
          .inFilter('user_id', likedUserIds);

      final users = List<Map<String, dynamic>>.from(usersResponse);

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
    }
  }

  // Handle reply action
  void _handleReply(int storyId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reply to Story',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Type your reply...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reply sent')),
                  );
                },
                child: const Text('Send Reply'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}