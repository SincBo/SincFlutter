import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sincboflutter/core/providers/chat_repository_provider.dart';
import 'package:sincboflutter/core/providers/payment_repository_provider.dart';

import '../../../../core/providers/auth_notifier_provider.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/widgets/search_bar.dart';
import '../../../../domain/entities/creator.dart';
import '../../../chat/presentation/pages/chat.page.dart';
import '../../../creator_profile/presentation/pages/creator_profile.page.dart';
import '../../../profile/presentation/pages/profile.page.dart';
import '../controller/community.provider.dart';
import '../controller/community.state.dart';

class ComunidadPage extends ConsumerStatefulWidget {
  const ComunidadPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ComunidadPage> createState() => _ComunidadPageState();
}

class _ComunidadPageState extends ConsumerState<ComunidadPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communityControllerProvider.notifier).refresh('');
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final s = ref.read(communityControllerProvider);
    if (s.loading || s.loadingMore || !s.hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(communityControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    ref.read(communityControllerProvider.notifier).refresh(value);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(communityControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Comunidad',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'logout') {
                      ref.read(authNotifierProvider.notifier).signOut();
                    } else if (value == 'perfil') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'perfil', child: Text('Perfil')),
                    const PopupMenuItem(
                        value: 'logout', child: Text('Cerrar sesión')),
                  ],
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        child: Icon(Icons.person,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 6),
                      const Text('Perfil', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            DebouncedSearchBar(
              hintText: 'Buscar en la comunidad',
              initialText: s.query,
              debounceDuration: const Duration(milliseconds: 300),
              onChanged: _onSearchChanged,
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _CreatorList(
                state: s,
                scrollController: _scrollController,
                onRefresh: () =>
                    ref.read(communityControllerProvider.notifier).refresh(s.query),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lista extraída en widget separado para claridad
// ---------------------------------------------------------------------------
class _CreatorList extends ConsumerWidget {
  final CommunityState state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  const _CreatorList({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.creators.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.creators.isEmpty) {
      return Center(child: Text('Error: ${state.error}'));
    }
    if (state.creators.isEmpty) {
      return const Center(
          child: Text('No hay creadores que coincidan con la búsqueda'));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        itemCount: state.creators.length + (state.loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= state.creators.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final c = state.creators[index];
          final initials = c.nombreUsuario
              .trim()
              .split(' ')
              .map((s) => s.isNotEmpty ? s[0] : '')
              .take(2)
              .join()
              .toUpperCase();

          return ListTile(
            leading:
                CircleAvatar(child: Text(initials.isNotEmpty ? initials : '?')),
            title: Text(c.nombreUsuario),
            subtitle: Text(c.categoria ?? ''),
            onTap: () => _onCreatorTap(context, ref, c),
          );
        },
      ),
    );
  }

  Future<void> _onCreatorTap(
      BuildContext context, WidgetRef ref, CreatorEntity creator) async {
    final tienePlanes =
        creator.planes != null && creator.planes!.isNotEmpty;

    if (!tienePlanes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Este creador aún está construyendo su perfil. ¡Vuelve pronto!'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Mostrar loading mientras verificamos suscripción
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool isSubscribed = false;
    try {
      isSubscribed =
          await ref.read(isSubscribedProvider(creator.idUsuario).future);
    } catch (_) {}

    if (!context.mounted) return;

    final comunidadPlanId =
        creator.planes?[0]['id_plan'] as String?;

    if (isSubscribed && comunidadPlanId != null) {
      bool esComunidad = false;
      try {
        esComunidad = await ref
            .read(paymentRepositoryProvider)
            .isSubscribedToPlan(comunidadPlanId);
      } catch (_) {}

      if (!context.mounted) return;

      if (esComunidad) {
        String? chatId;
        try {
          chatId = await ref
              .read(chatRepositoryProvider)
              .createChatAndParticipants(
                  creator.idUsuario, comunidadPlanId, false);
        } catch (_) {}

        if (context.mounted) Navigator.of(context).pop();
        if (!context.mounted) return;

        if (chatId != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatPage(creator: creator, chatId: chatId),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el chat')),
          );
        }
        return;
      }
    }

    // No suscrito o suscrito a otro plan → mostrar perfil
    if (context.mounted) Navigator.of(context).pop();
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreatorWallPage(creator: creator),
    ));
  }
}
