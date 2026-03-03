import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/season.dart';

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
