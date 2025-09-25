import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_outlined, size: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Frequently Asked Questions'),
            _buildFAQItem(
              'How do I start a conversation?',
              'Tap the search icon in the messages screen, search for a user, and tap on their name to start chatting.',
            ),
            _buildFAQItem(
              'How do I update my profile?',
              'Go to your profile screen, tap the edit button, and update your information.',
            ),
            _buildFAQItem(
              'Can I delete messages?',
              'Currently, you can only delete your own messages. Long press on a message to see options.',
            ),
            _buildFAQItem(
              'How do I report a user?',
              'Go to the user\'s profile, tap the three dots menu, and select "Report User".',
            ),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Contact Support'),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email Support'),
              subtitle: const Text('support@newsgram.app'),
              onTap: () => _launchEmail(),
            ),
            ListTile(
              leading: const Icon(Icons.help_center),
              title: const Text('Help Center'),
              subtitle: const Text('Visit our online help center'),
              onTap: () => _launchUrl('https://help.newsgram.app'),
            ),
            
            const SizedBox(height: 24),
            _buildSectionTitle('App Tutorials'),
            _buildTutorialItem('Messaging Basics', Icons.message),
            _buildTutorialItem('Profile Setup', Icons.person),
            _buildTutorialItem('Privacy Settings', Icons.security),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildTutorialItem(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        // Would navigate to tutorial screen
      },
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@newsgram.app',
      queryParameters: {'subject': 'NewsGram Support'},
    );
    
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}