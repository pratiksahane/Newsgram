// lib/screens/privacy_policy_screen.dart
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
            const Text(
              'Last Updated: January 2024',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildSection('1. Information We Collect', [
              '• Account Information: When you create an account, we collect your username, email address, and profile information.',
              '• Content: Messages you send, posts you create, and other content you share on NewsGram.',
              '• Usage Data: How you interact with our services, including time spent, features used, and device information.',
              '• Contacts: If you choose to sync your contacts to find friends on NewsGram.',
            ]),

            _buildSection('2. How We Use Your Information', [
              '• Provide and improve our services',
              '• Personalize your experience',
              '• Communicate with you about updates and security alerts',
              '• Ensure safety and security of our platform',
              '• Analyze usage trends and optimize performance',
            ]),

            _buildSection('3. Information Sharing', [
              '• We do not sell your personal data to third parties.',
              '• We may share information with service providers who help us operate NewsGram.',
              '• We may disclose information if required by law or to protect our rights.',
              '• In case of business transfers (merger, acquisition, etc.), your information may be transferred.',
            ]),

            _buildSection('4. Data Security', [
              '• We implement industry-standard security measures to protect your data.',
              '• Your messages are encrypted in transit and at rest.',
              '• We regularly monitor our systems for potential vulnerabilities.',
            ]),

            _buildSection('5. Your Rights', [
              '• Access and update your personal information through your profile settings.',
              '• Delete your account and associated data.',
              '• Opt-out of promotional communications.',
              '• Request a copy of your data in a portable format.',
            ]),

            _buildSection('6. Data Retention', [
              '• We retain your information for as long as your account is active.',
              '• After account deletion, we remove your data within 30 days.',
              '• Some information may be retained for legal purposes or to prevent fraud.',
            ]),

            _buildSection('7. Children\'s Privacy', [
              '• NewsGram is not intended for children under 13.',
              '• We do not knowingly collect information from children under 13.',
              '• If we learn we have collected information from a child under 13, we will delete it promptly.',
            ]),

            _buildSection('8. Changes to This Policy', [
              '• We may update this privacy policy from time to time.',
              '• We will notify you of significant changes through the app or email.',
              '• Continued use of NewsGram after changes constitutes acceptance of the new policy.',
            ]),

            _buildSection('9. Contact Us', [
              'If you have questions about this privacy policy, contact us at:',
              'privacy@newsgram.app',
              'Or write to us at:',
              'NewsGram Privacy Team',
              '123 App Street, Tech City, TC 12345',
            ]),

            const SizedBox(height: 30),
            const Text(
              'By using NewsGram, you agree to the collection and use of information in accordance with this policy.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ...points.map((point) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            point,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
        )).toList(),
      ],
    );
  }
}