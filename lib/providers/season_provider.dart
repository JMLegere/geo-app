import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/season.dart';

/// Current game season derived from today's date.
///
/// Stateless — computed each time the provider is read.
/// Summer: May–Oct. Winter: Nov–Apr.
final seasonProvider = Provider<Season>((ref) {
  return Season.fromDate(DateTime.now());
});
