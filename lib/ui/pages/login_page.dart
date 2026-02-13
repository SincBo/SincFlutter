import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isGoogleLoading = false;
  bool _isFacebookLoading = false;

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
                          : const Icon(Icons.g_translate, color: Colors.red),
                        label: Text(_isGoogleLoading ? 'Cargando...' : 'Google'),
                        onPressed: _isGoogleLoading ? null : () async {
                          setState(() => _isGoogleLoading = true);

                          try {
                            final ds = ref.read(supabaseDataSourceProvider);

                            debugPrint('LoginPage -> Starting Google sign in');

                            // Try to sign in with Google
                            final user = await ds.signInWithGoogle();

                            debugPrint('LoginPage -> Google sign in result: ${user?.id}');

                            if (user == null) {
                              if (mounted) {
                                setState(() => _isGoogleLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No se pudo iniciar sesión con Google')),
                                );
                              }
                              return;
                            }

                            // Check if user profile exists in our usuario table
                            final existing = await ds.client
                                .from('usuario')
                                .select('id_usuario')
                                .eq('id_usuario', user.id)
                                .maybeSingle();

                            debugPrint('LoginPage -> User exists in table: ${existing != null}');

                            if (existing == null && mounted) {
                              // New user - show registration sheet with prefilled data
                              setState(() => _isGoogleLoading = false);

                              final authUser = ds.client.auth.currentUser;
                              if (authUser != null) {
                                final fullName = authUser.userMetadata?['full_name'] ??
                                                 authUser.userMetadata?['name'] ?? '';
                                final nameParts = fullName.toString().split(' ');
                                final nombre = nameParts.isNotEmpty ? nameParts.first : '';
                                final apellido = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

                                _showSignUpSheet(
                                  context,
                                  prefilledNombre: nombre,
                                  prefilledApellido: apellido,
                                  prefilledEmail: authUser.email ?? '',
                                  isOAuthSignup: true,
                                );
                              }
                            } else {
                              // Existing user - update auth state
                              debugPrint('LoginPage -> Updating auth state for existing user');
                              await ref.read(authNotifierProvider.notifier).signInWithGoogle();
                              if (mounted) setState(() => _isGoogleLoading = false);
                            }
                          } catch (e) {
                            debugPrint('LoginPage -> Google sign in error: $e');
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
                    const SizedBox(width: 12),

                    // Facebook
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _isFacebookLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.facebook),
                        label: Text(_isFacebookLoading ? 'Cargando...' : 'Facebook'),
                        onPressed: _isFacebookLoading ? null : () async {
                          setState(() => _isFacebookLoading = true);

                          try {
                            final ds = ref.read(supabaseDataSourceProvider);

                            debugPrint('LoginPage -> Starting Facebook sign in');

                            // Try to sign in with Facebook
                            final user = await ds.signInWithFacebook();

                            debugPrint('LoginPage -> Facebook sign in result: ${user?.id}');

                            if (user == null) {
                              if (mounted) {
                                setState(() => _isFacebookLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No se pudo iniciar sesión con Facebook')),
                                );
                              }
                              return;
                            }

                            // Check if user profile exists in our usuario table
                            final existing = await ds.client
                                .from('usuario')
                                .select('id_usuario')
                                .eq('id_usuario', user.id)
                                .maybeSingle();

                            debugPrint('LoginPage -> User exists in table: ${existing != null}');

                            if (existing == null && mounted) {
                              // New user - show registration sheet with prefilled data
                              setState(() => _isFacebookLoading = false);

                              final authUser = ds.client.auth.currentUser;
                              if (authUser != null) {
                                final fullName = authUser.userMetadata?['full_name'] ??
                                                 authUser.userMetadata?['name'] ?? '';
                                final nameParts = fullName.toString().split(' ');
                                final nombre = nameParts.isNotEmpty ? nameParts.first : '';
                                final apellido = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

                                _showSignUpSheet(
                                  context,
                                  prefilledNombre: nombre,
                                  prefilledApellido: apellido,
                                  prefilledEmail: authUser.email ?? '',
                                  isOAuthSignup: true,
                                );
                              }
                            } else {
                              // Existing user - update auth state
                              debugPrint('LoginPage -> Updating auth state for existing user');
                              await ref.read(authNotifierProvider.notifier).signInWithFacebook();
                              if (mounted) setState(() => _isFacebookLoading = false);
                            }
                          } catch (e) {
                            debugPrint('LoginPage -> Facebook sign in error: $e');
                            if (mounted) {
                              setState(() => _isFacebookLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error con Facebook: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
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
    final ds = ref.read(supabaseDataSourceProvider);

    try {
      if (widget.isOAuthSignup) {
        // Usuario viene de OAuth (Google/Facebook), ya está autenticado
        // Solo necesitamos crear el registro en la tabla usuario
        final user = ds.client.auth.currentUser;
        if (user != null) {
          await ds.client.from('usuario').insert({
            'id_usuario': user.id,
            'nombre_usuario': nombreUsuario,
            'email': email,
            // 'telefono': telefono.isNotEmpty ? telefono : null,
            // 'codigo_inv': codigoInv.isNotEmpty ? codigoInv : null,
            'es_creador': _esCreador,
          });

          // Refresh auth state to load the new user profile
          await ref.read(authNotifierProvider.notifier).signInWithGoogle();
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
            await ds.client.from('usuario').update({
              'telefono': telefono.isNotEmpty ? telefono : null,
              'codigo_inv': codigoInv.isNotEmpty ? codigoInv : null,
            }).eq('id_usuario', user.id);
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
      // Close sheet on successful auth (like SignInSheet)
      localRef.listen<AsyncValue<dynamic>>(authNotifierProvider, (previous, next) {
        next.when(
          data: (user) {
            if (user != null) {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            }
          },
          loading: () {},
          error: (e, st) {
            // Show error only if currently submitting to avoid noise
            if (_isSubmitting) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de inicio tras registro: $e')));
            }
          },
        );
      });

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
                    enabled: !widget.isOAuthSignup || widget.prefilledNombre == null,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _apellidoController,
                    decoration: const InputDecoration(labelText: 'Apellido'),
                    enabled: !widget.isOAuthSignup || widget.prefilledApellido == null,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    enabled: !widget.isOAuthSignup || widget.prefilledEmail == null,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefono'),
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
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _esCreador,
                    onChanged: (v) => setState(() => _esCreador = v),
                    title: const Text('Soy creador de contenido'),
                  ),
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
