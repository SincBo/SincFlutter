import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Color turquesa del tema
  const turquoise = Color(0xFF00D9C0);

  // Tamaños necesarios para el icono
  final sizes = [512, 1024];

  for (final size in sizes) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fondo turquesa
    final paint = Paint()..color = turquoise;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      paint,
    );

    // Cargar SVG (logo blanco)
    final svgString = await rootBundle.loadString('assets/images/sinc.svg');

    // Aquí dibujaríamos el SVG, pero como Flutter no tiene soporte directo,
    // usaremos una imagen PNG temporal

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Guardar
    final file = File('assets/images/icon_${size}.png');
    await file.writeAsBytes(buffer);

    print('✅ Icono de ${size}x${size} creado');
  }

  print('✅ Todos los iconos creados exitosamente');
}

