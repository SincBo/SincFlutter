import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sincboflutter/domain/entities/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/chat_repository_provider.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/providers/storage_datasource_provider.dart';
import '../../../../core/providers/auth_notifier_provider.dart';

import '../../../../domain/entities/creator.dart';
import '../controllers/provider_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  final CreatorEntity creator;
  final String? chatId;

  const ChatPage({
    super.key,
    required this.creator,
    this.chatId,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool fromMe;
  final List<String> images;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.fromMe,
    this.images = const [],
  });

  bool get hasImages => images.isNotEmpty;
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isComposing = false;
  bool _sendingImage = false;
  bool _pendingScroll = false;

  final List<ChatMessage> _localOutgoing = [];

  RealtimeChannel? _channel;

  bool get _isCommunityChat {
    final cat = widget.creator.categoria?.toLowerCase() ?? '';
    if (cat.contains('comunidad')) return true;

    final planes = widget.creator.planes ?? [];
    for (final p in planes) {
      try {
        final name = (p is Map ? p['nombre'] : '')?.toString().toLowerCase();
        if (name!.contains('comunidad')) return true;
      } catch (_) {}
    }
    return false;
  }

  bool _isCreator(WidgetRef ref) {
    final u = ref.read(authNotifierProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);
    return u?.esCreador ?? false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      if (widget.chatId != null) _subscribe();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText(String text) async {
    final isCreator = _isCreator(ref);
    final currentUserId = ref.read(authNotifierProvider).maybeWhen(
        data: (u) => u?.id, orElse: () => null);
    debugPrint(
        '_sendText -> chatId=${widget.chatId} currentUserId=$currentUserId '
        'isCreator=$isCreator isCommunityChat=$_isCommunityChat '
        'creator.idUsuario=${widget.creator.idUsuario}');

    if (_isCommunityChat && !isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo el creador puede escribir')),
      );
      return;
    }

    if (text.trim().isEmpty) return;

    setState(() => _isComposing = false);

    _controller.clear();
    _pendingScroll = true;

    if (widget.chatId == null) {
      return;
    }

    try {
      final ok = await ref
          .read(chatRepositoryProvider)
          .sendTextMessage(chatId: widget.chatId!, text: text.trim());

      if (ok == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error enviando mensaje')),
        );
      } else {
        ref.invalidate(messagesProvider(widget.chatId!));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _sendImage() async {
    final isCreator = _isCreator(ref);

    // Solo el creador puede mandar imágenes, en cualquier tipo de chat.
    if (!isCreator) return;

    if (widget.chatId == null) return;

    try {
      setState(() => _sendingImage = true);

      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      final storage = ref.read(storageDataSourceProvider);

      final url = await storage.uploadChatImage(
        bytes: bytes,
        fileName: fileName,
        pathHint: widget.chatId!,
      );

      if (url == null) return;

      await ref.read(chatRepositoryProvider).sendImageMessage(
        chatId: widget.chatId!,
        urls: [url],
      );

      ref.invalidate(messagesProvider(widget.chatId!));
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  void _subscribe() {
    final supabase = ref.read(supabaseClientProvider);

    _channel = supabase
        .channel('chat:${widget.chatId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'mensaje',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id_chat',
        value: widget.chatId!,
      ),
      callback: (_) {
        ref.invalidate(messagesProvider(widget.chatId!));
        _scrollToBottom();
      },
    )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(chatControllerProvider);

    final canSend = controller.canSendMessage(
      _isCommunityChat,
      _isCreator(ref),
    );
    final canAttachImage = controller.canSendImage(_isCreator(ref));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.creator.nombreUsuario),
      ),
      body: Padding(padding: EdgeInsets.all(8.0), child: Column(
        children: [
          Expanded(
            child: widget.chatId == null
                ? const Center(child: Text('Demo chat'))
                : ref.watch(messagesProvider(widget.chatId!)).when(
              data: (list) {
                final messages = controller.mapMessages(list);

                final visible = (_isCommunityChat && !_isCreator(ref))
                    ? messages.where((m) => !m.fromMe).toList()
                    : messages;

                final combined = [...visible, ..._localOutgoing];

                combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: combined.length,
                  itemBuilder: (_, i) {
                    final m = combined[i];

                    return Align(
                      alignment: m.fromMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: m.fromMe
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: m.images.isNotEmpty
                            ? Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            for (final img in m.images)
                              Image.network(img),
                          ],
                        )
                            : Text(
                          m.text,
                          style: TextStyle(
                            color: m.fromMe
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error'),
            ),
          ),

          if (canSend)
            SafeArea(
              child: Row(
                children: [
                  if (canAttachImage)
                    IconButton(
                      onPressed: _sendingImage ? null : _sendImage,
                      icon: const Icon(Icons.image),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: (v) =>
                          setState(() => _isComposing = v.isNotEmpty),
                      onSubmitted: _sendText,
                    ),
                  ),
                  IconButton(
                    onPressed: _isComposing
                        ? () => _sendText(_controller.text)
                        : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),

          if(!canSend)
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              alignment: Alignment.center,
              child: const Text(
                'Modo Comunidad: solo el creador puede enviar mensajes',
              ),
            ),
        ],
      ),)
    );
  }
}