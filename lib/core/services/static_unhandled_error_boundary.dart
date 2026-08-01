import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef StaticUnhandledErrorEventReporter = void Function(String eventName);
typedef ProcessFailureMarker = void Function();

final class StaticUnhandledErrorBoundary {
  const StaticUnhandledErrorBoundary({
    this.reportStaticEvent = _reportStaticEvent,
    this.markProcessFailure = _markProcessFailure,
  });

  final StaticUnhandledErrorEventReporter reportStaticEvent;
  final ProcessFailureMarker markProcessFailure;

  void install() {
    FlutterError.onError = handleFlutterError;
    PlatformDispatcher.instance.onError = handlePlatformError;
  }

  void handleFlutterError(FlutterErrorDetails _) {
    markProcessFailure();
    reportStaticEvent('flutter_framework_unhandled');
  }

  bool handlePlatformError(Object _, StackTrace __) {
    markProcessFailure();
    reportStaticEvent('platform_dispatcher_unhandled');
    return true;
  }

  void handleZoneError(Object _, StackTrace __) {
    markProcessFailure();
    reportStaticEvent('zone_unhandled');
  }
}

void _reportStaticEvent(String eventName) {
  developer.log(
    eventName,
    name: 'Kelivo.StaticUnhandledErrorBoundary',
    level: 1000,
  );
}

void _markProcessFailure() {
  exitCode = 1;
}
