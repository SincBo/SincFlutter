import 'package:flutter/material.dart';
import '../../widgets/search_bar.dart';

class FellowPage extends StatefulWidget {
  const FellowPage({Key? key}) : super(key: key);

  @override
  State<FellowPage> createState() => _FellowPageState();
}

class _FellowPageState extends State<FellowPage> {
  final List<Map<String, String>> _allItems = List.generate(20, (i) => {
    'title': 'Conversación ${i + 1}',
    'subtitle': 'Último mensaje de ejemplo en la conversación ${i + 1}',
  });

  List<Map<String, String>> _filtered = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filtered = List.from(_allItems);
  }

  void _onSearchChanged(String q) {
    setState(() {
      _query = q.trim();
      if (_query.isEmpty) {
        _filtered = List.from(_allItems);
      } else {
        final lower = _query.toLowerCase();
        _filtered = _allItems.where((m) {
          final t = (m['title'] ?? '').toLowerCase();
          final s = (m['subtitle'] ?? '').toLowerCase();
          return t.contains(lower) || s.contains(lower);
        }).toList();
      }
    });
  }

  Future<void> _refresh() async {
    // simulate a short reload
    await Future.delayed(const Duration(milliseconds: 700));
    setState(() {
      // for mock, just reset filter and keep same data
      _filtered = List.from(_allItems);
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Header (title left, avatar+perfil right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fellow', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                      child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 6),
                    const Text('Perfil', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Section 2: Search bar
            DebouncedSearchBar(
              hintText: 'Buscar conversaciones',
              debounceDuration: const Duration(milliseconds: 300),
              initialText: _query,
              onChanged: _onSearchChanged,
            ),

            const SizedBox(height: 12),

            // Section 3: List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No se encontraron conversaciones')),
                        ],
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          return ListTile(
                            leading: CircleAvatar(child: Text((index + 1).toString())),
                            title: Text(item['title'] ?? ''),
                            subtitle: Text(item['subtitle'] ?? ''),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abrir: ${item['title']}')));
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
