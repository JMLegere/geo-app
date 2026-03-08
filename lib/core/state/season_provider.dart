import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/models/season.dart';

class SeasonNotifier extends Notifier<Season> {
  @override
  Season build() {
    return Season.fromDate(DateTime.now());
  }

  void setSeason(Season season) {
    state = season;
  }

  void toggleSeason() {
    state = state.opposite;
  }
}

final seasonProvider =
    NotifierProvider<SeasonNotifier, Season>(() => SeasonNotifier());
