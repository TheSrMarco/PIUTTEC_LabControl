import 'package:flutter/material.dart';

import 'presentation/operational_summary.dart';
import '../auth/data/auth_store.dart';
import '../auth/presentation/users_page.dart';
import '../auth/presentation/change_password_page.dart';
import '../backups/presentation/backups_page.dart';
import '../history/presentation/history_page.dart';
import '../inventory/presentation/inventory_page.dart';
import '../loans/presentation/loans_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AuthState session;
  final Future<void> Function() onLogout;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _summaryKey = GlobalKey<OperationalSummaryState>();
  bool _isLoggingOut = false;

  Future<void> _openModule(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) {
      _summaryKey.currentState?.refresh();
    }
  }

  Future<void> _refreshDashboard() async {
    _summaryKey.currentState?.refresh();
  }

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Deseas salir de tu sesión actual en este dispositivo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  ThemeData _buildLabTheme() {
    const seed = Color(0xFF1B6B4A); // Verde institucional PIUTTEC
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F8F7),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8E5)),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDFE6E2)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.session.role!;
    final username = widget.session.username ?? 'Usuario';
    final theme = _buildLabTheme();
    final colorScheme = theme.colorScheme;

    final modules = <_DashboardModule>[
      _DashboardModule(
        icon: Icons.inventory_2_outlined,
        title: 'Inventario',
        subtitle: role.canManageInventory
            ? 'Registro y consulta de equipos'
            : 'Consulta de equipos',
        accent: const Color(0xFF1B6B4A),
        page: InventoryPage(canEdit: role.canManageInventory),
      ),
      _DashboardModule(
        icon: Icons.swap_horiz_rounded,
        title: 'Préstamos',
        subtitle: role.canOperateLoans
            ? 'Entregas y devoluciones'
            : 'Consulta de folios',
        accent: const Color(0xFF0E7490),
        page: LoansPage(canOperate: role.canOperateLoans),
      ),
      const _DashboardModule(
        icon: Icons.history_rounded,
        title: 'Historial',
        subtitle: 'Bitácora de préstamos y entregas',
        accent: Color(0xFF6D28D9),
        page: HistoryPage(),
      ),
      if (role.canManageUsers) ...[
        const _DashboardModule(
          icon: Icons.cloud_sync_outlined,
          title: 'Respaldos',
          subtitle: 'Copias y recuperación local',
          accent: Color(0xFFB45309),
          page: BackupsPage(),
        ),
        const _DashboardModule(
          icon: Icons.manage_accounts_outlined,
          title: 'Usuarios',
          subtitle: 'Cuentas y roles del sistema',
          accent: Color(0xFFBE185D),
          page: UsersPage(),
        ),
      ],
    ];

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.science_outlined,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'PIUTTEC LabControl',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.password_outlined),
              tooltip: 'Cambiar contraseña',
              onPressed: () => _openModule(const ChangePasswordPage()),
            ),
            IconButton(
              icon: _isLoggingOut
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.logout_rounded),
              tooltip: 'Cerrar sesión',
              onPressed: _isLoggingOut ? null : _confirmLogout,
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshDashboard,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    _HeaderCard(
                      username: username,
                      roleLabel: role.label,
                    ),
                    const SizedBox(height: 22),
                    OperationalSummary(key: _summaryKey),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Text(
                          'Módulos operativos',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${modules.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width >= 820
                            ? 3
                            : width >= 540
                            ? 2
                            : 1;
                        const spacing = 12.0;
                        final tileWidth =
                            (width - spacing * (columns - 1)) / columns;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (final module in modules)
                              SizedBox(
                                width: tileWidth,
                                child: _ModuleCard(
                                  module: module,
                                  onTap: () => _openModule(module.page),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.username,
    required this.roleLabel,
  });

  final String username;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF5F0), Color(0xFFFFFFFF)],
        ),
        border: Border.all(color: const Color(0xFFD0E4DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/branding/labcontrol-wordmark.png',
            height: 26,
            fit: BoxFit.contain,
            semanticLabel: 'Logo de PIUTTEC LabControl',
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Text(
            'Panel del laboratorio',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$username · $roleLabel',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Almacenamiento local activo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardModule {
  const _DashboardModule({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget page;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.onTap,
  });

  final _DashboardModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: module.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  module.icon,
                  size: 23,
                  color: module.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      module.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}