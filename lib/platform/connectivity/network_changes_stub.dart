/// No network signal on this platform: the resume wake and the stall
/// watchdog remain.
Stream<Object?> platformNetworkChanges() => const Stream.empty();
