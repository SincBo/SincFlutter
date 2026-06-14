import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageDataSource {
  final SupabaseClient client;

  StorageDataSource(this.client);

  /// Sube una imagen o archivo al bucket `chat-media`
  /// y devuelve una URL firmada o pública.
  Future<String?> uploadChatImage({
    required Uint8List bytes,
    required String fileName,
    String? pathHint,
    String contentType = 'image/jpeg',
    Duration signedUrlTTL = const Duration(days: 7),
  }) async {
    try {
      final bucket = client.storage.from('chat-media');

      final objectPath = (pathHint != null && pathHint.isNotEmpty)
          ? '$pathHint/$fileName'
          : fileName;

      await bucket.uploadBinary(
        objectPath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: false,
        ),
      );

      // 1. intentar URL firmada (recomendado si bucket es privado)
      try {
        final signed = await bucket.createSignedUrl(
          objectPath,
          signedUrlTTL.inSeconds,
        );
        if (signed.isNotEmpty) return signed;
      } catch (_) {}

      // 2. fallback a pública
      final publicUrl = bucket.getPublicUrl(objectPath);
      if (publicUrl.isNotEmpty) return publicUrl;

      return null;
    } catch (e) {
      debugPrint('uploadChatImage -> error: $e');
      return null;
    }
  }

  /// Subida genérica (reutilizable para futuros módulos)
  Future<String?> uploadFile({
    required Uint8List bytes,
    required String bucketName,
    required String filePath,
    String contentType = 'application/octet-stream',
  }) async {
    try {
      final bucket = client.storage.from(bucketName);

      await bucket.uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: false,
        ),
      );

      final publicUrl = bucket.getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      debugPrint('uploadFile -> error: $e');
      return null;
    }
  }
}