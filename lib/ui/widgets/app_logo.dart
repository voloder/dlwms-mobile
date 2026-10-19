import 'package:flutter/material.dart';

/// The app mark (graduation cap with an amber "notification" tassel) on a
/// rounded tile in the current accent colour. Used on the login and loading
/// screens; the launcher icon is generated from the same artwork
/// (assets/icon/).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.25),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(scheme.primary, Colors.white, 0.12)!,
            Color.lerp(scheme.primary, Colors.black, 0.35)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.06),
        child: Image.asset(
          'assets/icon/mark.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
