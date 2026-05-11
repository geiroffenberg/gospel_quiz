import 'package:flutter/material.dart';

/// Ads disabled: simple placeholder to avoid platform view issues.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key, this.fallbackHeight = 58});

  final double fallbackHeight;

  @override
  Widget build(BuildContext context) => SizedBox(height: fallbackHeight);
}
