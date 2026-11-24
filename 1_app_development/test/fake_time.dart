import 'package:todays_bungeoppang/time_service.dart';

/// A clock the tests move by hand (moved from controller_test.dart, 32번).
class FakeTime implements TimeService {
  DateTime now = DateTime.utc(2026);
  int mono = 0;
  @override
  DateTime get utcNow => now;
  @override
  int get monotonicMilliseconds => mono;
  void advance(int ms) {
    mono += ms;
    now = now.add(Duration(milliseconds: ms));
  }
}
