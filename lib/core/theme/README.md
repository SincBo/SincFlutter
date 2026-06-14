# 🎨 Tema Sincbo - Documentación

## 📋 Resumen

El tema de Sincbo está diseñado con una paleta de colores moderna y vibrante que refleja una plataforma profesional para creadores de contenido. Incluye soporte completo para modo claro y oscuro.

## 🎨 Paleta de Colores Principal

### Colores Primarios (Turquesa - Color del Icono)
```
Primary:       #00D9C0  ████████
Primary Light: #4DFFE8  ████████
Primary Dark:  #00A894  ████████
```

### Colores Secundarios (Púrpura)
```
Secondary:       #6B4EFF  ████████
Secondary Light: #9B7FFF  ████████
Secondary Dark:  #4A2FD9  ████████
```

### Colores de Acento (Rosa)
```
Accent:       #FF6B9D  ████████
Accent Light: #FF9BB8  ████████
Accent Dark:  #D94A7B  ████████
```

### Colores de Estado
```
Success: #00C853  ████████  (Verde)
Warning: #FFC107  ████████  (Amarillo)
Error:   #FF5252  ████████  (Rojo)
Info:    #2196F3  ████████  (Azul)
```

## 🚀 Uso Rápido

### Importar el tema
```dart
import 'package:sincboflutter/ui/theme/app_theme.dart';
```

### Aplicar en MaterialApp
```dart
MaterialApp(
  theme: AppTheme.lightTheme(),
  darkTheme: AppTheme.darkTheme(),
  themeMode: ThemeMode.system,
  // ...
)
```

### Usar colores del tema
```dart
// Acceder a colores del tema
final theme = Theme.of(context);
Container(color: theme.colorScheme.primary)

// Usar colores directamente
Container(color: AppColors.primary)

// Usar gradientes
Container(
  decoration: BoxDecoration(
    gradient: AppColors.primaryGradient,
  ),
)
```

## 🎭 Gradientes Predefinidos

El tema incluye 4 gradientes listos para usar:

1. **Primary Gradient** - Púrpura
2. **Secondary Gradient** - Rosa
3. **Accent Gradient** - Turquesa
4. **Rainbow Gradient** - Todos los colores combinados

```dart
Container(
  decoration: BoxDecoration(
    gradient: AppColors.rainbowGradient,
    borderRadius: BorderRadius.circular(16),
  ),
)
```

## 📱 Componentes Estilizados

Todos los componentes de Material Design están pre-estilizados:

- ✅ AppBar
- ✅ Buttons (Elevated, Outlined, Text)
- ✅ Cards
- ✅ TextFields
- ✅ Bottom Navigation
- ✅ FloatingActionButton
- ✅ Dividers
- ✅ Icons

## 🎯 Casos de Uso Comunes

### Plan de Suscripción
```dart
// Plan Comunidad - Primary
Container(decoration: BoxDecoration(gradient: AppColors.primaryGradient))

// Plan Fellow - Secondary
Container(decoration: BoxDecoration(gradient: AppColors.secondaryGradient))

// Plan Premium - Rainbow
Container(decoration: BoxDecoration(gradient: AppColors.rainbowGradient))
```

### Estados
```dart
// Éxito
Icon(Icons.check_circle, color: AppColors.success)

// Advertencia
Icon(Icons.warning, color: AppColors.warning)

// Error
Icon(Icons.error, color: AppColors.error)
```

## 👀 Ver Demo

Para ver todos los colores y componentes en acción:

```dart
import 'package:sincboflutter/ui/theme/theme_demo_page.dart';

// Navegar a la página de demo
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => ThemeDemoPage()),
);
```

## 📚 Documentación Completa

Para más información y ejemplos detallados, consulta:
- 📄 [docs/theme_guide.md](../docs/theme_guide.md)

## 🎯 Sugerencias de Uso

### Para Planes/Categorías
- **Comunidad**: `AppColors.primary` (Turquesa - color del icono)
- **Fellow**: `AppColors.secondary` (Púrpura)
- **Premium**: `AppColors.rainbowGradient`
- **Tips**: `AppColors.accent` (Rosa)

### Para Estados de Contenido
- **Publicado**: `AppColors.success`
- **Pendiente**: `AppColors.warning`
- **Rechazado**: `AppColors.error`
- **Información**: `AppColors.info`

### Para Botones
- **Acción Principal**: `ElevatedButton` (usa primary automáticamente)
- **Acción Secundaria**: `OutlinedButton`
- **Acción Terciaria**: `TextButton`

---

**Creado por**: Equipo Sincbo  
**Versión**: 1.0.0  
**Última actualización**: Febrero 2026



