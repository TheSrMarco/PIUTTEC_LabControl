import 'package:flutter/material.dart';
import '../theme/piuttec_theme.dart';

class PiuttecHeader extends StatelessWidget {
  final String subtitulo;
  final Widget? trailing;

  const PiuttecHeader({
    super.key,
    required this.subtitulo,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: PiuttecTheme.primaryDark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'π',
                style: TextStyle(
                  color: PiuttecTheme.primaryDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PIUTTEC LabControl',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      color: Color(0xFFB7E4D8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SectionBanner extends StatelessWidget {
  final String paso;
  final String titulo;
  final IconData icon;

  const SectionBanner({
    super.key,
    required this.paso,
    required this.titulo,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PiuttecTheme.accentMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PiuttecTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: PiuttecTheme.primaryDark,
            child: Text(
              paso,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: PiuttecTheme.primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Icon(icon, color: PiuttecTheme.primaryGreen, size: 20),
        ],
      ),
    );
  }
}