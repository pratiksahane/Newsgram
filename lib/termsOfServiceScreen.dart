// lib/screens/terms_of_service_screen.dart
import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
              'Terms of Service',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome to NewsGram! By using our services, you agree to these terms. Please read them carefully.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),

            _buildSection('1. Acceptance of Terms', [
              'By creating an account or using NewsGram, you accept these Terms of Service and our Privacy Policy.',
              'You must be at least 13 years old to use NewsGram.',
              'If you are using NewsGram on behalf of an organization, you represent that you have authority to bind that organization.',
            ]),

            _buildSection('2. Account Responsibilities', [
              'You are responsible for maintaining the confidentiality of your account credentials.',
              'You are responsible for all activities that occur under your account.',
              'You must provide accurate and complete information when creating your account.',
              'You must not create multiple accounts for abusive purposes.',
            ]),

            _buildSection('3. User Conduct', [
              'You agree not to:',
              '• Post illegal, harmful, or offensive content',
              '• Harass, bully, or threaten other users',
              '• Impersonate others or provide false information',
              '• Share private information of others without consent',
              '• Use automated systems to access our services',
              '• Violate any applicable laws or regulations',
            ]),

            _buildSection('4. Content Ownership', [
              'You retain ownership of the content you create and share on NewsGram.',
              'By posting content, you grant NewsGram a worldwide license to use, display, and distribute that content.',
              'This license continues even if you stop using our services.',
              'You are responsible for ensuring you have the rights to share the content you post.',
            ]),

            _buildSection('5. Intellectual Property', [
              'NewsGram and its logos, designs, and source code are protected by intellectual property laws.',
              'You may not copy, modify, or distribute our intellectual property without permission.',
              'All rights not expressly granted are reserved.',
            ]),

            _buildSection('6. Termination', [
              'We may suspend or terminate your account if you violate these terms.',
              'You may delete your account at any time through the app settings.',
              'Upon termination, your right to use NewsGram immediately ceases.',
            ]),

            _buildSection('7. Service Modifications', [
              'We may modify, suspend, or discontinue any aspect of NewsGram at any time.',
              'We are not liable for any modification, suspension, or discontinuance of the service.',
              'We may update these terms from time to time, and continued use constitutes acceptance.',
            ]),

            _buildSection('8. Disclaimer of Warranties', [
              'NewsGram is provided "as is" without warranties of any kind.',
              'We do not guarantee that the service will be uninterrupted or error-free.',
              'We are not responsible for the accuracy, completeness, or usefulness of any content.',
            ]),

            _buildSection('9. Limitation of Liability', [
              'To the fullest extent permitted by law, NewsGram shall not be liable for:',
              '• Any indirect, incidental, or consequential damages',
              '• Loss of data, profits, or business opportunities',
              '• Damages resulting from your use or inability to use the service',
            ]),

            _buildSection('10. Governing Law', [
              'These terms are governed by the laws of the State of California, USA.',
              'Any disputes shall be resolved in the courts located in San Francisco, California.',
            ]),

            _buildSection('11. Contact Information', [
              'For questions about these terms, contact us at:',
              'legal@newsgram.app',
              'Or write to us at:',
              'NewsGram Legal Department',
              '123 App Street, Tech City, TC 12345',
            ]),

            _buildSection('12. Entire Agreement', [
              'These terms constitute the entire agreement between you and NewsGram.',
              'If any provision is found invalid, the remaining provisions remain in effect.',
              'Our failure to enforce any right does not waive that right.',
            ]),

            const SizedBox(height: 30),
            const Text(
              'By using NewsGram, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
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