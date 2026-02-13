# Configuración de Facebook OAuth en Supabase

## 1. Crear Facebook App

1. Ve a [Facebook Developers](https://developers.facebook.com/)
2. Haz clic en **My Apps** > **Create App**
3. Selecciona tipo: **Consumer**
4. Nombre de la app: **Sincbo**
5. Email de contacto: tu email
6. Crea la app

## 2. Configurar Facebook Login

1. En el dashboard de tu app, ve a **Add Product**
2. Busca **Facebook Login** y haz clic en **Set Up**
3. Selecciona plataforma: **Android**
4. Configura:
   - **Package Name**: `com.sincbo.sincboflutter`
   - **Default Activity Class Name**: `com.sincbo.sincboflutter.MainActivity`
   - **Key Hashes**: Obtener con:
     ```bash
     # Para debug keystore
     keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
     # Contraseña: android
     ```
     O si tienes keystore de producción:
     ```bash
     keytool -exportcert -alias tu-alias -keystore /ruta/a/tu/keystore.jks | openssl sha1 -binary | openssl base64
     ```

## 3. Configurar OAuth Redirect URIs

1. En el panel izquierdo, ve a **Facebook Login** > **Settings**
2. En **Valid OAuth Redirect URIs**, agrega:
   ```
   https://hsbgqbyumyvcxczwuvqv.supabase.co/auth/v1/callback
   ```
3. Guarda los cambios

## 4. Obtener App ID y App Secret

1. Ve a **Settings** > **Basic**
2. Copia:
   - **App ID** (ej: `1234567890123456`)
   - **App Secret** (haz clic en "Show" para verlo)

## 5. Configurar en Supabase Dashboard

1. Ve a tu proyecto en [Supabase Dashboard](https://app.supabase.com/)
2. Ve a **Authentication** > **Providers**
3. Busca **Facebook** y habilítalo
4. Pega:
   - **Facebook App ID**
   - **Facebook App Secret**
5. Copia la **Callback URL** que te muestra Supabase:
   ```
   https://hsbgqbyumyvcxczwuvqv.supabase.co/auth/v1/callback
   ```
6. Guarda los cambios

## 6. Modo de App en Facebook

Para testing:
- La app está en modo **Development** por defecto
- Solo los usuarios agregados como **Testers** pueden usarla

Para producción:
1. Ve a **Settings** > **Basic**
2. Completa toda la información requerida:
   - Privacy Policy URL
   - Terms of Service URL
   - App Icon
   - Category
3. Ve a la parte superior y cambia el modo de **Development** a **Live**

## 7. Agregar Testers (Modo Development)

1. Ve a **Roles** > **Test Users**
2. Crea usuarios de prueba o agrega usuarios existentes
3. Los testers podrán usar la app en modo development

## 8. Configuración en Android (Ya está hecho)

El deep link ya está configurado en `AndroidManifest.xml`:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="com.sincbo.sincboflutter"
        android:host="login-callback" />
</intent-filter>
```

## 9. Uso en la App

El botón de Facebook ya está conectado en `LoginPage`:

```dart
await ref.read(authNotifierProvider.notifier).signInWithFacebook();
```

## 10. Flujo de OAuth con Facebook

1. Usuario presiona botón de Facebook
2. Se abre navegador con pantalla de login de Facebook
3. Usuario inicia sesión y da permisos
4. Facebook redirige a: `com.sincbo.sincboflutter://login-callback`
5. La app recibe el deep link y completa el login
6. Si es usuario nuevo → Muestra formulario de registro pre-llenado
7. Si es usuario existente → Login directo

## 11. Permisos de Facebook

Por defecto, Facebook OAuth solicita:
- **email** (correo electrónico del usuario)
- **public_profile** (nombre, foto de perfil)

Si necesitas permisos adicionales (ej: `user_friends`, `user_birthday`), debes:
1. Solicitarlos en tu Facebook App
2. Pasar por el proceso de **App Review** de Facebook

## 12. Datos que Obtienes

Del perfil de Facebook obtendrás:
```dart
userMetadata?['full_name']  // Nombre completo
userMetadata?['name']       // Nombre
email                       // Correo electrónico
```

## Testing

### Flujo de prueba completo:

1. **Primera vez con Facebook**:
   ```
   Click Facebook → Login en Facebook → Autorizar → 
   Formulario pre-llenado → Completar datos → Entrar a la app
   ```

2. **Usuario existente**:
   ```
   Click Facebook → Login en Facebook → 
   Entrar directamente (sin formulario)
   ```

3. **Cerrar sesión y re-login**:
   ```
   Cerrar sesión → Click Facebook → Login → 
   Entrar en primer intento ✅
   ```

## Troubleshooting

### Error: "Invalid Key Hash"
- Verifica que el Key Hash en Facebook coincida con el de tu keystore
- Para debug, usa el debug.keystore
- Para producción, usa tu release keystore

### Error: "App Not Setup"
- Verifica que Facebook Login esté habilitado en tu app
- Verifica que la app esté en modo Live o que tu usuario sea tester

### Error: "Invalid OAuth Redirect URI"
- Verifica que la URL de redirect en Facebook coincida con la de Supabase
- Debe ser: `https://hsbgqbyumyvcxczwuvqv.supabase.co/auth/v1/callback`

### No se obtiene el email
- Algunos usuarios de Facebook no tienen email público
- Maneja este caso en tu código (el email puede ser null)
- Solicita permisos adicionales si es necesario

## Comandos Útiles

```bash
# Generar Key Hash para Facebook (debug)
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64

# Ver certificado del keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Generar APK de prueba
flutter build apk --debug

# Ver logs
adb logcat | grep -E "LoginPage|signInWithFacebook|Auth state"
```

## Comparación Google vs Facebook

| Característica | Google | Facebook |
|---------------|--------|----------|
| **Setup** | Más simple | Requiere más configuración |
| **Key Hash** | SHA-1 | Base64 del SHA-1 |
| **Email garantizado** | Sí | No siempre |
| **App Review** | No requerido | Requerido para permisos extras |
| **Modo desarrollo** | No aplica | Solo testers pueden usar |
| **Datos del perfil** | Completos | Limitados sin permisos extras |

## Notas Importantes

⚠️ **Modo Development**: Solo usuarios agregados como testers pueden iniciar sesión

⚠️ **Email opcional**: Facebook puede no proporcionar email, maneja este caso

⚠️ **Deep Link**: Usa el mismo que Google (`com.sincbo.sincboflutter://login-callback`)

⚠️ **Key Hash correcto**: Debe coincidir exactamente con tu keystore

✅ **Mismo flujo que Google**: Detección de usuarios nuevos, formulario pre-llenado, loading state

