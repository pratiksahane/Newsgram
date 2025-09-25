class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? text;
  final List<String>? attachments;
  final int? postId; // Add this field for post sharing
  final DateTime createdAt;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.text,
    this.attachments,
    this.postId, // Add postId parameter
    required this.createdAt,
    this.isRead = false,
  });

  factory MessageModel.fromSupabase(Map<String, dynamic> data) {
    return MessageModel(
      id: data['id'],
      senderId: data['sender_id'],
      receiverId: data['receiver_id'],
      text: data['text'],
      attachments: data['attachments']?.cast<String>(),
      postId: data['post_id'], // Add postId
      createdAt: DateTime.parse(data['created_at']),
      isRead: data['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'text': text,
      'attachments': attachments,
      'post_id': postId, // Add postId
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  bool get hasMedia => attachments?.isNotEmpty ?? false;
  bool get isPostShare => postId != null; // Helper getter
}