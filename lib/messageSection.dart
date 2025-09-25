import 'package:flutter/material.dart';
import 'package:newsgram/accountPage.dart';
import 'package:newsgram/userModel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:newsgram/messageModel.dart';
import 'package:uuid/uuid.dart';

class MessageSection extends StatefulWidget {
  final String receiverId;
  final String? receiverName;
  final String? receiverAvatarUrl;

  const MessageSection({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatarUrl,
  });

  @override
  State<MessageSection> createState() => _MessageSectionState();
}

class _MessageSectionState extends State<MessageSection> {
  final _controller = ScrollController();
  final _messageController = TextEditingController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _setupRealtimeUpdates();
  }

  Future<void> _fetchMessages() async {
    try {
      print("@@@@here in messaging section page for fetching messages");
      final messages = await getConversation(widget.receiverId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching messages: $e')),
      );
    }
  }

  void _setupRealtimeUpdates() {
    print("@@@@here inside setup realtime updates");
    supabase.channel('message_updates')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final newMessage = MessageModel.fromSupabase(payload.newRecord);
          if (newMessage.receiverId == supabase.auth.currentUser?.id || 
              newMessage.senderId == supabase.auth.currentUser?.id) {
            setState(() {
              _messages.add(newMessage);
            });
            _scrollToBottom();
          }
        }
      ).subscribe();
  }

  void _scrollToBottom() {
    if (_controller.hasClients) {
      _controller.animateTo(
        _controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    print("@@@@here inside send message with text: $text");
    try {
      _messageController.clear();
      await sendMessage(
        receiverId: widget.receiverId,
        text: text,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Future<void> _sharePost(int postId) async {
    try {
      await sendPost(
        receiverId: widget.receiverId,
        postId: postId,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing post: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print("@@@@here inside build method of MessageSection");
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.receiverAvatarUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(widget.receiverAvatarUrl!),
                radius: 16,
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: 
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Accountpage(
                        searchUser: UserModel(
                          id: widget.receiverId,
                          name: widget.receiverName ?? "No Name",
                          avatarUrl: widget.receiverAvatarUrl,
                        ),
                        isOwner: widget.receiverId == supabase.auth.currentUser?.id,
                      ),
                    ),
                  );
                },
              child: Text(widget.receiverName??"No Name")
              ),
          ],
        ),
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _controller,
                      padding: const EdgeInsets.all(8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderId == supabase.auth.currentUser?.id;
                        
                        return MessageBubble(
                          message: message,
                          isMe: isMe,
                          onPostTap: message.isPostShare ? () {
                            _navigateToPost(context, message.postId!);
                          } : null,
                        );
                      },
                    ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    print("@@@@here inside build message input");
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
  
  Future<List<MessageModel>> getConversation(String receiverId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final response = await supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.${currentUserId.toString()},receiver_id.eq.${receiverId.toString()}),and(sender_id.eq.${receiverId.toString()},receiver_id.eq.${currentUserId.toString()})')
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => MessageModel.fromSupabase(item))
          .toList();
    } catch (e) {
      print("Error fetching conversation: $e");
      return [];
    }
  }
  
  Future<void> sendMessage({
    required String receiverId, 
    required String text
  }) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final message = MessageModel(
        id: const Uuid().v4(),
        senderId: currentUserId,
        receiverId: receiverId,
        text: text,
        createdAt: DateTime.now(),
        isRead: false,
      );

      await supabase.from('messages').insert({
        'id': message.id,
        'sender_id': message.senderId,
        'receiver_id': message.receiverId,
        'text': message.text,
        'created_at': message.createdAt.toIso8601String(),
        'is_read': message.isRead,
      });
      
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: ${e.toString()}')),
      );
    }
  }

  Future<void> sendPost({
    required String receiverId, 
    required int postId
  }) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      // Get post details to include in message text
      final postResponse = await supabase
          .from('posts')
          .select('claim')
          .eq('id', postId)
          .single();

      final claim = postResponse['claim'] ?? 'Check out this post';
      
      final message = MessageModel(
        id: const Uuid().v4(),
        senderId: currentUserId,
        receiverId: receiverId,
        text: 'Shared post: $claim',
        postId: postId, // Set the postId for post sharing
        createdAt: DateTime.now(),
        isRead: false,
      );

      await supabase.from('messages').insert({
        'id': message.id,
        'sender_id': message.senderId,
        'receiver_id': message.receiverId,
        'text': message.text,
        'post_id': message.postId, // Include post_id
        'created_at': message.createdAt.toIso8601String(),
        'is_read': message.isRead,
      });
      
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    } catch (e) {
      print("Error sending post: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share post: ${e.toString()}')),
      );
    }
  }

  Future<Map<String, dynamic>?> fetchPost(int postId) async {
    try {
      final response = await supabase
          .from('posts')
          .select()
          .eq('id', postId)
          .single();
      return response as Map<String, dynamic>?;
    } catch (e) {
      print("Error fetching post: $e");
      return null;
    }
  }
void _navigateToPost(BuildContext context, int postId) async {
  try {
    final post = await fetchPost(postId);
    if (post != null && context.mounted) {
      final userId = post['user_id'] as String?;
      if (userId != null) {
        // Navigate to AccountPage with the specific post
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Accountpage(
              searchUser: UserModel.fromProfile(post), // Create UserModel from post
              isOwner: userId == supabase.auth.currentUser?.id,
              initialPostId: postId, // Pass the postId to highlight/show the specific post
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post author not found')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post not found')),
      );
    }
  } catch (e) {
    print('Error navigating to post: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}
}

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onPostTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onPostTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: message.isPostShare ? onPostTap : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.isPostShare)
                _buildPostShareMessage(context)
              else
                _buildTextMessage(context),
              
              const SizedBox(height: 4),
              Text(
                DateFormat('h:mm a').format(message.createdAt),
                style: TextStyle(
                  color: (isMe 
                      ? Theme.of(context).colorScheme.onPrimary 
                      : Theme.of(context).colorScheme.onSurface)
                      .withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextMessage(BuildContext context) {
    return Text(
      message.text ?? '',
      style: TextStyle(
        color: isMe 
            ? Theme.of(context).colorScheme.onPrimary 
            : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildPostShareMessage(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.share, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message.text ?? 'Shared post',
            style: TextStyle(
              color: isMe 
                  ? Theme.of(context).colorScheme.onPrimary 
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}