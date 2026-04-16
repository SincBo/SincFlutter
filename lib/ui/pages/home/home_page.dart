import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sincboflutter/ui/pages/chat_page.dart';
import 'package:sincboflutter/ui/pages/home/fellow_creator_page.dart';
import 'package:sincboflutter/ui/pages/home/fellow_page.dart';
import 'package:sincboflutter/ui/pages/home/ganancias_page.dart';
import 'package:sincboflutter/ui/pages/home/suscritos_page.dart';

import '../../../domain/entities/creator.dart';
import '../../../providers/providers.dart';
import '../login_page.dart';
import 'comunidad_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  int _fellowsCount = 0;
  int _solicitudesCount = 0;

  void _onTap(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _loadCounts() async {
    try {
      final ds = ref.read(supabaseDataSourceProvider);
      // Fellows count: personas que compraron el plan Fellow del creador actual
      final fellows = await ds.obtenerUsuarioPorTipo('Fellow', limit: 200, offset: 0);
      // Solicitudes count placeholder
      final solicitudes = <dynamic>[];
      setState(() {
        _fellowsCount = fellows.length;
        _solicitudesCount = solicitudes.length;
      });
    } catch (_) {
      // keep current counts
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const SizedBox.shrink();
        }
        final creatorsAsync = ref.watch(creatorsProvider);

        return creatorsAsync.when(
          data: (creators) {
            final isCreator = user.esCreador || false;

            // Defer counts load until after first build to avoid build-time async
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadCounts();
            });

            // Build pages and items depending on isCreator
            List<Widget> pages;
            List<BottomNavigationBarItem> items;

            if (isCreator) {
              // Order: Comunidad, Fellows(N), Solicitudes(N), Ganancias
              pages = <Widget>[
                _ComunidadChatLauncher(userId: user.id),
                const FellowCreatorPage(),
                const SuscritosPage(), // placeholder for Solicitudes page
                const GananciasPage(), // placeholder for Ganancias page
              ];

              items = <BottomNavigationBarItem>[
                const BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Comunidad'),
                BottomNavigationBarItem(icon: const Icon(Icons.people), label: 'Fellows (${_fellowsCount})'),
                BottomNavigationBarItem(icon: const Icon(Icons.mail_outline), label: 'Solicitudes (${_solicitudesCount})'),
                const BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Ganancias'),
              ];
            } else {
              // Non-creator: Comunidad, Fellows, Suscritos
              pages = const <Widget>[
                ComunidadPage(),
                FellowPage(),
                SuscritosPage(),
              ];

              items = const <BottomNavigationBarItem>[
                BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Comunidad'),
                BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Fellows'),
                BottomNavigationBarItem(icon: Icon(Icons.post_add), label: 'Suscritos'),
              ];
            }

            // Clamp current index if menu size changed
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

class _ComunidadChatLauncher extends ConsumerStatefulWidget {
  final String userId;
  const _ComunidadChatLauncher({Key? key, required this.userId}) : super(key: key);

  @override
  ConsumerState<_ComunidadChatLauncher> createState() => _ComunidadChatLauncherState();
}

class _ComunidadChatLauncherState extends ConsumerState<_ComunidadChatLauncher> {
  String? _chatId;
  CreatorEntity? _creator;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openChat());
  }

  Future<void> _openChat() async {
    final authUser = ref.read(authNotifierProvider).maybeWhen(
      data: (u) => u,
      orElse: () => null,
    );

    // 🔥 SI NO HAY USUARIO → NO HACER NADA
    if (authUser == null) return;
    setState(() => _error = null);
    try {
      // Fetch creators and try to find current user as creator entity
      final repo = ref.read(creatorRepositoryProvider);
      final creators = await repo.obtenerCreadores();

      CreatorEntity? me;
      if (creators.isNotEmpty) {
        me = creators.firstWhere((c) => c.idUsuario == widget.userId, orElse: () => creators.first);
      }

      if (me == null) {
        // Fallback: build a minimal CreatorEntity from auth profile
        final authUser = ref.read(authNotifierProvider).maybeWhen(data: (u) => u, orElse: () => null);
        if (authUser == null) {
          setState(() => _error = 'No hay usuario autenticado');
          return;
        }
        me = CreatorEntity(
          idUsuario: authUser.id,
          nombreUsuario: authUser.email?.split('@').first ?? 'Creador',
          email: authUser.email ?? '',
          bio: 'Perfil de creador',
          precioSuscripcion: 0.0,
          precioSuscripcionFellow: 0.0,
          categoria: 'Comunidad',
          publicaciones: const [],
          planes: const [],
        );
      }

      _creator = me;

      String? chatId;

      // Si el creador tiene planes, usar el flujo normal con el primer plan
      if (me.planes != null && me.planes!.isNotEmpty) {
        final planId = me.planes!.first['id_plan'] as String;
        chatId = await repo.crearChatYParticipantes(me.idUsuario, planId, false);
      } else {
        // Sin planes: buscar o crear el chat de comunidad directamente
        chatId = await repo.getOrCreateComunidadChatCreador(me.idUsuario);
      }

      if (!mounted) return;
      setState(() => _chatId = chatId ?? '');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _openChat(), child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_chatId == null || _creator == null) return const Center(child: CircularProgressIndicator());
    return ChatPage(creator: _creator!, chatId: _chatId!);
  }
}
