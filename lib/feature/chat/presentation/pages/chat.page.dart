import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auth_notifier_provider.dart';
import '../../../../core/providers/chat/chat.provider.dart';
import '../../../../core/providers/chat_repository_provider.dart';
import '../../../../domain/entities/creator.dart';

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

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _sending = false;
  bool _isComposing = false;

  bool get _hasChat => widget.chatId != null;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.chatId == null) return;

    _controller.clear();

    setState(() => _sending = true);

    await ref.read(chatRepositoryProvider).sendSimpleMessage(
      chatId: widget.chatId!,
      text: text,
    );

    ref.invalidate(chatMessagesProvider(widget.chatId!));

    setState(() => _sending = false);

    _scrollToBottom();
  }

  Future<void> _sendImages(List<String> urls) async {
    if (widget.chatId == null) return;

    setState(() => _sending = true);

    final ok = await ref.read(chatRepositoryProvider).sendImageMessage(
      chatId: widget.chatId!,
      urls: urls,
    );

    if (ok) {
      ref.invalidate(chatMessagesProvider(widget.chatId!));
    }

    setState(() => _sending = false);

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasChat) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.creator.nombreUsuario)),
        body: const Center(child: Text("Chat no inicializado")),
      );
    }

    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId!));
    final auth = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.creator.nombreUsuario),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                final myId = auth.maybeWhen(
                  data: (u) => u?.id,
                  orElse: () => null,
                );

                return ListView.builder(
                  controller: _scroll,
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];

                    final isMe = m.idRemitente == myId;
                    final images = m.multimedia.map((e) => e.url).toList();

                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (images.isNotEmpty)
                              Column(
                                children: images
                                    .map((u) => Image.network(u, height: 180))
                                    .toList(),
                              ),
                            if (m.contenido.isNotEmpty)
                              Text(
                                m.contenido,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text("Error: $e"),
            ),
          ),

          // INPUT
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (v) =>
                        setState(() => _isComposing = v.trim().isNotEmpty),
                    decoration:
                    const InputDecoration(hintText: "Escribe..."),
                  ),
                ),
                IconButton(
                  onPressed: _isComposing ? _sendText : null,
                  icon: _sending
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}