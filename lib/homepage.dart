import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newsgram/conversations_list_screen.dart';
import 'package:newsgram/displayPosts.dart';
import 'package:newsgram/explorePage.dart';
import 'package:newsgram/messageSection.dart';
import 'package:newsgram/stories.dart';
import 'package:newsgram/userModel.dart';
import 'package:newsgram/accountPage.dart';
import 'package:newsgram/postPage.dart';
import 'package:newsgram/searchPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Homepage extends StatefulWidget {
  final User? viewUser;
  
  const Homepage({
    super.key, 
    required this.viewUser,
  });

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _selectedIndex = 0;
  final _supabase = Supabase.instance.client;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = _buildPages();
  }

  List<Widget> _buildPages() {
    final currentUser = _supabase.auth.currentUser;
    final isOwner = (widget.viewUser?.id ?? currentUser?.id) == currentUser?.id;
   

    return [
      Column(
        children: [
          const Stories(),
          Expanded(child: DisplayPosts())
        ],
      ),
      const SearchPage(),
      const Postpage(),
      const ExplorePage(),
      FutureBuilder<UserModel>(
        future: _loadUserProfile(widget.viewUser ?? currentUser),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return Accountpage(
            searchUser: snapshot.data ?? UserModel(id: currentUser?.id ?? ''),
            isOwner: isOwner,
          );
        },
      ),
    ];
  }

  Future<UserModel> _loadUserProfile(User? user) async {
    if (user == null) return UserModel(id: '');

    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        return UserModel.fromProfile(response);
      }
      return UserModel.fromAuthUser(user);
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return UserModel.fromAuthUser(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
      FocusManager.instance.primaryFocus?.unfocus();
    },
    behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: _selectedIndex == 0 
            ? AppBar(
              backgroundColor: Colors.black,
                title: Center(
                  child: Text(
                    'Newsgram',
                    style: GoogleFonts.dancingScript(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.apps_rounded, size: 30),
                  onPressed: _handleCameraPress,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.message_outlined, size: 30),
                    onPressed: _handleSendPress,
                  ),
                ],
              )
            : null,
        body: Container(
          color: Colors.black,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //Text("Datatatt"),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavIcon(0, Icons.home_outlined, Icons.home),
              _buildNavIcon(1, Icons.search_outlined, Icons.search),
              _buildNavIcon(2, Icons.add_circle_outlined, Icons.add_circle),
              _buildNavIcon(3, Icons.monitor_heart_outlined, Icons.monitor_heart),
              _buildNavIcon(4, Icons.account_box_outlined, Icons.account_box),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(int index, IconData outlineIcon, IconData filledIcon) {
    return IconButton(
      onPressed: () => setState(() => _selectedIndex = index),
      icon: Icon(
        _selectedIndex == index ? filledIcon : outlineIcon,
        size: 40,
      ),
    );
  }

  Future<void> _handleCameraPress() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to access camera')),
      );
      return;
    }
    // Implement camera functionality
  }

  Future<void> _handleSendPress() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send messages')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConversationsListScreen(),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}