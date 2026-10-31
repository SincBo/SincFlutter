import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:sincboflutter/core/providers/auth_repository_provider.dart';

import '../../../../core/providers/auth_notifier_provider.dart';
import '../../../../domain/entities/user.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  void _showSignInSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: SignInSheet(),
      ),
    );
  }

  void _showSignUpSheet(BuildContext context, {
    String? prefilledNombre,
    String? prefilledApellido,
    String? prefilledEmail,
    bool isOAuthSignup = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: SignUpSheet(
          prefilledNombre: prefilledNombre,
          prefilledApellido: prefilledApellido,
          prefilledEmail: prefilledEmail,
          isOAuthSignup: isOAuthSignup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No ref.listen aquí: AuthGate ya maneja la navegación reactiva.
    // El botón de Google navega manualmente cuando corresponde.
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App icon (CircleAvatar with Icon fallback)
                CircleAvatar(
                  radius: 60,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.people_alt,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sincbo',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                // Sign in button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Inicio de sesión'),
                    ),
                    onPressed: () => _showSignInSheet(context),
                  ),
                ),
                const SizedBox(height: 12),

                // Register button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Registro'),
                    ),
                    onPressed: () => _showSignUpSheet(context),
                  ),
                ),
                const SizedBox(height: 20),

                // Divider / hint
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('o continuar con'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // Social buttons
                Row(
                  children: [
                    // Google
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: BorderSide(color: theme.dividerColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _isGoogleLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                            )
                          : const FaIcon(FontAwesomeIcons.google, color: Colors.red, size: 20),
                        label: Text(_isGoogleLoading ? 'Cargando...' : 'Google'),
                        onPressed: _isGoogleLoading ? null : () async {
                          setState(() => _isGoogleLoading = true);
                          try {
                            final ds = ref.read(authRepositoryProvider);

                            // PASO 0: si ya hay sesión activa con perfil, usarla directamente
                            final existingUser = await ds.getCurrentUser();
                            if (existingUser != null) {
                              ref.read(authNotifierProvider.notifier).setUser(existingUser);
                              if (mounted) setState(() => _isGoogleLoading = false);
                              return;
                            }

                            // PASO 1: iniciar OAuth Google
                            final oauthUser = await ds.signInGoogle();

                            if (!mounted) return;

                            if (oauthUser != null) {
                              // Usuario existente con perfil
                              ref.read(authNotifierProvider.notifier).setUser(oauthUser);
                              if (mounted) setState(() => _isGoogleLoading = false);
                              return;
                            }

                            // PASO 2: OAuth puede haber funcionado pero sin perfil aún — reintentar
                            await Future.delayed(const Duration(milliseconds: 800));

                            UserEntity? fullUser;
                            for (int i = 1; i <= 5; i++) {
                              fullUser = await ds.getCurrentUser();
                              if (fullUser != null) break;
                              await Future.delayed(const Duration(milliseconds: 600));
                            }

                            if (!mounted) return;

                            if (fullUser != null) {
                              ref.read(authNotifierProvider.notifier).setUser(fullUser);
                              if (mounted) setState(() => _isGoogleLoading = false);
                              return;
                            }

                            // PASO 3: verificar si OAuth funcionó (usuario nuevo sin perfil)
                            final isAuth = await ds.isAuthenticated();
                            setState(() => _isGoogleLoading = false);

                            if (!isAuth) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No se pudo iniciar sesión con Google')),
                              );
                              return;
                            }

                            // Usuario nuevo — obtener datos para pre-llenar el form
                            final authInfo = await ds.getAuthUserInfo();
                            final fullName = authInfo?.displayName ?? '';
                            final parts = fullName.split(' ');

                            if (!mounted) return;
                            await showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              isDismissible: false,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              builder: (ctx) => Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: SignUpSheet(
                                  prefilledNombre: parts.isNotEmpty ? parts.first : '',
                                  prefilledApellido: parts.length > 1 ? parts.sublist(1).join(' ') : '',
                                  prefilledEmail: authInfo?.email ?? '',
                                  isOAuthSignup: true,
                                ),
                              ),
                            );
                          } catch (e) {
                            debugPrint('LoginPage -> Google error: $e');
                            if (mounted) {
                              setState(() => _isGoogleLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error con Google: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),

                // Botón Apple — solo visible en iOS
                if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SignInWithAppleButton(
                      onPressed: _isAppleLoading
                          ? () {}
                          : () async {
                              setState(() => _isAppleLoading = true);
                              try {
                                final ds = ref.read(authRepositoryProvider);

                                final result = await ds.signInApple();

                                if (!mounted) return;

                                if (result != null) {
                                  // Usuario existente con perfil
                                  ref
                                      .read(authNotifierProvider.notifier)
                                      .setUser(result);
                                  if (mounted) {
                                    setState(() => _isAppleLoading = false);
                                  }
                                  return;
                                }

                                // Sin perfil aún — reintentar
                                await Future.delayed(
                                    const Duration(milliseconds: 500));

                                UserEntity? fullUser;
                                for (int i = 1; i <= 3; i++) {
                                  fullUser = await ds.getCurrentUser();
                                  if (fullUser != null) break;
                                  await Future.delayed(
                                      const Duration(milliseconds: 500));
                                }

                                if (!mounted) return;

                                if (fullUser != null) {
                                  ref
                                      .read(authNotifierProvider.notifier)
                                      .setUser(fullUser);
                                  if (mounted) {
                                    setState(() => _isAppleLoading = false);
                                  }
                                  return;
                                }

                                // Usuario nuevo — mostrar sheet de registro
                                final authInfo = await ds.getAuthUserInfo();
                                final fullName = authInfo?.displayName ?? '';
                                final parts = fullName.split(' ');

                                setState(() => _isAppleLoading = false);

                                if (!mounted) return;
                                await showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  isDismissible: false,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                  ),
                                  builder: (ctx) => Padding(
                                    padding:
                                        const EdgeInsets.only(top: 8.0),
                                    child: SignUpSheet(
                                      prefilledNombre: parts.isNotEmpty
                                          ? parts.first
                                          : '',
                                      prefilledApellido: parts.length > 1
                                          ? parts.sublist(1).join(' ')
                                          : '',
                                      prefilledEmail:
                                          authInfo?.email ?? '',
                                      isOAuthSignup: true,
                                    ),
                                  ),
                                );
                              } on SignInWithAppleAuthorizationException catch (e) {
                                // El usuario canceló — no mostrar error
                                if (e.code !=
                                    AuthorizationErrorCode.canceled) {
                                  debugPrint('Apple sign in error: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Error con Apple: ${e.message}')),
                                    );
                                  }
                                }
                                if (mounted) {
                                  setState(() => _isAppleLoading = false);
                                }
                              } catch (e) {
                                debugPrint('Apple sign in error: $e');
                                if (mounted) {
                                  setState(() => _isAppleLoading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Error con Apple: $e')),
                                  );
                                }
                              }
                            },
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Small footer / legal
                Text(
                  'Al continuar aceptas los Términos y la Política de Privacidad',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignInSheet extends ConsumerStatefulWidget {
  const SignInSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends ConsumerState<SignInSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static void _showForgotPasswordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _ForgotPasswordSheet(),
      ),
    );
  }

  Future<void> _onSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese email y password')));
      return;
    }

    // Trigger sign-in. AuthStateNotifier updates provider state (loading/data/error).
    await ref.read(authNotifierProvider.notifier).signIn(email, password);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    // Use a Consumer builder to safely call listen/watch inside build
    return Consumer(
      builder: (context, localRef, child) {
        final authState = localRef.watch(authNotifierProvider);

        // Listen for changes to react: close sheet on success, show snack on error
        localRef.listen<AsyncValue<dynamic>>(authNotifierProvider, (previous, next) {
          // close sheet when user data is available
          next.when(
            data: (user) {
              if (user != null) {
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              }
            },
            loading: () {},
            error: (e, st) {
              final msg = e.toString();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            },
          );
        });

        final isLoading = authState.isLoading;

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Inicio de sesión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _onSubmit,
                        child: isLoading
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('Iniciar'),
                              ),
                      ),
                    ),
                    // const SizedBox(height: 8),
                    // // Forgot password link
                    // TextButton(
                    //   onPressed: () {
                    //     Navigator.of(context).pop();
                    //     _showForgotPasswordSheet(context, ref);
                    //   },
                    //   child: const Text('¿Olvidaste tu contraseña?'),
                    // ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class SignUpSheet extends ConsumerStatefulWidget {
  final String? prefilledNombre;
  final String? prefilledApellido;
  final String? prefilledEmail;
  final bool isOAuthSignup;

  const SignUpSheet({
    Key? key,
    this.prefilledNombre,
    this.prefilledApellido,
    this.prefilledEmail,
    this.isOAuthSignup = false,
  }) : super(key: key);

  @override
  ConsumerState<SignUpSheet> createState() => _SignUpSheetState();
}

class _SignUpSheetState extends ConsumerState<SignUpSheet> {
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codigoInvController = TextEditingController();
  bool _esCreador = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill controllers if data is provided from OAuth
    if (widget.prefilledNombre != null) {
      _nombreController.text = widget.prefilledNombre!;
    }
    if (widget.prefilledApellido != null) {
      _apellidoController.text = widget.prefilledApellido!;
    }
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    _codigoInvController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();
    final email = _emailController.text.trim();
    final telefono = _telefonoController.text.trim();
    final password = _passwordController.text;
    final codigoInv = _codigoInvController.text.trim();

    // Validación básica
    if (nombre.isEmpty || apellido.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete nombre, apellido y correo')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    // Si no es OAuth, validar contraseña
    if (!widget.isOAuthSignup && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña es requerida')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final nombreUsuario = '$nombre $apellido'.trim();
    final ds = ref.read(authRepositoryProvider);

    try {
      if (widget.isOAuthSignup) {
        // Usuario viene de OAuth (Google/Facebook), ya está autenticado.
        // Solo necesitamos crear el registro en la tabla usuario.
        final isAuth = await ds.isAuthenticated();
        if (isAuth) {
          try {
            await ds.insertUser(nombreUsuario, email, _esCreador);
          } catch (insertErr) {
            debugPrint('SignUpSheet -> insert error (may already exist): $insertErr');
          }

          // getCurrentUser ya carga auth + perfil en un solo paso
          final userModel = await ds.getCurrentUser();
          if (userModel != null) {
            ref.read(authNotifierProvider.notifier).setUser(userModel);

            // No navegamos manualmente a HomePage: AuthGate ya está
            // observando authNotifierProvider y cambia solo a HomePage en
            // cuanto setUser(...) actualiza el estado. Si en vez de esto
            // reemplazábamos toda la pila con un HomePage() suelto, AuthGate
            // quedaba fuera de la pila de navegación — y entonces cerrar
            // sesión o eliminar la cuenta después ya no tenía nada que
            // redirigiera a Login (HomePage solo se ponía en blanco).
            if (mounted) {
              Navigator.of(context).pop();
            }
          } else {
            // El insert falló (por ejemplo, el correo ya está tomado por
            // otra cuenta) y por eso tampoco hay perfil que cargar. Antes
            // esto se quedaba en silencio y parecía que "Continuar" no
            // hacía nada — ahora avisamos con un mensaje claro.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No se pudo completar el registro. Es posible que ya '
                    'exista una cuenta con este correo — intenta iniciar '
                    'sesión en su lugar, o contacta a soporte.',
                  ),
                ),
              );
            }
          }
        }
      } else {
        // Registro tradicional con email y contraseña
        final user = await ds.signUpWithEmail(
          email: email,
          password: password,
          nombreUsuario: nombreUsuario,
          esCreador: _esCreador,
        );

        if (user != null) {
          try {
            ds.updateUser(telefono, codigoInv);
          } catch (_) {}

          // Auto-login so user enters the app immediately
          await ref.read(authNotifierProvider.notifier).signIn(email, password);
        } else {
          // If sign-up requires email confirmation, try login anyway
          await ref.read(authNotifierProvider.notifier).signIn(email, password);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en registro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Consumer(builder: (context, localRef, child) {

      final bottom = MediaQuery.of(context).viewInsets.bottom;

      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Registro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    // Apple/Google casi nunca comparten el nombre completo
                    // (Apple solo la primerísima vez, y a veces ni eso), así
                    // que el valor "prefilled" suele llegar como '' y no
                    // como null. Si tratamos '' como "ya tiene un valor" el
                    // campo queda bloqueado y vacío a la vez. Por eso
                    // comprobamos también isEmpty, no solo == null.
                    enabled: !widget.isOAuthSignup ||
                        widget.prefilledNombre == null ||
                        widget.prefilledNombre!.isEmpty,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _apellidoController,
                    decoration: const InputDecoration(labelText: 'Apellido'),
                    enabled: !widget.isOAuthSignup ||
                        widget.prefilledApellido == null ||
                        widget.prefilledApellido!.isEmpty,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    enabled: !widget.isOAuthSignup ||
                        widget.prefilledEmail == null ||
                        widget.prefilledEmail!.isEmpty,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                  ),
                  // Solo mostrar contraseña si NO es OAuth signup
                  if (!widget.isOAuthSignup) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codigoInvController,
                    decoration: const InputDecoration(labelText: 'Código de invitación (opcional)'),
                  ),
                  // const SizedBox(height: 10),
                  // SwitchListTile(
                  //   value: _esCreador,
                  //   onChanged: (v) => setState(() => _esCreador = v),
                  //   title: const Text('Soy creador de contenido'),
                  // ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _onSubmit,
                      child: _isSubmitting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Continuar'),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    });
  }
}

/// Bottom sheet para recuperar contraseña
class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  const _ForgotPasswordSheet();

  @override
  ConsumerState<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;

    final email = _emailController.text.trim();

    // Validación
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo electrónico')),
      );
      return;
    }

    // Validación básica de email
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo válido')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authNotifierProvider.notifier).resetPassword(email);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se ha enviado un email de recuperación. Revisa tu correo.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            '¿Olvidaste tu contraseña?',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Email field
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          ElevatedButton(
            onPressed: _isSubmitting ? null : _onSubmit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enviar enlace de recuperación'),
          ),
          const SizedBox(height: 12),

          // Cancel button
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
