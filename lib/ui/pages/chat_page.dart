import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/creator.dart';
import '../../providers/providers.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends ConsumerStatefulWidget {
  final CreatorEntity creator;
  final String? chatId; // optional chat id created on the server

  const ChatPage({Key? key, required this.creator, this.chatId}) : super(key: key);

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool fromMe; // true = outgoing
  final List<String> images; // new: multimedia images URLs

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.fromMe,
    this.images = const [],
  });

  bool get hasImages => images.isNotEmpty;
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  final List<ChatMessage> _messages = []; // used only for demo mode (chatId == null)
  final List<ChatMessage> _localOutgoing = []; // optimistic local messages when chatId != null
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  bool _sendingImage = false;

  bool get _isCommunityChat {
    final cat = widget.creator.categoria?.toLowerCase() ?? '';
    if (cat.contains('comunidad')) return true;
    final planes = widget.creator.planes ?? [];
    for (final p in planes) {
      try {
        final name = (p is Map && p['nombre'] is String) ? (p['nombre'] as String).toLowerCase() : '';
        if (name.contains('comunidad')) return true;
      } catch (_) {}
    }
    return false;
  }

  bool _isCurrentUserCreator(WidgetRef ref) {
    final authUser = ref.read(authNotifierProvider).maybeWhen(data: (u) => u, orElse: () => null);
    if (authUser == null) return false;
    return authUser.id == widget.creator.idUsuario;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Only seed demo messages when no chatId provided
    if (widget.chatId == null) {
      _messages.addAll([
        ChatMessage(
          id: 'm1',
          text: 'Hola! Bienvenido al chat de ${widget.creator.nombreUsuario}.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          fromMe: false,
        ),
        ChatMessage(
          id: 'm2',
          text: 'Gracias! ¿Cómo puedo suscribirme?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
          fromMe: true,
        ),
        ChatMessage(
          id: 'm3',
          text: 'Puedes pulsar Suscribirse en el perfil. 🙂',
          timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
          fromMe: false,
        ),
      ]);
    }

    // Scroll to bottom after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSubmitted(String text) async {
    // Only block community input for non-creators
    final isCreatorSelf = _isCurrentUserCreator(ref);
    if (_isCommunityChat && !isCreatorSelf) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En Comunidad solo el creador puede escribir')));
      return;
    }
    if (text.trim().isEmpty) return;
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      timestamp: DateTime.now(),
      fromMe: true,
    );

    if (widget.chatId != null) {
      // optimistic local append; will be merged with provider messages in the UI
      setState(() {
        _localOutgoing.add(msg);
        _isComposing = false;
      });
    } else {
      setState(() {
        _messages.insert(0, msg); // insert at top because list is reversed
        _isComposing = false;
      });
    }

    _controller.clear();
    _scrollToBottom();

    // Simulate a short reply from creator in demo mode
    if (widget.chatId == null) {
      Future.delayed(const Duration(milliseconds: 700), () {
        final reply = ChatMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_r',
          text: 'Gracias por escribir. Te responderé pronto.',
          timestamp: DateTime.now(),
          fromMe: false,
        );
        setState(() => _messages.insert(0, reply));
        _scrollToBottom();
      });
    } else {
      // If we have a real chatId, send the message through the repository (RPC)
      try {
        final success = await ref.read(creatorRepositoryProvider).enviarMensaje(widget.chatId!, text.trim());
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error enviando mensaje')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error enviando mensaje: $e')));
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    // Only block community input for non-creators
    final isCreatorSelf = _isCurrentUserCreator(ref);
    if (_isCommunityChat && !isCreatorSelf) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En Comunidad solo el creador puede enviar imágenes')));
      return;
    }
    if (widget.chatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat no inicializado')));
      return;
    }

    try {
      setState(() => _sendingImage = true);
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (file == null) { setState(() => _sendingImage = false); return; }

      final Uint8List bytes = await file.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      final ds = ref.read(supabaseDataSourceProvider);
      final url = await ds.uploadChatImage(bytes: bytes, fileName: fileName, pathHint: widget.chatId ?? widget.creator.idUsuario);

      if (url == null || url.isEmpty) {
        throw Exception('No se pudo obtener URL de la imagen subida');
      }

      await _sendImageMessage([url]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error enviando imagen: $e')));
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  Future<void> _sendImageMessage(List<String> urls) async {
    if (widget.chatId == null || urls.isEmpty) return;

    // optimistic local bubbles per image URL
    final now = DateTime.now();
    setState(() {
      for (final u in urls) {
        _localOutgoing.add(ChatMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_img',
          text: u, // use URL so it renders immediately
          timestamp: now,
          fromMe: true,
        ));
      }
    });
    _scrollToBottom();

    try {
      // Prefer repository method with images; fallback to sending the first URL as text
      final repo = ref.read(creatorRepositoryProvider);
      bool ok = false;
      try {
        final id = await repo.enviarMensajeConImagenes(widget.chatId!, '', urls);
        ok = id != null && id.isNotEmpty;
      } catch (_) {
        ok = await repo.enviarMensaje(widget.chatId!, urls.first);
      }
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo enviar la imagen')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error enviando imagen: $e')));
    }
  }

  // Helper to detect image URLs (basic heuristics)
  bool _isImageUrl(String s) {
    final u = s.trim().toLowerCase();
    if (!u.startsWith('http')) return false;
    return u.endsWith('.png') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.gif') ||
        u.contains('image=') || // handles signed URLs with query
        u.contains('content-type=image');
  }

  // Simple widget to render 1..N images as a grid (uses 1 image aspectRatio, otherwise 2-col grid)
  Widget _imagesWidget(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) {
      final u = urls.first;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(
            u,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? (progress.cumulativeBytesLoaded / (progress.expectedTotalBytes!))
                      : null,
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image, size: 32),
            ),
          ),
        ),
      );
    }
    // multiple images -> grid
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: urls.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, i) {
          final u = urls[i];
          return Container(
            color: Colors.black12,
            child: Image.network(
              u,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage m) {
    const radius = Radius.circular(14);
    final align = m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = m.fromMe ? Theme.of(context).colorScheme.primary : Colors.grey[200];
    final textColor = m.fromMe ? Colors.white : Colors.black87;

    // decide if we show images: either explicit images list or text is image URL
    final isImgText = _isImageUrl(m.text);
    final showImages = m.hasImages || isImgText;
    final images = m.hasImages ? m.images : (isImgText ? [m.text] : const <String>[]);
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment: m.fromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!m.fromMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  child: Text(widget.creator.nombreUsuario.isNotEmpty
                      ? widget.creator.nombreUsuario[0].toUpperCase()
                      : '?'),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: m.text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensaje copiado')));
                  },
                  child: Container(
                    width: showImages ? screenWidth * 0.8 : null,
                    padding: showImages ? const EdgeInsets.all(6) : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: showImages
                          ? (m.fromMe ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : Colors.grey[100])
                          : bgColor,
                      borderRadius: BorderRadius.only(
                        topLeft: m.fromMe ? radius : Radius.zero,
                        topRight: m.fromMe ? Radius.zero : radius,
                        bottomLeft: radius,
                        bottomRight: radius,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showImages)
                          _imagesWidget(images)
                        else
                          Text(
                            m.text,
                            style: TextStyle(color: textColor),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          _formatTime(m.timestamp),
                          style: TextStyle(
                            color: (showImages ? Colors.black54 : textColor.withValues(alpha: 0.7)),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (m.fromMe) const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      // show HH:mm
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$h:$min';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      // If we have a chatId, load messages from the provider; otherwise show demo messages
      final authState = ref.watch(authNotifierProvider);

      Widget messagesListWidget() {
        if (widget.chatId == null) {
          // demo/local messages
          final source = (_isCommunityChat && !_isCurrentUserCreator(ref))
              ? _messages.where((m) => !m.fromMe).toList()
              : _messages;
          return ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            itemCount: source.length,
            itemBuilder: (context, index) {
              final m = source[index];
              return _buildMessageBubble(m);
            },
          );
        }

        final mensajesAsync = ref.watch(messagesProvider(widget.chatId!));

        return mensajesAsync.when(
          data: (list) {
            // Map MessageEntity -> ChatMessage (ascending order expected from provider)
            final backendAll = list.map((e) {
              DateTime ts;
              try {
                ts = e.fechaEnvio != null && e.fechaEnvio!.isNotEmpty ? DateTime.parse(e.fechaEnvio!) : DateTime.now();
              } catch (_) {
                ts = DateTime.now();
              }
              final isFromMe = authState.when(data: (u) => u?.id == e.idRemitente, loading: () => false, error: (_, __) => false);
              // FIX: extract URL from each MensajeMultimediaEntity
              final imgs = e.multimedia
                  .map((mm) => mm.url)
                  .where((u) => u.trim().isNotEmpty)
                  .toList();
              return ChatMessage(
                id: e.idMensaje ?? DateTime.now().millisecondsSinceEpoch.toString(),
                text: e.contenido,
                timestamp: ts,
                fromMe: isFromMe,
                images: imgs,
              );
            }).toList();

            // Community mode: only show creator messages (not fromMe) for non-creators
            final backend = (_isCommunityChat && !_isCurrentUserCreator(ref))
                ? backendAll.where((m) => !m.fromMe).toList()
                : backendAll;

            // backend is ascending (oldest -> newest). Append local optimistic messages only if not community mode or if current user is creator
            final combined = (_isCommunityChat && !_isCurrentUserCreator(ref))
                ? backend
                : (List<ChatMessage>.from(backend)..addAll(_localOutgoing));

            return ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              itemCount: combined.length,
              itemBuilder: (context, index) {
                final m = combined[index];
                return _buildMessageBubble(m);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error cargando mensajes: ${e.toString()}')),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                child: Text(widget.creator.nombreUsuario.isNotEmpty ? widget.creator.nombreUsuario[0].toUpperCase() : '?'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.creator.nombreUsuario, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('En línea', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              // IconButton(onPressed: () {}, icon: const Icon(Icons.call)),
              // IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: messagesListWidget(),
                ),
              ),
              const Divider(height: 1),
              // Input disabled in community mode only for non-creators
              if (!(_isCommunityChat && !_isCurrentUserCreator(ref)))
                Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.emoji_emotions_outlined)),
                      // New: image picker button (disabled while uploading)
                      IconButton(
                        onPressed: _sendingImage ? null : _pickAndSendImage,
                        icon: _sendingImage
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.image_outlined),
                        tooltip: 'Enviar imagen',
                      ),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: Scrollbar(
                            child: TextField(
                              controller: _controller,
                              keyboardType: TextInputType.multiline,
                              maxLines: null,
                              decoration: const InputDecoration(
                                hintText: 'Escribe un mensaje',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                setState(() => _isComposing = val.trim().isNotEmpty);
                              },
                              onSubmitted: (val) => _handleSubmitted(val),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isComposing ? () => _handleSubmitted(_controller.text) : null,
                        color: Theme.of(context).colorScheme.primary,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              if (_isCommunityChat && !_isCurrentUserCreator(ref))
                Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  alignment: Alignment.center,
                  child: const Text('Modo Comunidad: solo el creador puede enviar mensajes'),
                ),
            ],
          ),
        ),
      );
    });
  }
}
