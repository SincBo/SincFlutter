import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../../providers/providers.dart';
import '../../../domain/entities/creator.dart';
import '../../widgets/search_bar.dart';
import '../creator_wall_page.dart';
import '../profile/profile_page.dart';

class ComunidadPage extends ConsumerStatefulWidget {
  const ComunidadPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ComunidadPage> createState() => _ComunidadPageState();
}

class _ComunidadPageState extends ConsumerState<ComunidadPage> {
  String _searchQuery = '';

  // Pagination state
  final List<CreatorEntity> _creators = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false; // initial load or refresh
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 20;
  String? _error;

  void _onSearchChanged(String value) {
    // when DebouncedSearchBar calls this, perform a fresh search
    _searchQuery = value;
    _refreshSearch();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // initial load
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSearch());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchNextPage();
    }
  }

  Future<void> _refreshSearch() async {
    _page = 0;
    _hasMore = true;
    _error = null;
    setState(() {
      _isLoading = true;
      _creators.clear();
    });
    await _fetchPage();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchNextPage() async {
    if (!_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    await _fetchPage();
    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<void> _fetchPage() async {
    try {
      final repo = ref.read(creatorRepositoryProvider);
      final offset = _page * _pageSize;
      final results = await repo.buscarCreadores(_searchQuery, limit: _pageSize, offset: offset);
      debugPrint('ComunidadPage._fetchPage -> fetched ${results.length} items for query "$_searchQuery" offset $offset');
      if (results.isNotEmpty) {
        try {
          final sample = results.take(3).map((r) => r.toMap()).toList();
          debugPrint('ComunidadPage._fetchPage sample items: ${const JsonEncoder.withIndent('  ').convert(sample)}');
        } catch (_) {
          debugPrint('ComunidadPage._fetchPage -> unable to serialize sample items');
        }
      }
      if (results.isEmpty) {
        // Try a direct datasource RPC fallback (in case RLS or table selection returns empty)
        try {
          final ds = ref.read(supabaseDataSourceProvider);
          final rpcModels = await ds.obtenerCreadores();
          final rpcEntities = rpcModels.cast<CreatorEntity>();
          if (rpcEntities.isNotEmpty) {
            debugPrint('ComunidadPage._fetchPage -> populated from RPC fallback with ${rpcEntities.length} items');
            setState(() {
              _creators.addAll(rpcEntities.take(_pageSize));
              if (rpcEntities.length < _pageSize) {
                _hasMore = false;
              } else {
                _page = 1; // we've loaded first page from RPC
              }
              _error = null;
            });
            return;
          }
        } catch (e) {
          debugPrint('ComunidadPage._fetchPage -> RPC fallback error: $e');
        }
        setState(() {
          _hasMore = false;
          _error = null;
        });
        return;
      }

      setState(() {
        _creators.addAll(results);
        if (results.length < _pageSize) {
          _hasMore = false;
        } else {
          _page += 1;
        }
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Header with title and profile avatar + label
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Comunidad', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'logout') {
                      // Sign out via the auth notifier
                      ref.read(authNotifierProvider.notifier).signOut();
                    } else if (value == 'perfil') {
                      // Navigate to ProfilePage
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'perfil', child: Text('Perfil')),
                    const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
                  ],
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 6),
                      const Text('Perfil', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Section 2: Reusable SearchBar widget
            DebouncedSearchBar(
              hintText: 'Buscar en la comunidad',
              initialText: _searchQuery,
              debounceDuration: const Duration(milliseconds: 300),
              onChanged: _onSearchChanged,
            ),

            const SizedBox(height: 16),

            // Section 3: Paginated list of creators fetched server-side
            Expanded(
              child: Builder(builder: (context) {
                if (_isLoading && _creators.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error != null && _creators.isEmpty) {
                  return Center(child: Text('Error cargando creadores: $_error'));
                }
                if (_creators.isEmpty) {
                  return const Center(child: Text('No hay creadores que coincidan con la búsqueda'));
                }

                return RefreshIndicator(
                  onRefresh: _refreshSearch,
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: _creators.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index >= _creators.length) {
                        // loading more indicator
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final c = _creators[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(c.nombreUsuario),
                        subtitle: Text(c.categoria ?? ''),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => CreatorWallPage(creator: c),
                          ));
                        },
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
