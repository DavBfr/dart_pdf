import 'dart:async';

/// A utility class for maintaining event loop responsiveness during
/// long-running work.
///
/// [EventLoopBalancer] monitors elapsed time during execution and yields
/// control to the event loop when a configurable time threshold is exceeded.
/// This helps ensure that the main isolate remains responsive by allowing
/// other scheduled asynchronous events to execute.
class EventLoopBalancer {
  /// Creates an instance of [EventLoopBalancer].
  EventLoopBalancer() : _stopwatch = Stopwatch();

  final Stopwatch _stopwatch;

  /// Begins tracking elapsed execution time.
  ///
  /// Should be called before starting a workload that may require periodic
  /// yielding.
  void start() {
    _stopwatch.start();
  }

  /// Yields control to the event loop if the elapsed time exceeds a fixed
  /// threshold.
  ///
  /// If more than 4 milliseconds have passed since the last yield,
  /// this method awaits a short asynchronous delay of 1 millisecond and resets
  /// the internal timer. This allows pending asynchronous events to execute.
  Future<void> yieldIfNeeded() async {
    if (_stopwatch.elapsedMilliseconds >= 4) {
      await Future.delayed(const Duration(milliseconds: 1));
      _stopwatch.reset();
    }
  }

  /// Stops tracking elapsed execution time.
  ///
  /// Should be called when the workload is complete.
  void stop() {
    _stopwatch.stop();
  }
}
