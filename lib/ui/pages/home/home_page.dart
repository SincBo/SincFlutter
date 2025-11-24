import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sincboflutter/ui/pages/home/fellow_page.dart';
import 'package:sincboflutter/ui/pages/home/chat_page.dart';
import 'package:sincboflutter/ui/pages/home/publicacion_page.dart';
import 'package:sincboflutter/ui/pages/home/suscritos_page.dart';

import '../../../providers/providers.dart';
import 'comunidad_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  void _onTap(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return authState.when(
      data: (user) {
        // Determine whether the current user is a creator by checking creatorsProvider
        final creatorsAsync = ref.watch(creatorsProvider);

        return creatorsAsync.when(
          data: (creators) {
            final isCreator = user != null && creators.any((c) => c.idUsuario == user.id);

            // Build pages and items depending on isCreator
            final pages = <Widget>[
              FellowPage(),
              SuscritosPage(),
              if (isCreator) ChatPage(),
              if (isCreator) PublicacionPage(),
              ComunidadPage(),
            ];

            final items = <BottomNavigationBarItem>[
              const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Fellows'),
              const BottomNavigationBarItem(icon: Icon(Icons.post_add), label: 'Suscritos'),
              const BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Comunidad Sinc'),
              if (isCreator)  const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
              if (isCreator)  const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
            ];

            // Clamp current index in case available pages changed
            if (_currentIndex >= pages.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _currentIndex = 0);
              });
            }

            return Scaffold(
              body: pages[_currentIndex],
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onTap,
                type: BottomNavigationBarType.fixed,
                items: items,
              ),
            );
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, st) => Scaffold(body: Center(child: Text('Error: ${e.toString()}'))),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: ${e.toString()}'))),
    );
  }
}
