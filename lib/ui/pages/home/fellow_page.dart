import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/search_bar.dart';
import '../../../providers/providers.dart';
import '../../../data/models/creator_por_tipo_model.dart';
import '../../../domain/entities/creator.dart';
import '../chat_page.dart';

class FellowPage extends ConsumerStatefulWidget {
  const FellowPage({Key? key}) : super(key: key);

  @override
  ConsumerState<FellowPage> createState() => _FellowPageState();
}

class _FellowPageState extends ConsumerState<FellowPage> {
  // Real data from Supabase (tipo fellow)
  final List<CreatorPorTipoModel> _data = [];
  List<CreatorPorTipoModel> _filtered = [];
  String _query = '';
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ds = ref.read(supabaseDataSourceProvider);
      final results = await ds.obtenerCreadoresPorTipo('Fellow', limit: 100, offset: 0);
      setState(() {
        _data
          ..clear()
          ..addAll(results);
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_data);
    } else {
      _filtered = _data.where((c) {
        final nombre = c.nombreCreador.toLowerCase();
        final bio = c.bio.toLowerCase();
        final tipo = c.tipoPlan.toLowerCase();
        return nombre.contains(q) || bio.contains(q) || tipo.contains(q);
      }).toList();
    }
  }

  void _onSearchChanged(String q) {
    setState(() {
      _query = q.trim();
      _applyFilter();
    });
  }

  Future<void> _refresh() async {
    await _load();
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
              hintText: 'Buscar creadores suscritos (fellow)',
              debounceDuration: const Duration(milliseconds: 300),
              initialText: _query,
              onChanged: _onSearchChanged,
            ),

            const SizedBox(height: 12),

            // Status row
            if (_isLoading && _data.isEmpty) const LinearProgressIndicator(),
            if (_error != null && _data.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
              ),
            Text('Tipo: fellow — resultados: ${_filtered.length}'),

            const SizedBox(height: 12),

            // Section 3: List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          Center(child: Text(_isLoading ? 'Cargando…' : 'No se encontraron creadores fellow')),
                        ],
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = _filtered[index];
                          final initials = c.nombreCreador.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase();
                          return ListTile(
                            leading: CircleAvatar(child: Text(initials)),
                            title: Text(c.nombreCreador),
                            subtitle: Text('${c.tipoPlan} · Bs ${c.precioPlan.toStringAsFixed(2)}'),
                            onTap: () async {
                              // Crear u obtener chat id y navegar a ChatPage
                              showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                              String? chatId;
                              try {
                                final repo = ref.read(creatorRepositoryProvider);
                                chatId = await repo.crearChatYParticipantes(c.idCreador, c.idPlan);
                              } catch (e) {
                                chatId = null;
                              }
                              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                              if (!mounted) return;
                              if (chatId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el chat')));
                                return;
                              }

                              // Map CreatorPorTipoModel to CreatorEntity minimally
                              final creator = CreatorEntity(
                                idUsuario: c.idCreador,
                                nombreUsuario: c.nombreCreador,
                                email: '',
                                bio: c.bio,
                                precioSuscripcion: c.precioPlan,
                                precioSuscripcionFellow: c.precioPlan,
                                categoria: c.tipoPlan,
                                publicaciones: const [],
                                planes: const [],
                              );

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(creator: creator, chatId: chatId),
                                ),
                              );
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
