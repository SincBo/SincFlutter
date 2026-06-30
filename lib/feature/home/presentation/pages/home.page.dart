import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sincboflutter/feature/chat/presentation/pages/chat.page.dart';
import 'package:sincboflutter/feature/fellow/presentation/pages/fellow_creator.page.dart';
import 'package:sincboflutter/feature/fellow/presentation/pages/fellow.page.dart';
import 'package:sincboflutter/feature/earnings/presentation/pages/earnings.page.dart';
import 'package:sincboflutter/feature/subscription/presentation/pages/subscription.page.dart';

import '../../../../core/providers/auth_notifier_provider.dart';
import '../../../../core/providers/providers.dart';
import '../../../community/presentation/pages/comunidad_page.dart';
import '../controllers/creator_community_chat_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  void _onTap(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final isCreator = user.esCreador;

    final List<Widget> pages;
    final List<BottomNavigationBarItem> items;

    if (isCreator) {
      pages = const [
        _CreatorComunidadView(),
        FellowCreatorPage(),
        SuscritosPage(),
        GananciasPage(),
      ];
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Comunidad'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Fellows'),
        BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline), label: 'Solicitudes'),
        BottomNavigationBarItem(
            icon: Icon(Icons.attach_money), label: 'Ganancias'),
      ];
    } else {
      pages = const [
        ComunidadPage(),
        FellowPage(),
        SuscritosPage(),
      ];
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Comunidad'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Fellows'),
        BottomNavigationBarItem(
            icon: Icon(Icons.post_add), label: 'Suscritos'),
      ];
    }

    // Clamp index si el rol cambió y la tab ya no existe
    final safeIndex = _currentIndex.clamp(0, pages.length - 1);

    return Scaffold(
      body: pages[safeIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        items: items,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vista de comunidad del creador: delega toda la lógica al provider
// ---------------------------------------------------------------------------
class _CreatorComunidadView extends ConsumerWidget {
  const _CreatorComunidadView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(creatorCommunityChatProvider);

    return chatAsync.when(
      data: (result) {
        if (result == null) {
          return const Center(child: Text('No se pudo cargar el chat de comunidad'));
        }
        return ChatPage(creator: result.creator, chatId: result.chatId);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(e.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(creatorCommunityChatProvider),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
