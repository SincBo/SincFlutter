# Guía de Uso del Tema Sincbo

## Paleta de Colores

El tema de la aplicación Sincbo está diseñado basándose en el color turquesa del icono de la marca, con colores complementarios modernos y vibrantes que reflejan una plataforma profesional para creadores de contenido.

### 🎨 Colores Principales

#### **Primary (Turquesa - Color del Icono de Sincbo)**
- **Primary**: `#00D9C0` - Color principal de la marca (del icono)
- **Primary Light**: `#4DFFE8` - Versión más clara
- **Primary Dark**: `#00A894` - Versión más oscura

**Uso**: Botones principales, AppBar, elementos de marca, identidad visual

```dart
// Ejemplo de uso
Container(
  color: AppColors.primary,
  child: Text('Texto', style: TextStyle(color: AppColors.textOnPrimary)),
)

// Con gradiente
Container(
  decoration: BoxDecoration(gradient: AppColors.primaryGradient),
)
```

#### **Secondary (Púrpura)**
- **Secondary**: `#6B4EFF` - Color complementario
- **Secondary Light**: `#9B7FFF`
- **Secondary Dark**: `#4A2FD9`

**Uso**: Acciones secundarias, elementos premium, categorías especiales

```dart
// Ejemplo
ElevatedButton(
  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
  onPressed: () {},
  child: Text('Acción secundaria'),
)
```

#### **Accent (Rosa)**
- **Accent**: `#FF6B9D` - Color de acento
- **Accent Light**: `#FF9BB8`
- **Accent Dark**: `#D94A7B`

**Uso**: Tips, elementos sociales (likes), categorías específicas

```dart
// Badge ejemplo
Container(
  padding: EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: AppColors.accent,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text('Nuevo', style: TextStyle(color: Colors.white)),
)
```

### 🚦 Colores de Estado

```dart
AppColors.success  // #00C853 - Acciones exitosas
AppColors.warning  // #FFC107 - Advertencias
AppColors.error    // #FF5252 - Errores
AppColors.info     // #2196F3 - Información
```

**Ejemplos de uso**:

```dart
// Mensaje de éxito
SnackBar(
  backgroundColor: AppColors.success,
  content: Text('Operación exitosa'),
)

// Alerta de error
Container(
  color: AppColors.error.withOpacity(0.1),
  child: Text('Error', style: TextStyle(color: AppColors.error)),
)
```

### 🌈 Gradientes Predefinidos

El tema incluye gradientes listos para usar:

```dart
// Gradiente primario (Turquesa - Color del icono)
AppColors.primaryGradient

// Gradiente secundario (Púrpura)
AppColors.secondaryGradient

// Gradiente de acento (Rosa)
AppColors.accentGradient

// Gradiente arcoíris (Turquesa → Púrpura → Rosa)
AppColors.rainbowGradient
```

**Ejemplo de uso**:

```dart
Container(
  height: 200,
  decoration: BoxDecoration(
    gradient: AppColors.rainbowGradient,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Center(
    child: Text(
      'Premium',
      style: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
)
```

## 🎭 Temas

La aplicación soporta modo claro y oscuro automáticamente:

```dart
// En main.dart (ya configurado)
MaterialApp(
  theme: AppTheme.lightTheme(),      // Tema claro
  darkTheme: AppTheme.darkTheme(),   // Tema oscuro
  themeMode: ThemeMode.system,       // Automático según sistema
)
```

### Acceder al tema actual:

```dart
// Obtener el tema actual
final theme = Theme.of(context);

// Usar colores del tema
Container(color: theme.colorScheme.primary)

// Usar estilos de texto
Text('Título', style: theme.textTheme.titleLarge)
```

## 📝 Estilos de Texto

```dart
theme.textTheme.displayLarge    // 57px - Títulos muy grandes
theme.textTheme.displayMedium   // 45px
theme.textTheme.displaySmall    // 36px
theme.textTheme.headlineLarge   // 32px - Encabezados
theme.textTheme.headlineMedium  // 28px
theme.textTheme.headlineSmall   // 24px
theme.textTheme.titleLarge      // 22px - Títulos
theme.textTheme.titleMedium     // 16px
theme.textTheme.titleSmall      // 14px
theme.textTheme.bodyLarge       // 16px - Cuerpo de texto
theme.textTheme.bodyMedium      // 14px
theme.textTheme.bodySmall       // 12px
theme.textTheme.labelLarge      // 14px - Etiquetas
theme.textTheme.labelMedium     // 12px
theme.textTheme.labelSmall      // 11px
```

**Ejemplo**:

```dart
Column(
  children: [
    Text('Título Principal', style: theme.textTheme.headlineLarge),
    Text('Subtítulo', style: theme.textTheme.titleMedium),
    Text('Descripción del contenido...', style: theme.textTheme.bodyMedium),
  ],
)
```

## 🎨 Componentes Estilizados

### Botones

Todos los botones ya están estilizados automáticamente:

```dart
// Botón elevado (principal)
ElevatedButton(
  onPressed: () {},
  child: Text('Botón Principal'),
)

// Botón con borde
OutlinedButton(
  onPressed: () {},
  child: Text('Botón Secundario'),
)

// Botón de texto
TextButton(
  onPressed: () {},
  child: Text('Cancelar'),
)
```

### Cards

```dart
Card(
  // Ya tiene border radius de 12px y elevación
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('Contenido'),
  ),
)
```

### Inputs

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Email',
    hintText: 'correo@ejemplo.com',
    prefixIcon: Icon(Icons.email),
  ),
)
```

## 🎨 Variantes de Color para Diferentes Casos de Uso

### Para Planes/Suscripciones

```dart
// Plan Comunidad (Primary - Turquesa)
Container(
  decoration: BoxDecoration(
    gradient: AppColors.primaryGradient,
    borderRadius: BorderRadius.circular(16),
  ),
)

// Plan Fellow (Secondary - Púrpura)
Container(
  decoration: BoxDecoration(
    gradient: AppColors.secondaryGradient,
    borderRadius: BorderRadius.circular(16),
  ),
)

// Plan Premium (Rainbow)
Container(
  decoration: BoxDecoration(
    gradient: AppColors.rainbowGradient,
    borderRadius: BorderRadius.circular(16),
  ),
)
```

### Para Estados de Contenido

```dart
// Contenido publicado
Icon(Icons.check_circle, color: AppColors.success)

// Contenido pendiente
Icon(Icons.pending, color: AppColors.warning)

// Contenido rechazado
Icon(Icons.cancel, color: AppColors.error)

// Información
Icon(Icons.info, color: AppColors.info)
```

### Para Categorías

```dart
final categoryColors = [
  AppColors.primary,
  AppColors.secondary,
  AppColors.accent,
  AppColors.info,
];

// Usar en lista de categorías
GridView.builder(
  itemBuilder: (context, index) {
    final color = categoryColors[index % categoryColors.length];
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          categories[index],
          style: TextStyle(color: color),
        ),
      ),
    );
  },
)
```

## 🌟 Ejemplos Prácticos

### Card de Creador con Gradiente

```dart
Card(
  child: Container(
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(12),
    ),
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.white,
          child: Icon(Icons.person, size: 40, color: AppColors.primary),
        ),
        SizedBox(height: 12),
        Text(
          'Nombre Creador',
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        Text(
          '@username',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ],
    ),
  ),
)
```

### Badge con Contador

```dart
Stack(
  children: [
    Icon(Icons.notifications, size: 28),
    Positioned(
      right: 0,
      top: 0,
      child: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.error,
          shape: BoxShape.circle,
        ),
        constraints: BoxConstraints(minWidth: 16, minHeight: 16),
        child: Text(
          '5',
          style: TextStyle(color: Colors.white, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  ],
)
```

### Botón con Gradiente Personalizado

```dart
Container(
  decoration: BoxDecoration(
    gradient: AppColors.rainbowGradient,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withOpacity(0.3),
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
    ),
    onPressed: () {},
    child: Text('Suscribirse Premium'),
  ),
)
```

## 🎯 Mejores Prácticas

1. **Usa el tema en lugar de colores hardcodeados**:
   ```dart
   // ❌ Evita
   Container(color: Colors.blue)
   
   // ✅ Mejor
   Container(color: theme.colorScheme.primary)
   ```

2. **Usa los colores de estado apropiados**:
   ```dart
   // Para mensajes de éxito
   SnackBar(backgroundColor: AppColors.success)
   
   // Para errores
   SnackBar(backgroundColor: AppColors.error)
   ```

3. **Aprovecha los gradientes**:
   ```dart
   // Da un look más moderno y premium
   decoration: BoxDecoration(gradient: AppColors.primaryGradient)
   ```

4. **Mantén consistencia**:
   - Primary: Acciones principales
   - Secondary: Acciones secundarias
   - Accent: Elementos destacados
   - Success/Warning/Error: Estados

---

**Colores Hex de Referencia Rápida**:
- Primary: `#6B4EFF` (Púrpura)
- Secondary: `#FF6B9D` (Rosa)
- Accent: `#00D9C0` (Turquesa)
- Success: `#00C853` (Verde)
- Warning: `#FFC107` (Amarillo)
- Error: `#FF5252` (Rojo)
- Info: `#2196F3` (Azul)




