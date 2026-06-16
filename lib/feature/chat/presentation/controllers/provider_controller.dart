import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_controller.dart';

final chatControllerProvider = Provider((ref) {
  return ChatController(ref);
});