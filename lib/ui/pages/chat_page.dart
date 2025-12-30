import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/creator.dart';
import '../../providers/providers.dart';

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

  ChatMessage({required this.id, required this.text, required this.timestamp, required this.fromMe});
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  final List<ChatMessage> _messages = []; // used only for demo mode (chatId == null)
  final List<ChatMessage> _localOutgoing = []; // optimistic local messages when chatId != null
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;

  bool get _isCommunityChat {
    // Consider "Comunidad" if categoria matches or any plan in planes has nombre == Comunidad
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
    if (_isCommunityChat) {
      // In community mode, user cannot send messages
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

  Widget _buildMessageBubble(ChatMessage m) {
    const radius = Radius.circular(14);
    final align = m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = m.fromMe ? Theme.of(context).colorScheme.primary : Colors.grey[200];
    final textColor = m.fromMe ? Colors.white : Colors.black87;

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
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
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
                        Text(
                          m.text,
                          style: TextStyle(color: textColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatTime(m.timestamp),
                          style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11),
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
          final source = _isCommunityChat ? _messages.where((m) => !m.fromMe).toList() : _messages;
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
              return ChatMessage(id: e.idMensaje ?? DateTime.now().millisecondsSinceEpoch.toString(), text: e.contenido, timestamp: ts, fromMe: isFromMe);
            }).toList();

            // Community mode: only show creator messages (not fromMe)
            final backend = _isCommunityChat ? backendAll.where((m) => !m.fromMe).toList() : backendAll;

            // backend is ascending (oldest -> newest). Append local optimistic messages only if not community mode
            final combined = _isCommunityChat ? backend : (List<ChatMessage>.from(backend)..addAll(_localOutgoing));

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
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.14),
                child: Text(widget.creator.nombreUsuario.isNotEmpty ? widget.creator.nombreUsuario[0].toUpperCase() : '?'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.creator.nombreUsuario, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('En línea', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
                  ],
                ),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.call)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
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
              // Input disabled in community mode
              if (!_isCommunityChat)
                Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.emoji_emotions_outlined)),
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
              if (_isCommunityChat)
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
