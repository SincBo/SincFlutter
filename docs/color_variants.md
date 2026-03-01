# 🎨 Variantes de Color - Tema Sincbo

## Paleta de Colores Completa

### 1️⃣ Colores Principales - Turquesa (Primary - Color del Icono de Sincbo)

| Nombre | Hex | RGB | Uso Recomendado |
|--------|-----|-----|-----------------|
| **Primary Dark** | `#00A894` | `rgb(0, 168, 148)` | Hover states, elementos oscuros |
| **Primary** | `#00D9C0` | `rgb(0, 217, 192)` | **Color principal de marca (icono)** |
| **Primary Light** | `#4DFFE8` | `rgb(77, 255, 232)` | Fondos sutiles, tema oscuro |

**Variaciones de opacidad del Primary**:
- 10%: Fondos muy sutiles
- 20%: Backgrounds de cards
- 40%: Elementos disabled
- 60%: Overlays
- 100%: Botones principales

### 2️⃣ Colores Secundarios - Púrpura (Secondary)

| Nombre | Hex | RGB | Uso Recomendado |
|--------|-----|-----|-----------------|
| **Secondary Dark** | `#4A2FD9` | `rgb(74, 47, 217)` | Hover states secundarios |
| **Secondary** | `#6B4EFF` | `rgb(107, 78, 255)` | **Acciones secundarias** |
| **Secondary Light** | `#9B7FFF` | `rgb(155, 127, 255)` | Fondos sutiles púrpura |

**Casos de uso**:
- Plan Fellow
- Categoría "Premium/Exclusivo"
- Elementos destacados
- Secciones especiales

### 3️⃣ Colores de Acento - Rosa (Accent)

| Nombre | Hex | RGB | Uso Recomendado |
|--------|-----|-----|-----------------|
| **Accent Dark** | `#D94A7B` | `rgb(217, 74, 123)` | Hover de elementos accent |
| **Accent** | `#FF6B9D` | `rgb(255, 107, 157)` | **Elementos destacados** |
| **Accent Light** | `#FF9BB8` | `rgb(255, 155, 184)` | Fondos muy claros |

**Casos de uso**:
- Likes, favoritos
- Tips/propinas
- Elementos sociales
- Categorías románticas/suaves

### 4️⃣ Colores de Estado

| Nombre | Hex | RGB | Uso |
|--------|-----|-----|-----|
| **Success** | `#00C853` | `rgb(0, 200, 83)` | Éxito, completado, activo |
| **Warning** | `#FFC107` | `rgb(255, 193, 7)` | Advertencias, pendiente |
| **Error** | `#FF5252` | `rgb(255, 82, 82)` | Errores, rechazado, cancelado |
| **Info** | `#2196F3` | `rgb(33, 150, 243)` | Información, ayuda |

## 🎨 Combinaciones de Colores Sugeridas

### Para Planes de Suscripción

```dart
// Plan Básico/Comunidad - Turquesa (color del icono)
Gradient: AppColors.primaryGradient
Color sólido: AppColors.primary
Texto sobre color: Colors.white

// Plan Fellow - Púrpura
Gradient: AppColors.secondaryGradient
Color sólido: AppColors.secondary
Texto sobre color: Colors.white

// Plan Premium - Arcoíris
Gradient: AppColors.rainbowGradient
Color sólido: Usar gradiente
Texto sobre color: Colors.white

// Plan Tips - Rosa
Gradient: AppColors.accentGradient
Color sólido: AppColors.accent
Texto sobre color: Colors.white
```

### Para Categorías de Contenido

```dart
const categoryColorMap = {
  'Arte': AppColors.accent,              // Rosa
  'Música': AppColors.secondary,         // Púrpura
  'Educación': AppColors.info,           // Azul
  'Tecnología': AppColors.primary,       // Turquesa (color del icono)
  'Fitness': AppColors.success,          // Verde
  'Cocina': AppColors.warning,           // Amarillo
  'Gaming': AppColors.secondaryLight,    // Púrpura claro
  'Lifestyle': AppColors.accentLight,    // Rosa claro
};
```

### Para Estados de Transacción

```dart
const transactionStatusColors = {
  'pendiente': AppColors.warning,     // Amarillo
  'completado': AppColors.success,    // Verde
  'fallido': AppColors.error,         // Rojo
  'procesando': AppColors.info,       // Azul
  'cancelado': AppColors.textSecondary, // Gris
};
```

### Para Niveles de Suscriptores

```dart
// Suscriptor nuevo (< 1 mes)
Color: AppColors.primaryLight (turquesa claro)
Icon: Icons.fiber_new

// Suscriptor activo (1-6 meses)
Color: AppColors.primary (turquesa - color del icono)
Icon: Icons.verified

// Suscriptor VIP (> 6 meses)
Color: AppColors.secondary (púrpura)
Icon: Icons.star
Gradient: AppColors.rainbowGradient
```

## 🌈 Gradientes y sus Casos de Uso

### 1. Primary Gradient (Turquesa - Color del Icono)
```dart
AppColors.primaryGradient
// Colors: [#00D9C0 → #4DFFE8]
```
**Usar para**:
- Plan Comunidad
- Headers principales
- Botones de acción principal
- Elementos de marca/identidad

### 2. Secondary Gradient (Púrpura)
```dart
AppColors.secondaryGradient
// Colors: [#6B4EFF → #9B7FFF]
```
**Usar para**:
- Plan Fellow
- Elementos premium/exclusivos
- Secciones especiales
- Contenido destacado

### 3. Accent Gradient (Rosa)
```dart
AppColors.accentGradient
// Colors: [#FF6B9D → #FF9BB8]
```
**Usar para**:
- Tips y donaciones
- Interacciones sociales (likes, follows)
- Elementos de comunidad
- Badges de "Popular"

### 4. Rainbow Gradient (Multi-color)
```dart
AppColors.rainbowGradient
// Colors: [#00D9C0 → #6B4EFF → #FF6B9D]
```
**Usar para**:
- Plan Premium/VIP
- Elementos especiales
- Celebraciones (aniversarios, logros)
- Banners promocionales

## 🎯 Guía de Uso por Contexto

### Perfil de Creador

```dart
// Avatar border
Gradient: AppColors.primaryGradient (si es creador verificado - turquesa)
Gradient: AppColors.secondaryGradient (si es top creator - púrpura)
Gradient: AppColors.rainbowGradient (si es premium creator)

// Badge de verificación
Color: AppColors.primary (turquesa - color del icono)
Icon: Icons.verified

// Estadísticas
Suscriptores: AppColors.primary (turquesa)
Ganancias: AppColors.success (verde)
Posts: AppColors.info (azul)
Likes: AppColors.accent (rosa)
```

### Chat/Mensajería

```dart
// Mensaje enviado (usuario)
Background: AppColors.primary con 10% opacidad
Texto: AppColors.textPrimary
Borde: AppColors.primary

// Mensaje recibido (creador)
Background: AppColors.surface
Texto: AppColors.textPrimary
Borde: AppColors.divider

// Indicador de typing
Color: AppColors.accent animado

// Mensaje no leído badge
Color: AppColors.error
```

### Ganancias/Estadísticas del Creador

```dart
// Total ganado
Color: AppColors.success
Gradient: LinearGradient([AppColors.success, AppColors.primary])

// Ganancias de Comunidad
Color: AppColors.primary (turquesa - color principal)

// Ganancias de Fellow
Color: AppColors.secondary (púrpura)

// Tips recibidos
Color: AppColors.accent (rosa)

// Contenido solicitado
Color: AppColors.warning
```

### Notificaciones

```dart
// Nuevo suscriptor
Color: AppColors.primary (turquesa)
Icon: Icons.person_add

// Nueva donación/tip
Color: AppColors.accent (rosa)
Icon: Icons.paid

// Nuevo mensaje
Color: AppColors.info
Icon: Icons.message

// Contenido aprobado
Color: AppColors.success
Icon: Icons.check_circle

// Alerta/advertencia
Color: AppColors.warning
Icon: Icons.warning
```

## 💡 Tips de Diseño

### Contraste de Texto

**Sobre fondos de color**:
- Primary/Secondary/Accent oscuros → `Colors.white`
- Primary/Secondary/Accent claros → `AppColors.textPrimary`
- Fondos claros → `AppColors.textPrimary`
- Fondos oscuros → `Colors.white`

### Accesibilidad

Todos los colores cumplen con WCAG AA cuando se usan con:
- Colores primarios + texto blanco ✅
- Colores de estado + texto blanco ✅
- Fondos claros + textPrimary ✅

### Espaciado y Bordes

**BorderRadius recomendados**:
- Botones: `8px`
- Cards: `12px`
- Modals/Sheets: `16px` (top corners)
- Chips/Badges: `16px` (pill shape)
- Avatars: `circular` (50%)

**Elevación (shadows)**:
- Cards: `elevation: 2`
- Floating buttons: `elevation: 4`
- Modals: `elevation: 8`
- Dropdowns: `elevation: 6`

## 📱 Ejemplos de Código

### Card con Plan
```dart
ThemeExamples.subscriptionPlanCard(
  context: context,
  planName: 'Fellow',
  price: '9.99 bs',
  description: 'Acceso completo a contenido exclusivo',
  gradient: AppColors.secondaryGradient,
  onSubscribe: () {},
)
```

### Badge de Notificación
```dart
ThemeExamples.notificationBadge(
  icon: Icons.notifications,
  count: 5,
  badgeColor: AppColors.error,
)
```

### Chip de Categoría
```dart
ThemeExamples.categoryChip(
  label: 'Arte',
  backgroundColor: AppColors.secondary,
  onTap: () {},
)
```

---

**Colores Hex de Referencia Rápida**:
- Primary: `#00D9C0` (Turquesa - Color del Icono de Sincbo)
- Secondary: `#6B4EFF` (Púrpura)
- Accent: `#FF6B9D` (Rosa)
- Success: `#00C853` (Verde)
- Warning: `#FFC107` (Amarillo)
- Error: `#FF5252` (Rojo)
- Info: `#2196F3` (Azul)

**Versión**: 1.0.0  
**Actualizado**: Febrero 2026










