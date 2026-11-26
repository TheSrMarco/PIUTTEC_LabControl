import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/piuttec_theme.dart';
import '../widgets/piuttec_ui.dart';
import 'tablet_dashboard_screen.dart';
import 'loan_wizard_screen.dart';

class LoginShiftScreen extends StatefulWidget {
  const LoginShiftScreen({super.key});

  @override
  State<LoginShiftScreen> createState() {
    return _LoginShiftScreenState();
  }
}

class _LoginShiftScreenState extends State<LoginShiftScreen> {
  final _userCtrl = TextEditingController(text: 'Lab. Gabriel Nájera');
  final _pinCtrl = TextEditingController(text: '1234');
  final _tabletIpCtrl = TextEditingController(text: '192.168.1.50');
  bool _isTabletMode = false;

  void _vincularQrTableta() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SizedBox(
        height: 360,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Escanear QR Temporal de la Tableta', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final val = capture.barcodes.first.rawValue;
                  if (val != null) {
                    setState(() => _tabletIpCtrl.text = val);
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 720;
    if (isWide && !_isTabletMode) _isTabletMode = true;

    return Scaffold(
      body: Column(
        children: [
          const PiuttecHeader(subtitulo: 'Autenticación de Turno y Vinculación'),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionBanner(
                            paso: '01',
                            titulo: 'Inicio de Turno Operativo',
                            icon: Icons.verified_user_outlined,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _userCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Cuenta de Laboratorista',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pinCtrl,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'PIN de seguridad por inactividad',
                              prefixIcon: Icon(Icons.pin_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: PiuttecTheme.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SwitchListTile(
                              title: const Text('Estación Tableta (Base SQLite)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: const Text('Habilita panel de control y recepción local', style: TextStyle(fontSize: 12)),
                              value: _isTabletMode,
                              onChanged: (v) => setState(() => _isTabletMode = v),
                            ),
                          ),
                          if (!_isTabletMode) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _tabletIpCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'IP / Vínculo con Tableta',
                                      prefixIcon: Icon(Icons.wifi_tethering),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: PiuttecTheme.primaryDark),
                                  onPressed: _vincularQrTableta,
                                  tooltip: 'Vincular por QR temporal',
                                  icon: const Icon(Icons.qr_code_scanner),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(_isTabletMode ? 'Entrar al Panel Principal' : 'Iniciar Turno en Celular'),
                            onPressed: () {
                              if (_isTabletMode) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TabletDashboardScreen(laboratorista: _userCtrl.text),
                                  ),
                                );
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoanWizardScreen(
                                      laboratorista: _userCtrl.text,
                                      tabletIp: _tabletIpCtrl.text,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}