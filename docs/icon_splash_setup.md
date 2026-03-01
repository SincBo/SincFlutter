# 📱 Configuración de Icono y Splash Screen para Sincbo

## 🎯 Estado Actual

El tema de Sincbo ya está configurado con el color turquesa (`#00D9C0`) del icono. Ahora necesitamos configurar:
1. **Icono de la app** (launcher icon)
2. **Splash screen** (pantalla de carga)

## 🎨 Recursos Actuales

- ✅ **SVG del icono**: `assets/images/sinc.svg` (blanco)
- ✅ **SVG turquesa**: `assets/images/sinc_turquoise.svg` (con color #00D9C0)

## ⚠️ Problema

Los paquetes de Flutter (`flutter_launcher_icons` y `flutter_native_splash`) **no soportan SVG directamente**. Necesitan PNG.

## 🛠️ Solución: Convertir SVG a PNG

### Opción 1: Usar un convertidor online (Más fácil)

1. Ve a uno de estos sitios:
   - https://cloudconvert.com/svg-to-png
   - https://www.adobe.com/express/feature/image/convert/svg-to-png
   - https://convertio.co/es/svg-png/

2. Sube `assets/images/sinc_turquoise.svg`

3. Configura las siguientes dimensiones:
   - **Para icono**: 1024x1024 px (o más grande, el logo se adaptará)
   - **Para splash**: 1024x1024 px

4. Descarga el PNG y guárdalo como:
   - `assets/images/icon.png` (para el icono)
   - `assets/images/splash.png` (para el splash screen)

### Opción 2: Usar Inkscape (Gratis)

1. Descarga Inkscape: https://inkscape.org/
2. Abre `sinc_turquoise.svg`
3. Ve a **Archivo → Exportar imagen PNG**
4. Configura:
   - Ancho: 1024px
   - Alto: 1024px
5. Exporta como `icon.png` y `splash.png`

### Opción 3: Usar ImageMagick (Para desarrolladores)

Si tienes Homebrew en Mac:

```bash
# Instalar ImageMagick
brew install imagemagick librsvg

# Convertir SVG a PNG
cd /Users/pabloperez/Documents/Proyectos/SincFlutter/assets/images
convert -background none -density 1200 -resize 1024x1024 sinc_turquoise.svg icon.png
convert -background none -density 1200 -resize 1024x1024 sinc_turquoise.svg splash.png
```

### Opción 4: Usar un diseñador gráfico

Si tienes acceso a Adobe Illustrator, Photoshop, o Figma:
- Importa el SVG
- Exporta como PNG de 1024x1024px con fondo transparente

## 📝 Configuración Actual en `pubspec.yaml`

Ya está configurado para usar los PNGs una vez que los crees:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/icon.png"  # ← Crear este archivo
  adaptive_icon_background: "#00D9C0"
  adaptive_icon_foreground: "assets/images/icon.png"
  min_sdk_android: 21

flutter_native_splash:
  color: "#00D9C0"
  image: "assets/images/splash.png"  # ← Crear este archivo
  android: true
  ios: true
  web: false
  
  android_12:
    color: "#00D9C0"
    image: "assets/images/splash.png"
  
  ios_content_mode: center
```

## 🚀 Pasos para Aplicar (Después de crear los PNGs)

### 1. Actualizar `pubspec.yaml`

Ya está actualizado, solo necesitas verificar que los archivos PNG existan.

### 2. Generar el icono de la app

```bash
cd /Users/pabloperez/Documents/Proyectos/SincFlutter
dart run flutter_launcher_icons
```

Esto generará automáticamente todos los iconos para Android e iOS en los tamaños correctos.

### 3. Generar el splash screen

```bash
dart run flutter_native_splash:create
```

Esto configurará el splash screen con el color turquesa y tu logo.

### 4. Verificar los cambios

Para Android:
- Los iconos se generan en: `android/app/src/main/res/`
- El splash se configura en: `android/app/src/main/res/drawable/`

Para iOS:
- Los iconos se generan en: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- El splash se configura en: `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

### 5. Probar en el emulador/dispositivo

```bash
# Limpiar build anterior
flutter clean

# Compilar y ejecutar
flutter run
```

## 🎨 Diseño del Splash Screen

El splash screen tendrá:
- **Fondo**: Turquesa sólido (#00D9C0) - color del icono
- **Logo**: El icono de Sincbo en turquesa (centrado)
- **Efecto**: En Android 12+, usará el nuevo sistema de splash screens con animación

## 📱 Vista Previa

```
┌─────────────────────────┐
│                         │
│                         │
│       ┌─────────┐       │
│       │         │       │  ← Logo de Sincbo
│       │  SINCBO │       │    (turquesa sobre turquesa,
│       │         │       │     se verá el contorno)
│       └─────────┘       │
│                         │
│                         │
└─────────────────────────┘
     Color de fondo: #00D9C0
```

## 💡 Recomendación

Para mejor visibilidad, considera crear **dos versiones del logo**:

1. **Para el icono de la app**: Logo turquesa con fondo blanco o transparente
2. **Para el splash**: Logo blanco sobre fondo turquesa

Si quieres hacer esto, puedo crear otro SVG con el logo en blanco.

## 🔧 Comandos Rápidos (Resumen)

```bash
# 1. Después de crear icon.png y splash.png
cd /Users/pabloperez/Documents/Proyectos/SincFlutter

# 2. Generar iconos
dart run flutter_launcher_icons

# 3. Generar splash screen
dart run flutter_native_splash:create

# 4. Limpiar y reconstruir
flutter clean
flutter pub get
flutter run
```

## ✅ Checklist

- [ ] Convertir `sinc_turquoise.svg` a PNG (1024x1024)
- [ ] Guardar como `assets/images/icon.png`
- [ ] Guardar como `assets/images/splash.png`
- [ ] Ejecutar `dart run flutter_launcher_icons`
- [ ] Ejecutar `dart run flutter_native_splash:create`
- [ ] Ejecutar `flutter clean && flutter run`
- [ ] Verificar que el icono se vea bien
- [ ] Verificar que el splash screen se vea bien

## 🎨 Alternativa: Logo Blanco para Splash

Si quieres que el logo del splash sea blanco (mejor contraste), puedo crear `sinc_white.svg` y usarlo solo para el splash screen.

---

**¿Necesitas ayuda con alguno de estos pasos?** Puedo crear el SVG blanco o ajustar la configuración según tus preferencias.

