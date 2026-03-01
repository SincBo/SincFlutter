import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Página de demostración del tema
/// Muestra todos los colores, gradientes y componentes estilizados
class ThemeDemoPage extends StatelessWidget {
  const ThemeDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo del Tema Sincbo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Colores principales
          _SectionTitle('Colores Principales'),
          _ColorRow('Primary', AppColors.primary),
          _ColorRow('Primary Light', AppColors.primaryLight),
          _ColorRow('Primary Dark', AppColors.primaryDark),
          const Divider(height: 32),

          // Colores secundarios
          _SectionTitle('Colores Secundarios'),
          _ColorRow('Secondary', AppColors.secondary),
          _ColorRow('Secondary Light', AppColors.secondaryLight),
          _ColorRow('Secondary Dark', AppColors.secondaryDark),
          const Divider(height: 32),

          // Colores de acento
          _SectionTitle('Colores de Acento'),
          _ColorRow('Accent', AppColors.accent),
          _ColorRow('Accent Light', AppColors.accentLight),
          _ColorRow('Accent Dark', AppColors.accentDark),
          const Divider(height: 32),

          // Colores de estado
          _SectionTitle('Colores de Estado'),
          _ColorRow('Success', AppColors.success),
          _ColorRow('Warning', AppColors.warning),
          _ColorRow('Error', AppColors.error),
          _ColorRow('Info', AppColors.info),
          const Divider(height: 32),

          // Gradientes
          _SectionTitle('Gradientes'),
          _GradientCard('Primary Gradient', AppColors.primaryGradient),
          const SizedBox(height: 12),
          _GradientCard('Secondary Gradient', AppColors.secondaryGradient),
          const SizedBox(height: 12),
          _GradientCard('Accent Gradient', AppColors.accentGradient),
          const SizedBox(height: 12),
          _GradientCard('Rainbow Gradient', AppColors.rainbowGradient),
          const Divider(height: 32),

          // Botones
          _SectionTitle('Botones'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Elevated Button'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Outlined Button'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {},
            child: const Text('Text Button'),
          ),
          const Divider(height: 32),

          // Cards con diferentes estilos
          _SectionTitle('Cards con Gradientes'),
          const SizedBox(height: 12),
          _CreatorCard(
            name: 'Plan Comunidad',
            gradient: AppColors.primaryGradient,
            price: '4.99 bs',
          ),
          const SizedBox(height: 12),
          _CreatorCard(
            name: 'Plan Fellow',
            gradient: AppColors.secondaryGradient,
            price: '9.99 bs',
          ),
          const SizedBox(height: 12),
          _CreatorCard(
            name: 'Plan Premium',
            gradient: AppColors.rainbowGradient,
            price: '19.99 bs',
          ),
          const Divider(height: 32),

          // Estilos de texto
          _SectionTitle('Estilos de Texto'),
          Text('Display Large', style: theme.textTheme.displayLarge),
          Text('Display Medium', style: theme.textTheme.displayMedium),
          Text('Display Small', style: theme.textTheme.displaySmall),
          Text('Headline Large', style: theme.textTheme.headlineLarge),
          Text('Headline Medium', style: theme.textTheme.headlineMedium),
          Text('Headline Small', style: theme.textTheme.headlineSmall),
          Text('Title Large', style: theme.textTheme.titleLarge),
          Text('Title Medium', style: theme.textTheme.titleMedium),
          Text('Title Small', style: theme.textTheme.titleSmall),
          Text('Body Large', style: theme.textTheme.bodyLarge),
          Text('Body Medium', style: theme.textTheme.bodyMedium),
          Text('Body Small', style: theme.textTheme.bodySmall),
          Text('Label Large', style: theme.textTheme.labelLarge),
          Text('Label Medium', style: theme.textTheme.labelMedium),
          Text('Label Small', style: theme.textTheme.labelSmall),
          const Divider(height: 32),

          // Inputs
          _SectionTitle('Inputs'),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'correo@ejemplo.com',
              prefixIcon: Icon(Icons.email),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'Contraseña',
              hintText: '********',
              prefixIcon: Icon(Icons.lock),
              suffixIcon: Icon(Icons.visibility),
            ),
            obscureText: true,
          ),
          const Divider(height: 32),

          // Badges y chips
          _SectionTitle('Badges y Chips'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge('Nuevo', AppColors.accent),
              _Badge('Popular', AppColors.primary),
              _Badge('Promoción', AppColors.secondary),
              _Badge('Destacado', AppColors.warning),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String name;
  final Color color;

  const _ColorRow(this.name, this.color);

  @override
  Widget build(BuildContext context) {
    final hexColor = '#${color.a.toInt().toRadixString(16).padLeft(2, '0')}${color.r.toInt().toRadixString(16).padLeft(2, '0')}${color.g.toInt().toRadixString(16).padLeft(2, '0')}${color.b.toInt().toRadixString(16).padLeft(2, '0')}'.substring(2).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  hexColor,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientCard extends StatelessWidget {
  final String name;
  final Gradient gradient;

  const _GradientCard(this.name, this.gradient);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  final String name;
  final Gradient gradient;
  final String price;

  const _CreatorCard({
    required this.name,
    required this.gradient,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              child: const Icon(Icons.star, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              onPressed: () {},
              child: const Text('Suscribirse'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}



