import 'package:earth_nova/features/map/domain/entities/camera_follow_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _DerivedCameraFollowState extends CameraFollowState {
  const _DerivedCameraFollowState({
    required super.lat,
    required super.lng,
    required super.hasFix,
    required super.gapDistance,
  });
}

void main() {
  group('CameraFollowState', () {
    test('noFix is a stable zero-valued state', () {
      const noFix = CameraFollowState.noFix();

      expect(noFix.lat, equals(0.0));
      expect(noFix.lng, equals(0.0));
      expect(noFix.hasFix, isFalse);
      expect(noFix.gapDistance, equals(0.0));
      expect(noFix, equals(const CameraFollowState.noFix()));
      expect(noFix.hashCode, equals(const CameraFollowState.noFix().hashCode));
    });

    test('value equality and hash identity include every tracking field', () {
      const state = CameraFollowState(
        lat: 45.9636,
        lng: -66.6431,
        hasFix: true,
        gapDistance: 12.5,
      );
      const same = CameraFollowState(
        lat: 45.9636,
        lng: -66.6431,
        hasFix: true,
        gapDistance: 12.5,
      );

      expect(state, equals(same));
      expect(state.hashCode, equals(same.hashCode));
      expect(state, equals(state));
      expect(
        state,
        isNot(
          equals(
            const CameraFollowState(
              lat: 45.9636,
              lng: -66.6431,
              hasFix: false,
              gapDistance: 12.5,
            ),
          ),
        ),
      );
      expect(
        state,
        isNot(
          equals(
            const CameraFollowState(
              lat: 45.9637,
              lng: -66.6431,
              hasFix: true,
              gapDistance: 12.5,
            ),
          ),
        ),
      );
      expect(
        state,
        isNot(
          equals(
            const CameraFollowState(
              lat: 45.9636,
              lng: -66.6431,
              hasFix: true,
              gapDistance: 12.6,
            ),
          ),
        ),
      );
    });

    test('does not equate a subclass with the same coordinate values', () {
      const state = CameraFollowState(
        lat: 45.9636,
        lng: -66.6431,
        hasFix: true,
        gapDistance: 12.5,
      );
      const derived = _DerivedCameraFollowState(
        lat: 45.9636,
        lng: -66.6431,
        hasFix: true,
        gapDistance: 12.5,
      );

      expect(state, isNot(equals(derived)));
    });
  });
}
