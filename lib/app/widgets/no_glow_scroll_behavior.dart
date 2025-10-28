import 'package:flutter/material.dart';

/// Menghilangkan efek 'glow' (overscroll indicator) pada semua widget scroll.
class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Dengan me-return 'child' secara langsung, kita tidak membungkusnya
    // dengan widget indikator overscroll bawaan.
    return child;
  }
}
