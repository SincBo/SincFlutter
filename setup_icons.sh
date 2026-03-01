#!/bin/bash

# Script para configurar iconos y splash screen de Sincbo
# Colores del tema: Turquesa #00D9C0

echo "🎨 Configuración de Icono y Splash Screen - Sincbo"
echo "=================================================="
echo ""

# Verificar si existen los PNGs necesarios
ICON_FILE="assets/images/icon.png"
SPLASH_FILE="assets/images/splash.png"

if [ ! -f "$ICON_FILE" ]; then
    echo "⚠️  ADVERTENCIA: No se encontró $ICON_FILE"
    echo ""
    echo "Necesitas crear los archivos PNG primero:"
    echo ""
    echo "Opción 1 - Usar convertidor online:"
    echo "  1. Ve a https://cloudconvert.com/svg-to-png"
    echo "  2. Convierte 'assets/images/sinc_turquoise.svg' a PNG (1024x1024)"
    echo "  3. Guárdalo como 'assets/images/icon.png'"
    echo ""
    echo "Opción 2 - Usar ImageMagick (si lo tienes instalado):"
    echo "  brew install imagemagick librsvg"
    echo "  convert -background none -density 1200 -resize 1024x1024 assets/images/sinc_turquoise.svg assets/images/icon.png"
    echo ""
    exit 1
fi

if [ ! -f "$SPLASH_FILE" ]; then
    echo "⚠️  ADVERTENCIA: No se encontró $SPLASH_FILE"
    echo ""
    echo "Necesitas crear el archivo PNG del splash:"
    echo ""
    echo "Opción 1 - Usar convertidor online:"
    echo "  1. Ve a https://cloudconvert.com/svg-to-png"
    echo "  2. Convierte 'assets/images/sinc_white.svg' a PNG (1024x1024)"
    echo "  3. Guárdalo como 'assets/images/splash.png'"
    echo ""
    echo "Opción 2 - Usar ImageMagick:"
    echo "  convert -background none -density 1200 -resize 1024x1024 assets/images/sinc_white.svg assets/images/splash.png"
    echo ""
    exit 1
fi

echo "✅ Archivos PNG encontrados"
echo ""

# Verificar que las dependencias estén instaladas
echo "📦 Instalando dependencias..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Error al instalar dependencias"
    exit 1
fi

echo ""
echo "🎯 Generando iconos de la aplicación..."
dart run flutter_launcher_icons

if [ $? -ne 0 ]; then
    echo "❌ Error al generar iconos"
    exit 1
fi

echo ""
echo "🎨 Generando splash screen..."
dart run flutter_native_splash:create

if [ $? -ne 0 ]; then
    echo "❌ Error al generar splash screen"
    exit 1
fi

echo ""
echo "🧹 Limpiando build anterior..."
flutter clean

echo ""
echo "✅ ¡Configuración completada!"
echo ""
echo "📱 Próximos pasos:"
echo "  1. Ejecuta: flutter run"
echo "  2. Verifica que el icono se vea bien en tu dispositivo"
echo "  3. Verifica que el splash screen se muestre correctamente"
echo ""
echo "🎨 Diseño aplicado:"
echo "  • Icono: Logo turquesa sobre fondo blanco"
echo "  • Splash: Logo blanco sobre fondo turquesa (#00D9C0)"
echo ""

