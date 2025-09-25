import 'package:flutter/material.dart';
import 'package:newsgram/SecurityScreen.dart';
import 'package:newsgram/aboutScreen.dart';
import 'package:newsgram/helpScreen.dart';
import 'package:newsgram/privacyPolicyScreen.dart';
import 'package:newsgram/savedPage.dart';
import 'package:newsgram/searchPage.dart';
import 'package:newsgram/signuppage.dart';
import 'package:newsgram/termsOfServiceScreen.dart';
import 'package:newsgram/yourActivityScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class Settingpage extends StatefulWidget {
  const Settingpage({super.key});

  @override
  State<Settingpage> createState() => _SettingpageState();
}

class _SettingpageState extends State<Settingpage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _allSettings = [
    {'icon': Icons.archive_outlined, 'title': "Archive", 'section': "General"},
    {'icon': Icons.local_activity_outlined, 'title': "Your Activity", 'section': "General",'screen':YourActivityScreen()},
    {'icon': Icons.qr_code_scanner_outlined, 'title': "Nametag", 'section': "General"},
    {'icon': Icons.bookmark_border_outlined, 'title': "Saved", 'section': "General",'screen':SavedPage()},
    {'icon': Icons.favorite_border_outlined, 'title': "Close Friends", 'section': "General"},
    {'icon': Icons.person_add_outlined, 'title': "Discover People", 'section': "General",'screen':SearchPage()},
    {'icon': Icons.notifications_outlined, 'title': "Notifications", 'section': "Preferences"},
    {'icon': Icons.privacy_tip_outlined, 'title': "Privacy", 'section': "Preferences",'screen': PrivacyPolicyScreen()},
    {'icon': Icons.security_outlined, 'title': "Security", 'section': "Preferences",'screen': SecurityScreen()},
    {'icon': Icons.help_outline_outlined, 'title': "Help", 'section': "About", 'screen': HelpScreen()},
    {'icon': Icons.info_outline, 'title': "About", 'section': "About", 'screen': AboutScreen()},
    {'icon': Icons.privacy_tip_outlined, 'title': "Privacy Policy", 'section': "About", 'screen': PrivacyPolicyScreen()},
    {'icon': Icons.description_outlined, 'title': "Terms of Service", 'section': "About", 'screen':TermsOfServiceScreen()},
    {'icon': Icons.logout_outlined, 'title': "Logout", 'section': "Login", 'action': 'logout'},
  ];

  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _filteredSettings = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredSettings = _allSettings;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredSettings = _allSettings;
      } else {
        _filteredSettings = _allSettings.where((setting) {
          return setting['title'].toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignUpPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  void _handleItemTap(Map<String, dynamic> item) {
    if (item['action'] == 'logout') {
      _signOut();
    } else if (item['screen'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => item['screen']),
      );
    }
    // Add other actions here if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings and Activity", style: TextStyle(fontSize: 18)),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_outlined, size: 20),
        ),
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
                prefixIcon: const Icon(Icons.search_outlined, size: 20),
                hintText: "Search settings",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          
          // Settings List
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildDefaultSettingsList()
                : _buildSearchResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultSettingsList() {
    final sections = _getSections();
    
    return ListView.builder(
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final items = _allSettings.where((s) => s['section'] == section).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(section, style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              )),
            ),
            ...items.map((item) => _buildSettingItem(item)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSearchResultsList() {
    return ListView.builder(
      itemCount: _filteredSettings.length,
      itemBuilder: (context, index) {
        final item = _filteredSettings[index];
        return _buildSettingItem(item);
      },
    );
  }

  Widget _buildSettingItem(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _handleItemTap(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: Row(
          children: [
            Icon(item['icon'], size: 24),
            const SizedBox(width: 16),
            Expanded(child: Text(item['title'], style: const TextStyle(fontSize: 16))),
            if (item['screen'] != null || item['action'] != null)
              const Icon(Icons.chevron_right_outlined, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  List<String> _getSections() {
    return _allSettings
        .map((item) => item['section'] as String)
        .toSet()
        .toList();
  }
}