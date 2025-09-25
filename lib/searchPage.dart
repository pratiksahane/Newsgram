import 'dart:async';
import 'package:flutter/material.dart';
import 'package:newsgram/userModel.dart';
import 'package:newsgram/accountPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;
  final User? _currentUser = Supabase.instance.client.auth.currentUser;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchTextChanged(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .or('username.ilike.%$query%,name.ilike.%$query%')
          .limit(20);

      if (!mounted) return;
      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: ${e.toString()}')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 48),
              child: TextField(
                autofocus: false,
                controller: _searchController,
                onChanged: _onSearchTextChanged,
                //autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Search users...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: _searchResults.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'Search user profiles...'
                                  : 'No results found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final profile = _searchResults[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: NetworkImage(
                                    profile['avatar_url'] ?? 
                                    'https://www.gravatar.com/avatar/?d=mp',
                                  ),
                                  onBackgroundImageError: (_, __) => 
                                      const Icon(Icons.person),
                                ),
                                title: Text(
                                  profile['username'] ?? 'No username',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: profile['name']?.toString().isNotEmpty ?? false
                                    ? Text(profile['name']!)
                                    : null,
                                onTap: () {
                                  final userModel = UserModel.fromProfile(profile);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Accountpage(
                                        // Pass both the profile data and auth user info
                                        searchUser: userModel,
                                        isOwner: profile['user_id'] == _currentUser?.id,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
          ],
        ),
      ),
    );
  }
}