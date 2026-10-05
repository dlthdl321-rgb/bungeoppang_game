abstract class TimeService {
  DateTime get utcNow;
  int get monotonicMilliseconds;
}

class SystemTimeService implements TimeService {
  final Stopwatch _watch = Stopwatch()..start();
  @override
  DateTime get utcNow => DateTime.now().toUtc();
  @override
  int get monotonicMilliseconds => _watch.elapsedMilliseconds;
}
