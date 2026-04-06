import 'package:flutter/material.dart';
import 'package:earth_nova/core/domain/entities/iucn_status.dart';

extension IucnStatusTheme on IucnStatus {
  Color get color => switch (this) {
        IucnStatus.leastConcern => const Color(0xFFCDD5DB),
        IucnStatus.nearThreatened => const Color(0xFF4CAF50),
        IucnStatus.vulnerable => const Color(0xFF2196F3),
        IucnStatus.endangered => const Color(0xFFFFD700),
        IucnStatus.criticallyEndangered => const Color(0xFF9C27B0),
        IucnStatus.extinct => const Color(0xFF757575),
      };

  Color get fgColor => switch (this) {
        IucnStatus.leastConcern => const Color(0xFF1A1A2E),
        IucnStatus.endangered => const Color(0xFF1A1A2E),
        _ => Colors.white,
      };

  double get borderAlpha => switch (this) {
        IucnStatus.leastConcern => 0.15,
        IucnStatus.nearThreatened => 0.50,
        IucnStatus.vulnerable => 0.65,
        IucnStatus.endangered => 0.85,
        IucnStatus.criticallyEndangered => 0.90,
        IucnStatus.extinct => 0.40,
      };

  double get glowAlpha => switch (this) {
        IucnStatus.leastConcern => 0.0,
        IucnStatus.nearThreatened => 0.0,
        IucnStatus.vulnerable => 0.15,
        IucnStatus.endangered => 0.25,
        IucnStatus.criticallyEndangered => 0.35,
        IucnStatus.extinct => 0.0,
      };
}
