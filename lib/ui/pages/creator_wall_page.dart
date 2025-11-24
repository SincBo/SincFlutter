import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/creator.dart';
import '../../providers/providers.dart';
import 'chat_page.dart';

class CreatorWallPage extends StatefulWidget {
  final CreatorEntity creator;

  const CreatorWallPage({Key? key, required this.creator}) : super(key: key);

  @override
  State<CreatorWallPage> createState() => _CreatorWallPageState();
}

class _CreatorWallPageState extends State<CreatorWallPage> {
  bool? _optimisticSubscribed; // null = not decided yet, otherwise true/false
  static const double expandedHeight = 300;

  void _toggleSubscribe() {
    setState(() {
      _optimisticSubscribed = true; // solo permitimos subscribe, no unsubscribe en este flujo
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Suscrito a ${widget.creator.nombreUsuario}')),
    );
  }

  // Widget _buildPostCard(dynamic p) {
  //   // Asumimos que las publicaciones pueden venir en formatos varios:
  //   // - String -> texto
  //   // - Map con keys: 'text' / 'descripcion' / 'titulo'
  //   // - Map con 'image'|'imageUrl'|'image_url' -> URL de imagen
  //   // - Map con 'video'|'videoUrl'|'video_url' -> URL de video
  //   // - Map con 'media' -> puede ser una lista de items (each map con tipo)
  //
  //   String? text;
  //   String? imageUrl;
  //   String? videoUrl;
  //   List<dynamic>? mediaList;
  //
  //   if (p is String) {
  //     text = p;
  //   } else if (p is Map) {
  //     text = p['text'] ?? p['descripcion'] ?? p['titulo'] ?? p['body'];
  //     imageUrl = p['image'] ?? p['imageUrl'] ?? p['image_url'];
  //     videoUrl = p['video'] ?? p['videoUrl'] ?? p['video_url'];
  //     mediaList = p['media'] as List<dynamic>?;
  //   }
  //
  //   // Helper para renderizar un media item
  //   Widget mediaWidgetFromUrl({String? img, String? vid}) {
  //     if (img != null && img.isNotEmpty) {
  //       return ClipRRect(
  //         borderRadius: BorderRadius.circular(8),
  //         child: Image.network(
  //           img,
  //           height: 200,
  //           width: double.infinity,
  //           fit: BoxFit.cover,
  //           loadingBuilder: (context, child, loadingProgress) {
  //             if (loadingProgress == null) return child;
  //             return Container(
  //               height: 200,
  //               color: Theme.of(context).cardColor,
  //               child: const Center(child: CircularProgressIndicator()),
  //             );
  //           },
  //           errorBuilder: (context, error, stackTrace) {
  //             return Container(
  //               height: 200,
  //               color: Theme.of(context).cardColor,
  //               child: const Center(child: Icon(Icons.broken_image, size: 40)),
  //             );
  //           },
  //         ),
  //       );
  //     }
  //
  //     if (vid != null && vid.isNotEmpty) {
  //       // Placeholder visual para video con overlay de play
  //       return GestureDetector(
  //         onTap: () => _showVideoPlaceholder(vid),
  //         child: Container(
  //           height: 200,
  //           width: double.infinity,
  //           decoration: BoxDecoration(
  //             color: Colors.black12,
  //             borderRadius: BorderRadius.circular(8),
  //           ),
  //           child: Center(
  //             child: Stack(
  //               alignment: Alignment.center,
  //               children: [
  //                 Icon(Icons.play_circle_fill, size: 64, color: Colors.white.withOpacity(0.9)),
  //               ],
  //             ),
  //           ),
  //         ),
  //       );
  //     }
  //
  //     return const SizedBox.shrink();
  //   }
  //
  //   // If there's a media list, render each media inside a Column
  //   List<Widget> mediaWidgets = [];
  //   if (mediaList != null && mediaList.isNotEmpty) {
  //     for (var m in mediaList) {
  //       if (m is String) {
  //         // assume image url
  //         mediaWidgets.add(mediaWidgetFromUrl(img: m));
  //       } else if (m is Map) {
  //         final img = m['image'] ?? m['imageUrl'] ?? m['image_url'];
  //         final vid = m['video'] ?? m['videoUrl'] ?? m['video_url'];
  //         mediaWidgets.add(mediaWidgetFromUrl(img: img, vid: vid));
  //       }
  //       mediaWidgets.add(const SizedBox(height: 8));
  //     }
  //   } else if (imageUrl != null || videoUrl != null) {
  //     mediaWidgets.add(mediaWidgetFromUrl(img: imageUrl, vid: videoUrl));
  //   }
  //
  //   // Construir el card final
  //   return SizedBox(
  //     width: double.infinity,
  //     child: Card(
  //       margin: const EdgeInsets.symmetric(vertical: 8.0),
  //       clipBehavior: Clip.antiAlias,
  //       child: Padding(
  //         padding: const EdgeInsets.all(12.0),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             // Media (si existe)
  //             if (mediaWidgets.isNotEmpty) ...mediaWidgets,
  //
  //             // Texto (si existe)
  //             if (text != null && text.isNotEmpty) ...[
  //               const SizedBox(height: 8),
  //               Text(text),
  //             ],
  //
  //             // Fallback: si no hay nada, mostramos el map/string por inspección
  //             if (mediaWidgets.isEmpty && (text == null || text.isEmpty)) ...[
  //               const SizedBox(height: 8),
  //               Text(p.toString()),
  //             ],
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // void _showVideoPlaceholder(String url) {
  //   showDialog<void>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Reproducir video'),
  //       content: Text('Reproductor placeholder para: $url'),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final creator = widget.creator;

    // Use a Consumer here to obtain a WidgetRef safely and avoid relying on ConsumerState
    return Consumer(builder: (context, localRef, child) {
      // Watch the provider that checks subscription remotely
      final susAsync = localRef.watch(isSubscribedProvider(creator.idUsuario));
      final remoteSubscribed = susAsync.maybeWhen(data: (v) => v, orElse: () => false);
      final effectiveSubscribed = _optimisticSubscribed ?? remoteSubscribed;

      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          centerTitle: true,
          title: Text(
            creator.nombreUsuario,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          // thin colored bar under appbar to mimic design accent
          // bottom: PreferredSize(
          //   preferredSize: const Size.fromHeight(2),
          //   child: Container(height: 2, color: Theme.of(context).colorScheme.primary),
          // ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reuse the same padded content that was inside SliverToBoxAdapter
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // HEADER: centered rounded-square avatar, name and small profile label beneath
                    Center(
                      child: Column(
                        children: [
                          // rounded-square avatar placeholder (matches screenshot style)
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: creator.nombreUsuario.isNotEmpty
                                ? Center(
                                    child: Text(
                                      creator.nombreUsuario[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 48, color: Colors.grey),
                                    ),
                                  )
                                : const Icon(Icons.image, size: 48, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            creator.nombreUsuario,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const Text('Perfil', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // BIO
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Text(
                          creator.bio.isNotEmpty
                              ? creator.bio
                              : 'Hola! Este perfil aún no tiene descripción — aquí aparece la bio del creador.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // PUBLICACIONES (si existen)
                    // if (creator.publicaciones != null && creator.publicaciones!.isNotEmpty) ...[
                    //   const SizedBox(height: 20),
                    //   const Text('Publicaciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    //   const SizedBox(height: 8),
                    //   Column(
                    //     children: creator.publicaciones!.map((p) => _buildPostCard(p)).toList(),
                    //   ),
                    //   const SizedBox(height: 20),
                    // ],
                    //
                    // const SizedBox(height: 12),

                    // SUBSCRIPTION ROWS (mock data)
                    _subscriptionRow(
                      context,
                      title: 'Comunidad SINC',
                      price: '${creator.precioSuscripcion}',
                      description:
                          'Añade el precio para ingresar a tu comunidad, en este nivel, tu comunidad recibirá mensajes, notas de voz, imágenes.',
                    ),
                    const SizedBox(height: 16),
                    _subscriptionRow(
                      context,
                      title: 'Fellow',
                      price: '${creator.precioSuscripcionFellow}',
                      description:
                          'Esta es una sección más cercana a tu comunidad, con espacios limitados. Quienes están en este apartado pagarán un monto mayor.',
                    ),

                    const SizedBox(height: 20),

                    // Footer: available spaces (mock)
                    const Text('10 espacios disponibles', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
        // floatingActionButton: AnimatedSwitcher(
        //   duration: const Duration(milliseconds: 300),
        //   child: effectiveSubscribed
        //       ? FloatingActionButton.extended(
        //           key: const ValueKey('chat'),
        //           onPressed: () async {
        //             final repo = localRef.read(creatorRepositoryProvider);
        //             showDialog<void>(
        //               context: context,
        //               barrierDismissible: false,
        //               builder: (context) => const Center(child: CircularProgressIndicator()),
        //             );
        //             final idChat = await repo.crearChatYParticipantes(creator.idUsuario);
        //
        //             if (!mounted) return;
        //
        //             // Dismiss loading dialog if still shown
        //             if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        //
        //             if (!mounted) return;
        //
        //             if (idChat != null) {
        //               Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(creator: creator, chatId: idChat)));
        //             } else {
        //               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo crear el chat.')));
        //             }
        //           },
        //           icon: const Icon(Icons.chat_bubble_outline),
        //           label: const Text('Chat'),
        //         )
        //       : FloatingActionButton.extended(
        //           key: const ValueKey('subscribe'),
        //           onPressed: _toggleSubscribe,
        //           icon: const Icon(Icons.subscriptions),
        //           label: const Text('Suscribirse'),
        //         ),
        // ),
      );
    });
  }

  Widget _subscriptionRow(BuildContext context,
      {required String title, required String price, required String description}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Columna izquierda: título y descripción
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Columna derecha: precio y botón de acción
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Suscribirse'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
