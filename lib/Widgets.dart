import 'package:flutter/material.dart';
import 'package:newsgram/accountPage.dart';
import 'package:newsgram/homepage.dart';
import 'package:newsgram/userModel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

void showMoreDialog(
  BuildContext context,
  String postId,
  String userId,
  String claim,
  String mediaUrl,
  String rating,
  String source,
  Map<String, dynamic> evidence,
  bool isHomePage,
) {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 24, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        "Post Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 24, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Claim
                        _buildSection(
                          title: "Claim",
                          content: claim,
                          isBold: true,
                        ),

                        const SizedBox(height: 16),

                        // Rating with colored chip
                        Row(
                          children: [
                            const Text(
                              "Rating:",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getRatingColor(rating).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _getRatingColor(rating)),
                                ),
                                child: Text(
                                  rating.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _getRatingColor(rating),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Source
                        if (source.isNotEmpty && source != 'Unknown Source')
                          _buildSection(
                            title: "Source",
                            content: source,
                          ),

                        const SizedBox(height: 20),

                        // Evidence Section
                        const Text(
                          "Evidence Analysis",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (evidence['claims'] != null && evidence['claims'].isNotEmpty)
                          ..._buildEvidenceList(evidence)
                        else
                          const Text(
                            "No evidence data available",
                            style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                          ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[800]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (userId == Supabase.instance.client.auth.currentUser?.id)
                      TextButton(
                        onPressed: () => _deletePost(context, postId, userId,isHomePage),
                        child: const Text(
                          "Delete Post",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildSection({required String title, required String content, bool isBold = false}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        content,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
          color: Colors.white,
        ),
      ),
    ],
  );
}

Future<void> _deletePost(BuildContext context, String post_id, String user_id, bool isHomePage) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You must be logged in to delete posts')),
    );
    return;
  }

  try {
    // First delete all likes associated with this post
    await supabase
        .from('likes')
        .delete()
        .eq('post_id', post_id);

    // Then delete the post
    await supabase
        .from('posts')
        .delete()
        .eq('id', post_id)
        .eq('user_id', userId);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post deleted successfully')),
    );
    if(!isHomePage){
      Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => Accountpage(isOwner: true, searchUser: UserModel(id: supabase.auth.currentUser!.id)), // Replace with your page widget
    ),
  );
    }
    else{
    Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => Homepage(viewUser:Supabase.instance.client.auth.currentUser), // Replace with your page widget
    ),
  ); }// Close the dialog after deletion
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error deleting post: ${e.toString()}')),
    );
  }


  
}

Color _getRatingColor(String rating) {
  final lower = rating.toLowerCase();
  if (lower.contains('true') || lower.contains('accurate')) return Colors.green;
  if (lower.contains('false') || lower.contains('inaccurate')) return Colors.red;
  if (lower.contains('mixed') || lower.contains('partly')) return Colors.amber;
  if (lower.contains('misleading') || lower.contains('unverified')) return Colors.orange;
  if (lower.contains('unknown') || lower.contains('unrated')) return Colors.grey;
  return Colors.blue;
}

List<Widget> _buildEvidenceList(Map<String, dynamic> evidence) {
  List<Widget> widgets = [];

  for (var claim in evidence['claims']) {
    widgets.add(
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Claim Text
            Text(
              claim['text'] ?? 'No claim text',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),

            // Claimant
            if (claim['claimant'] != null) ...[
              const SizedBox(height: 6),
              Text(
                "Claimed by: ${claim['claimant']}",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // Reviews
            if (claim['claimReview'] != null) ...[
              const SizedBox(height: 12),
              ...claim['claimReview'].map<Widget>((review) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Colors.grey),
                  const SizedBox(height: 8),
                  
                  // Review Text
                  Text(
                    review['textualRating'] ?? 'No review text',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),

                  // Source
                  if (review['publisher'] != null && review['publisher']['name'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Source: ${review['publisher']['name']}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  // URL (clickable)
                  if (review['url'] != null && review['url'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _launchUrl(review['url']),
                      child: const Text(
                        "View source →",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              )).toList(),
            ],
          ],
        ),
      ),
    );
  }

  return widgets;
}

Future<void> _launchUrl(String url) async {
  try {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  } catch (e) {
    print('Error launching URL: $e');
  }
}