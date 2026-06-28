// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/api.dart';
import '../utils/error_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  bool _recentChatsLoaded = false;
  String _lastSearchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recentChatsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<ChatProvider>(context, listen: false).loadRecentChats();
        }
      });
      _recentChatsLoaded = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentChats() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;
    await context.read<ChatProvider>().loadRecentChats();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _lastSearchQuery = query;
    });

    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;
      final results = await _apiService.searchUsers(token, query.trim());
      setState(() {
        _searchResults = results;
      });
    } catch (err) {
      if (!mounted) return;
      AppErrorHandler.showError(
        context,
        err,
        fallbackMessage: 'Could not search users.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _handleLogout() {
    context.read<AuthProvider>().logout();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isSearchEmpty = _searchController.text.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User greeting banner
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  radius: 24,
                  child: Text(
                    (auth.username ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
                    ),
                    Text(
                      auth.username ?? 'User',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Premium Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by username...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: _performSearch,
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSearchEmpty ? 'Recent Chats' : 'Search Results',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                if (isSearchEmpty)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white60),
                    onPressed: _loadRecentChats,
                    tooltip: 'Refresh chats',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Search results or recent chats display
            Expanded(
              child: isSearchEmpty
                  ? _buildRecentChatsList(theme)
                  : _buildSearchResultsList(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentChatsList(ThemeData theme) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final recentChats = chatProvider.recentChats;

    if (chatProvider.isLoadingRecent) {
      return const Center(child: CircularProgressIndicator());
    }

    if (recentChats.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView.separated(
      itemCount: recentChats.length,
      separatorBuilder: (context, index) => const Divider(
        color: Color(0xFF222222),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final user = recentChats[index];
        final String username = user['username'] ?? 'Unknown';
        final String userId = user['_id'] ?? '';
        final int unreadCount = user['unreadCount'] as int? ?? 0;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              username.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            username,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            unreadCount > 0 ? '$unreadCount unread messages' : 'Tap to continue conversation',
            style: TextStyle(
              color: unreadCount > 0 ? theme.colorScheme.secondary : Colors.white38,
              fontSize: 13,
              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          trailing: unreadCount > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  size: 20,
                ),
          onTap: () async {
            await Navigator.pushNamed(
              context,
              '/chat',
              arguments: {
                'id': userId,
                'username': username,
              },
            );
            // Refresh recent chats when returning
            _loadRecentChats();
          },
        );
      },
    );
  }

  Widget _buildSearchResultsList(ThemeData theme) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(
        color: Color(0xFF222222),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final String username = user['username'] ?? 'Unknown';
        final String userId = user['_id'] ?? '';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
            child: Text(
              username.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            username,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: const Text(
            'Tap to start chatting',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          onTap: () async {
            await Navigator.pushNamed(
              context,
              '/chat',
              arguments: {
                'id': userId,
                'username': username,
              },
            );
            // Refresh recent chats when returning
            _searchController.clear();
            _performSearch('');
            _loadRecentChats();
          },
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No active chats yet.',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Search for a username above to start talking.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.white38.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found for "$_lastSearchQuery"',
              style: const TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }
  }
}
