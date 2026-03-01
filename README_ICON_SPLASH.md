# 🎨 Configuración de Icono y Splash Screen - Sincbo

## 📋 Resumen

Esta guía te ayudará a configurar el **icono de la app** y el **splash screen** usando el logo de Sincbo con los colores del tema.

## 🎯 Diseño Final

### Icono de la App
```
┌──────────────┐
│              │
│   🔷 LOGO    │  ← Logo turquesa (#00D9C0)
│   TURQUESA   │    sobre fondo blanco
│              │
└──────────────┘
```

### Splash Screen
```
┌──────────────┐
│              │
│   ⬜ LOGO    │  ← Logo BLANCO
│    BLANCO    │    sobre fondo turquesa (#00D9C0)
│              │
└──────────────┘
```

**¿Por qué esta combinación?**
- **Icono**: Logo turquesa (color de la marca) sobre blanco → Se ve bien en cualquier fondo
- **Splash**: Logo blanco sobre turquesa → Máximo contraste, experiencia premium

---

## 🚀 Instalación Rápida (2 pasos)

### Paso 1: Crear los archivos PNG

Tienes **3 opciones** para convertir los SVG a PNG:

#### ⭐ Opción A: Convertidor Online (MÁS FÁCIL)

1. **Para el icono** (logo turquesa):
   - Ve a: https://cloudconvert.com/svg-to-png
   - Sube: `assets/images/sinc_turquoise.svg`
   - Configura: **1024 x 1024 px**
   - Descarga y guarda como: `assets/images/icon.png`

2. **Para el splash** (logo blanco):
   - Ve a: https://cloudconvert.com/svg-to-png
   - Sube: `assets/images/sinc_white.svg`
   - Configura: **1024 x 1024 px**
   - Descarga y guarda como: `assets/images/splash.png`

#### Opción B: Usar Inkscape (Gratis)

```bash
# 1. Descargar Inkscape
https://inkscape.org/

# 2. Abrir cada SVG y exportar:
# - Archivo → Exportar PNG
# - Tamaño: 1024x1024
# - Guardar como icon.png y splash.png
```

#### Opción C: ImageMagick (Terminal)

```bash
# Instalar ImageMagick (solo la primera vez)
brew install imagemagick librsvg

# Convertir SVGs a PNG
cd /Users/pabloperez/Documents/Proyectos/SincFlutter/assets/images
convert -background none -density 1200 -resize 1024x1024 sinc_turquoise.svg icon.png
convert -background none -density 1200 -resize 1024x1024 sinc_white.svg splash.png
```

### Paso 2: Ejecutar el script de configuración

Una vez que tengas `icon.png` y `splash.png` en `assets/images/`:

```bash
cd /Users/pabloperez/Documents/Proyectos/SincFlutter
./setup_icons.sh
```

El script hará automáticamente:
- ✅ Generar todos los tamaños de iconos para Android e iOS
- ✅ Configurar el splash screen
- ✅ Limpiar el proyecto

---

## 🔧 Configuración Manual (Alternativa)

Si prefieres hacerlo manualmente:

### 1. Generar iconos

```bash
dart run flutter_launcher_icons
```

### 2. Generar splash screen

```bash
dart run flutter_native_splash:create
```

### 3. Limpiar y ejecutar

```bash
flutter clean
flutter pub get
flutter run
```

---

## 📁 Archivos Creados

### SVG Disponibles

```
assets/images/
├── sinc.svg              ← Logo original (blanco)
├── sinc_turquoise.svg    ← Logo turquesa (#00D9C0) - Para icono
└── sinc_white.svg        ← Logo blanco - Para splash
```

### PNG que debes crear

```
assets/images/
├── icon.png              ← Convertir sinc_turquoise.svg (1024x1024)
└── splash.png            ← Convertir sinc_white.svg (1024x1024)
```

### Archivos generados automáticamente

Después de ejecutar los comandos, se generarán automáticamente:

**Android:**
```
android/app/src/main/res/
├── mipmap-hdpi/ic_launcher.png
├── mipmap-mdpi/ic_launcher.png
├── mipmap-xhdpi/ic_launcher.png
├── mipmap-xxhdpi/ic_launcher.png
├── mipmap-xxxhdpi/ic_launcher.png
└── drawable/launch_background.xml
```

**iOS:**
```
ios/Runner/Assets.xcassets/
├── AppIcon.appiconset/
│   ├── Icon-App-20x20@1x.png
│   ├── Icon-App-20x20@2x.png
│   └── ... (todos los tamaños)
└── LaunchImage.imageset/
    ├── LaunchImage.png
    ├── LaunchImage@2x.png
    └── LaunchImage@3x.png
```

---

## ⚙️ Configuración en `pubspec.yaml`

Ya está configurado:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/icon.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/images/icon.png"
  min_sdk_android: 21

flutter_native_splash:
  color: "#00D9C0"
  image: "assets/images/splash.png"
  android: true
  ios: true
  android_12:
    color: "#00D9C0"
    image: "assets/images/splash.png"
  ios_content_mode: center
```

---

## 🎨 Personalización

### Cambiar el color del splash

Edita `pubspec.yaml`:

```yaml
flutter_native_splash:
  color: "#TU_COLOR_AQUI"  # Cambia #00D9C0 por otro color
```

### Usar logo diferente para Android e iOS

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path_android: "assets/images/icon_android.png"
  image_path_ios: "assets/images/icon_ios.png"
```

---

## ✅ Verificación

### Checklist después de la configuración

- [ ] Los archivos `icon.png` y `splash.png` existen en `assets/images/`
- [ ] Ejecutaste `dart run flutter_launcher_icons` sin errores
- [ ] Ejecutaste `dart run flutter_native_splash:create` sin errores
- [ ] Ejecutaste `flutter clean`
- [ ] El icono se ve bien en el launcher
- [ ] El splash screen aparece al iniciar la app
- [ ] Los colores coinciden con el tema (#00D9C0)

### ¿Cómo verificar?

1. **Icono**:
   - Instala la app en un dispositivo/emulador
   - Ve al launcher y busca el icono de Sincbo
   - Debe verse el logo turquesa sobre fondo blanco

2. **Splash Screen**:
   - Cierra la app completamente
   - Ábrela de nuevo
   - Debes ver el logo blanco sobre fondo turquesa por 1-2 segundos

---

## 🐛 Solución de Problemas

### El splash no aparece

```bash
# Limpiar completamente
flutter clean
rm -rf build/
rm -rf ios/Pods
rm -rf ios/.symlinks

# Reinstalar
flutter pub get
dart run flutter_native_splash:create
flutter run
```

### El icono no cambia

```bash
# Desinstalar app del dispositivo
# Regenerar iconos
dart run flutter_launcher_icons
flutter clean
flutter run
```

### Errores de tamaño de imagen

Asegúrate de que tus PNGs sean:
- **Mínimo**: 512x512 px
- **Recomendado**: 1024x1024 px
- **Fondo**: Transparente (PNG con alpha channel)

---

## 📚 Recursos

- [CloudConvert](https://cloudconvert.com/svg-to-png) - Convertir SVG a PNG
- [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) - Documentación
- [flutter_native_splash](https://pub.dev/packages/flutter_native_splash) - Documentación
- [Inkscape](https://inkscape.org/) - Editor SVG gratuito

---

## 🎯 Próximos Pasos

Después de configurar el icono y splash:

1. ✅ Tema de colores ya configurado (`lib/ui/theme/app_theme.dart`)
2. ✅ Icono y splash configurados
3. 🚀 Generar APK de prueba: `flutter build apk --debug`
4. 📱 Instalar en dispositivo y verificar

---

**¿Necesitas ayuda?** Consulta `docs/icon_splash_setup.md` para más detalles.

