import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import '../../../data/models/ganancias_mes_model.dart';
import '../../../data/models/top_pago_mes_model.dart';
import '../profile/profile_page.dart';

class GananciasPage extends ConsumerWidget {
  final String? creadorId;
  final int? year;
  final int? month;
  const GananciasPage({Key? key, this.creadorId, this.year, this.month}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final now = DateTime.now();
    final int resolvedYear = year ?? now.year;
    final int resolvedMonth = month ?? now.month;

    // Resolve creatorId: prefer provided, else try current auth user id
    String? resolvedCreatorId = creadorId;
    if (resolvedCreatorId == null || resolvedCreatorId.isEmpty) {
      final authUser = ref.read(authNotifierProvider).maybeWhen(data: (u) => u, orElse: () => null);
      resolvedCreatorId = authUser?.id;
    }

    // If we still have no creator id, show an informative message
    if (resolvedCreatorId == null || resolvedCreatorId.isEmpty) {
      return const SafeArea(child: Center(child: Text('No se pudo determinar el creador para cargar ganancias')));
    }

    final ds = ref.read(supabaseDataSourceProvider);
    // Load both: ganancias and top pagos
    final future = Future.wait<List<dynamic>>([
      ds.obtenerGananciasCreadorMesModel(creadorId: resolvedCreatorId, year: resolvedYear, month: resolvedMonth),
      ds.obtenerTopPagosCreadorMes(creadorId: resolvedCreatorId, year: resolvedYear, month: resolvedMonth, limit: 10),
    ]);

    return FutureBuilder<List<List<dynamic>>>(
      future: future,
      builder: (context, snap) {
        // Defaults
        String mesLabel = 'Total';
        double totalBruto = 0;
        double balanceTotal = 0;
        double feeMonto = 0;
        int suscriptoresComunidad = 0;
        double comunidadMonto = 0;
        double tipsMonto = 0;
        double fellowsMonto = 0;
        double contenidoMonto = 0;
        const double foundersFeeRate = 0.10;
        List<TopPagoMesModel> topPagos = const [];

        if (snap.hasData && snap.data!.isNotEmpty) {
          final gananciasList = (snap.data![0] as List<GananciasMesModel>);
          final topList = (snap.data![1] as List<TopPagoMesModel>);

          if (gananciasList.isNotEmpty) {
            final g = gananciasList.first;
            mesLabel = _monthName(g.mes);
            totalBruto = g.totalBruto;
            balanceTotal = g.balance;
            feeMonto = g.fee > 0 ? g.fee : totalBruto * foundersFeeRate;
            suscriptoresComunidad = g.comunidadSuscriptores;
            comunidadMonto = g.comunidadMonto;
            tipsMonto = g.tipsMonto;
            fellowsMonto = g.fellowMonto;
            contenidoMonto = g.contenidoSolicitadoMonto;
          }

          topPagos = topList;
        }


        if (snap.connectionState == ConnectionState.waiting) {
          return const SafeArea(child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return SafeArea(child: Center(child: Text('Error cargando datos: ${snap.error}')));
        }

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: _HeaderDelegate(
                    minExtent: 80,
                    maxExtent: 80,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ganancias', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'logout') {
                              // Sign out via the auth notifier
                              ref.read(authNotifierProvider.notifier).signOut();
                            } else if (value == 'perfil') {
                              // Navigate to ProfilePage
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ProfilePage()),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'perfil', child: Text('Perfil')),
                            const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
                          ],
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                              ),
                              const SizedBox(height: 6),
                              const Text('Perfil', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Circular balance card
              SliverToBoxAdapter(
                child: Center(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.colorScheme.primary, width: 10),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(mesLabel, style: theme.textTheme.titleMedium?.copyWith(color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text(
                              '${totalBruto.toStringAsFixed(0)} Bs',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const Text('Total recaudado', style: TextStyle(color: Colors.black54, fontSize: 12)),
                            const Divider(height: 16, indent: 30, endIndent: 30),
                            Text(
                              '${balanceTotal.toStringAsFixed(0)} Bs',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text('Neto (después de fee)', style: TextStyle(color: Colors.black54, fontSize: 11)),
                          ],
                        ),
                        Positioned(left: 10, child: Icon(Icons.play_arrow, color: Colors.grey[400], size: 48)),
                        Positioned(right: 10, child: Transform.rotate(angle: 3.1416, child: Icon(Icons.play_arrow, color: Colors.grey[400], size: 48))),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Breakdown title and subtitle
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text('Por suscripción a la comunidad', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text('($suscriptoresComunidad suscriptores)', style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),

              // Breakdown rows
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _BreakdownRow(label: 'Comunidad', monto: comunidadMonto),
                    _BreakdownRow(label: 'Tips', monto: tipsMonto),
                    _BreakdownRow(label: 'Fellows', monto: fellowsMonto),
                    _BreakdownRow(label: 'Contenido solicitado', monto: contenidoMonto),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total recaudado', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text('${totalBruto.toStringAsFixed(0)} Bs', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Tasa de servicio SINC', style: theme.textTheme.bodyMedium),
                    Text('Founders Fee ${(foundersFeeRate * 100).toStringAsFixed(0)}% mas 1bs por transacción', style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('- ${feeMonto.toStringAsFixed(2)} Bs', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.redAccent))]),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Neto (balance)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('${balanceTotal.toStringAsFixed(0)} Bs', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Top mejores pagas', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),

              // Top list (live)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = topPagos[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 24, backgroundColor: Colors.grey[300], child: const Icon(Icons.image, color: Colors.grey)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.nombreUsuario, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  const Text(''),
                                ],
                              ),
                            ),
                            Text('${item.totalPagado.toStringAsFixed(0)}Bs', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    },
                    childCount: topPagos.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }

  String _monthName(int m) {
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    if (m >= 1 && m <= 12) return months[m];
    return 'Total';
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtent;
  final double maxExtent;
  final Widget child;
  _HeaderDelegate({required this.minExtent, required this.maxExtent, required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.only(top: 8.0),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) {
    return oldDelegate.minExtent != minExtent || oldDelegate.maxExtent != maxExtent || oldDelegate.child != child;
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double monto;
  const _BreakdownRow({Key? key, required this.label, required this.monto}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text('${monto.toStringAsFixed(0)} Bs', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
