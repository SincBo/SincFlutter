import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';
import '../../../domain/entities/creator.dart';
import '../../widgets/search_bar.dart';
import '../chat_page.dart' as fullchat;

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  String _searchQuery = '';

  Future<void> _refresh() async {
    try {
      ref.invalidate(chatsSuscritosProvider);
      await ref.read(chatsSuscritosProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsSuscritosProvider);
    final authState = ref.watch(authNotifierProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Header with title on left and avatar+profile label on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chats', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                // Avatar + profile label
                authState.when(
                  data: (user) {
                    final display = user?.username ?? 'Perfil';
                    final avatarUrl = user?.avatarUrl;
                    if (avatarUrl != null && avatarUrl.isNotEmpty) {
                      return Column(
                        children: [
                          CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl)),
                          const SizedBox(height: 6),
                          Text(display, style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }
                    // fallback avatar using initials
                    final initials = (user?.username ?? '').trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join();
                    return Column(
                      children: [
                        CircleAvatar(radius: 24, child: Text(initials.isNotEmpty ? initials.toUpperCase() : '?')),
                        const SizedBox(height: 6),
                        Text(display, style: const TextStyle(fontSize: 12)),
                      ],
                    );
                  },
                  loading: () => const Column(
                    children: [
                      CircleAvatar(radius: 24, child: Icon(Icons.person)),
                      SizedBox(height: 6),
                      Text('Perfil', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  error: (_, __) => const Column(
                    children: [
                      CircleAvatar(radius: 24, child: Icon(Icons.person)),
                      SizedBox(height: 6),
                      Text('Perfil', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Section 2: Search bar on its own row
            DebouncedSearchBar(
              hintText: 'Buscar chats',
              debounceDuration: const Duration(milliseconds: 300),
              initialText: _searchQuery,
              onChanged: (val) => setState(() => _searchQuery = val),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: chatsAsync.when(
                data: (list) {
                  final filtered = _searchQuery.trim().isEmpty
                      ? list
                      : list.where((c) => c.nombreCreador.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

                  if (filtered.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No hay chats que coincidan')),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        final initials = c.nombreCreador.isNotEmpty
                            ? c.nombreCreador.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join()
                            : '?';

                        return ListTile(
                          leading: CircleAvatar(child: Text(initials.toUpperCase())),
                          title: Text(c.nombreCreador),
                          subtitle: Text('Chat id: ${c.idChat}'),
                          onTap: () {
                            final creator = CreatorEntity(
                              idUsuario: c.idCreador,
                              nombreUsuario: c.nombreCreador,
                              email: '',
                              bio: '',
                              precioSuscripcion: 0.0,
                              precioSuscripcionFellow: 0.0,
                              categoria: null,
                              publicaciones: null,
                            );

                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => fullchat.ChatPage(creator: creator, chatId: c.idChat),
                            ));
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error cargando chats: ${e.toString()}')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
