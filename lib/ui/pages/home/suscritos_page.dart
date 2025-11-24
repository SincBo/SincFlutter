import 'package:flutter/material.dart';
import '../../widgets/search_bar.dart';

class SuscritosPage extends StatefulWidget {
  const SuscritosPage({Key? key}) : super(key: key);

  @override
  State<SuscritosPage> createState() => _SuscritosPageState();
}

class _SuscritosPageState extends State<SuscritosPage> {
  final List<Map<String, String>> _all = List.generate(25, (i) => {
    'title': 'Creador ${i + 1}',
    'subtitle': 'Descripción breve o última publicación del creador ${i + 1}',
  });

  List<Map<String, String>> _filtered = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filtered = List.from(_all);
  }

  void _onSearchChanged(String val) {
    setState(() {
      _query = val.trim();
      if (_query.isEmpty) {
        _filtered = List.from(_all);
      } else {
        final lower = _query.toLowerCase();
        _filtered = _all.where((m) {
          final t = (m['title'] ?? '').toLowerCase();
          final s = (m['subtitle'] ?? '').toLowerCase();
          return t.contains(lower) || s.contains(lower);
        }).toList();
      }
    });
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _filtered = List.from(_all);
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
            // Section 1: Header (title left, avatar + perfil on right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Suscritos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
              hintText: 'Buscar creadores suscritos',
              debounceDuration: const Duration(milliseconds: 300),
              initialText: _query,
              onChanged: _onSearchChanged,
            ),

            const SizedBox(height: 12),

            // Section 3: List with title and subtitle
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No hay suscripciones que coincidan')),
                        ],
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final initials = (item['title'] ?? '').trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join();
                          return ListTile(
                            leading: CircleAvatar(child: Text(initials.toUpperCase())),
                            title: Text(item['title'] ?? ''),
                            subtitle: Text(item['subtitle'] ?? ''),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abrir ${item['title']}')));
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
