// lib/screens/conversations_list_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:newsgram/messageSection.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _setupRealtimeUpdates();
  }

Future<void> _fetchConversations() async {
  try {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Get messages where current user is either sender or receiver
    final messagesResponse = await _supabase
        .from('messages')
        .select()
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false);

    // Get unique participant IDs
    final participantIds = _getParticipantIds(
        List<Map<String, dynamic>>.from(messagesResponse), userId);
    
    if (participantIds.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // Fetch basic profile info
    final profilesResponse = await _supabase
    .from('user_profiles')
    .select('user_id, username, avatar_url')
    .inFilter('user_id', participantIds);

    // Combine data
    _conversations = _combineConversationsData(
        List<Map<String, dynamic>>.from(messagesResponse),
        List<Map<String, dynamic>>.from(profilesResponse),
        userId);

    setState(() => _isLoading = false);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading conversations: $e')),
      );
    }
  }
}

  List<String> _getParticipantIds(List<Map<String, dynamic>> messages, String userId) {
    print("@@@@here in getParticipantIds");
    final ids = <String>{};
    for (final msg in messages) {
      if (msg['sender_id'] != userId) ids.add(msg['sender_id']);
      if (msg['receiver_id'] != userId) ids.add(msg['receiver_id']);
    }
    return ids.toList();
  }

List<Map<String, dynamic>> _combineConversationsData(
  List<Map<String, dynamic>> messages,
  List<Map<String, dynamic>> profiles,
  String userId,
) {
  final conversations = <Map<String, dynamic>>[];
  final profileMap = {for (var p in profiles) p['user_id'].toString(): p};

  // Group messages by participant
  final messageMap = <String, List<Map<String, dynamic>>>{};
  for (final msg in messages) {
    final otherUserId = msg['sender_id'].toString() == userId 
        ? msg['receiver_id'].toString()
        : msg['sender_id'].toString();
    
    messageMap.putIfAbsent(otherUserId, () => []).add(msg);
  }

  // Create conversation items
  for (final entry in messageMap.entries) {
    final otherUser = profileMap[entry.key];
    if (otherUser == null) continue;

    final lastMessage = entry.value.first;
    conversations.add({
      'other_user': {
        'user_id': otherUser['user_id'],
        'username': otherUser['username'],
        // Add default avatar if needed
        'avatar_url':otherUser['avatar_url'] ?? 'null',
      },
      'last_message': lastMessage['text'] ?? '',
      'unread_count': entry.value
          .where((m) => m['receiver_id'].toString() == userId && !(m['is_read'] ?? false))
          .length,
      'updated_at': lastMessage['created_at'],
    });
  }

  // Sort by most recent
  conversations.sort((a, b) => 
      (b['updated_at'] as String).compareTo(a['updated_at'] as String));
  
  return conversations;
}

  void _setupRealtimeUpdates() {
    print("@@@@here in setupRealtimeUpdates");
    _supabase.channel('conversation_updates')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (_) => _fetchConversations(),
      ).subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showUserSearch(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Container(color: Colors.black,child: const Center(child: Text('No conversations yet')))
              : Container(color: Colors.black,
                child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                  final chat = _conversations[index];
                  final otherUser = chat['other_user'] as Map<String, dynamic>;
                  print("@@@@here in build method of ConversationsListScreen ${otherUser['avatar_url']}");
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:CachedNetworkImageProvider(otherUser['avatar_url']),
                      child: otherUser['avatar_url'] == null 
                          ? Text(otherUser['username'][0]) 
                          : null,
                    ),
                    title: Text(otherUser['username']),
                    subtitle: Text(chat['last_message']),
                    trailing: (chat['unread_count'] as int) > 0
                        ? Badge(label: Text(chat['unread_count'].toString()))
                        : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessageSection(
                          receiverId: otherUser['user_id'],
                          receiverName: otherUser['username'],
                          receiverAvatarUrl: otherUser['avatar_url'],
                        ),
                      ),
                    ),
                  );
                },
                  ),
              ),
    );
  }

  void _showUserSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _UserSearchDelegate(),
    );
  }
}

class _UserSearchDelegate extends SearchDelegate<String?> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          _searchResults.clear();
          showSuggestions(context);
        },
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return _buildEmptyState('Enter a username to search');
    }

    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildEmptyState('Search for users to start a conversation');
    }
    
    // Perform search immediately as user types
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _performSearch(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final users = snapshot.data ?? [];
        return _buildUserList(users);
      },
    );
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _performSearch(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final users = snapshot.data ?? [];
        return _buildUserList(users);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Search failed',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No users found for "$query"',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user['avatar_url'] != null && 
                            user['avatar_url'].isNotEmpty
                ? CachedNetworkImageProvider(user['avatar_url'])
                : null,
            child: user['avatar_url'] == null || user['avatar_url'].isEmpty
                ? Text(user['username'][0].toUpperCase())
                : null,
          ),
          title: Text(user['username']),
          subtitle: user['name'] != null ? Text(user['name']) : null,
          trailing: const Icon(Icons.message, color: Colors.blue),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MessageSection(
                  receiverId: user['user_id'],
                  receiverName: user['username'],
                  receiverAvatarUrl: user['avatar_url'],
                ),
              ),
            );
            close(context, user['user_id']);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _performSearch(String searchTerm) async {
    if (searchTerm.isEmpty) return [];

    try {
      final response = await _supabase
          .from('user_profiles')
          .select('user_id, username, avatar_url, name')
          .ilike('username', '%$searchTerm%')
          .neq('user_id', _supabase.auth.currentUser!.id)
          .order('username')
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }
}