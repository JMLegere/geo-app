import 'package:meta/meta.dart';

@immutable
sealed class EngineInput {
  const EngineInput();
}

final class PositionUpdate extends EngineInput {
  final double lat;
  final double lon;
  final double accuracy;
  const PositionUpdate(this.lat, this.lon, this.accuracy);
}

final class CellTapped extends EngineInput {
  final String cellId;
  const CellTapped(this.cellId);
}

final class AuthChanged extends EngineInput {
  final String? userId;
  const AuthChanged(this.userId);
}

final class AppBackgrounded extends EngineInput {
  const AppBackgrounded();
}

final class AppResumed extends EngineInput {
  const AppResumed();
}
