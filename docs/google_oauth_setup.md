# Configuración de Google OAuth en Supabase

## 1. Configurar Google Cloud Console

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un nuevo proyecto o selecciona uno existente
3. Ve a **APIs & Services** > **Credentials**
4. Haz clic en **Create Credentials** > **OAuth client ID**
5. Si es la primera vez, configura la **OAuth consent screen**:
   - User Type: **External**
   - App name: **Sincbo**
   - User support email: tu email
   - Developer contact: tu email
6. Crea el **OAuth client ID**:
   - Application type: **Web application**
   - Name: **Sincbo Web Client**
   - Authorized JavaScript origins: deja vacío
   - Authorized redirect URIs: 
     ```
     https://hsbgqbyumyvcxczwuvqv.supabase.co/auth/v1/callback
     ```
7. Guarda el **Client ID** y **Client Secret**

## 2. Configurar en Supabase Dashboard

1. Ve a tu proyecto en [Supabase Dashboard](https://app.supabase.com/)
2. Ve a **Authentication** > **Providers**
3. Busca **Google** y habilítalo
4. Pega el **Client ID** y **Client Secret** de Google Cloud
5. Guarda los cambios

## 3. Agregar Android al OAuth Client

1. Vuelve a Google Cloud Console > Credentials
2. Crea otro **OAuth client ID**:
   - Application type: **Android**
   - Name: **Sincbo Android**
   - Package name: `com.sincbo.sincboflutter`
   - SHA-1 certificate fingerprint: Obtén ejecutando:
     ```bash
     # Para debug (desarrollo)
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
     O si ya tienes un keystore de producción:
     ```bash
     keytool -list -v -keystore /ruta/a/tu/keystore.jks -alias tu-alias
     ```
   - Copia el SHA-1 que aparece en la salida

## 4. Configurar Deep Link en tu app

Ya está configurado en `android/app/src/main/AndroidManifest.xml`:

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

## 5. Uso en la App

El botón de Google ya está conectado en `LoginPage`:

```dart
await ref.read(authNotifierProvider.notifier).signInWithGoogle();
```

## 6. Flujo de OAuth

1. Usuario presiona botón de Google
2. Se abre navegador con pantalla de login de Google
3. Usuario inicia sesión y da permisos
4. Google redirige a: `com.sincbo.sincboflutter://login-callback`
5. La app recibe el deep link y completa el login
6. Se crea automáticamente el usuario en la tabla `usuario` si no existe

## 7. Notas Importantes

- El `redirectTo` debe usar el scheme de tu app: `com.sincbo.sincboflutter://login-callback`
- En producción, necesitarás el SHA-1 de tu keystore de release
- Asegúrate de que en Supabase la URL de redirect esté en la lista permitida

## 8. Testing

Para probar:
1. Genera el APK de debug: `flutter build apk --debug`
2. Instala en un dispositivo físico (no funciona bien en emulador para OAuth)
3. Presiona el botón de Google
4. Verifica que se abra el navegador y puedas iniciar sesión

## Troubleshooting

- **Error 400 redirect_uri_mismatch**: Verifica que la URL de redirect en Google Cloud coincida con la de Supabase
- **No se abre navegador**: Verifica que el intent-filter esté bien configurado en AndroidManifest.xml
- **Usuario no se crea en tabla**: Revisa que no haya RLS (Row Level Security) bloqueando los inserts

