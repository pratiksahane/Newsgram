// lib/screens/about_screen.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'NewsGram',
    packageName: 'Com.example.newsgram',
    version: '1.0.0',
    buildNumber: '1',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About NewsGram'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_outlined, size: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue,
              child: const Icon(
                Icons.article_outlined,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'NewsGram',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version ${_packageInfo.version} (${_packageInfo.buildNumber})',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your social news platform',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            
            const SizedBox(height: 32),
            _buildInfoCard(),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Connect With Us'),
            _buildSocialButton('Website', Icons.language, () => _launchUrl('https://newsgram.app')),
            _buildSocialButton('Twitter', Icons.chat, () => _launchUrl('https://twitter.com/newsgram')),
            _buildSocialButton('GitHub', Icons.code, () => _launchUrl('https://github.com/newsgram')),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Open Source Libraries'),
            _buildLibraryItem('Flutter', 'Google'),
            _buildLibraryItem('Supabase', 'Supabase Inc.'),
            _buildLibraryItem('Cached Network Image', 'Baseflow'),
            
            const SizedBox(height: 24),
            Text(
              '© 2024 NewsGram. All rights reserved.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'NewsGram brings people together through news and conversations. '
              'Share, discuss, and connect with others around the topics that matter to you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Users', '10K+'),
                _buildStatItem('Messages', '1M+'),
                _buildStatItem('Active', '24/7'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildSocialButton(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
      trailing: const Icon(Icons.open_in_new, size: 16),
    );
  }

  Widget _buildLibraryItem(String name, String author) {
    return ListTile(
      title: Text(name),
      subtitle: Text(author),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        // Would show library details
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}