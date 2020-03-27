import 'dart:async';

import 'package:flutter/services.dart';

const initMethod = "init";
const connectToNearestBreathalyzerMethod = "connectToNearestBreathalyzer";
const connectToNearestBreathalyzerWithTimeoutMethod = "connectToNearestBreathalyzerWithTimeout";
const disconnectMethod = "disconnect";
const startScanMethod = "startScan";
const stopScanMethod = "stopScan";
const connectToDeviceMethod = "connectToDevice";
const startCountdownMethod = "startCountdown";
const getBreathalyzerBatteryVoltageMethod = "getBreathalyzerBatteryVoltage";

/// There is one corresponding BACtrackState for each of the methods in the BACtrackAPICallbacks
/// object defined in the BACtrack SDK. These states are named the same as the callback methods
/// minus the BACtrack prefix on each.  The only exceptions are:
///
///   BACtrackStart -> startBlowing
///   BACtrackBlow -> keepBlowing
///   BACtrackSerial -> serialNumber
///
/// These have been slightly renamed for additional clarity.
enum BACtrackState {
  apiKeyDeclined,
  apiKeyAuthorized,
  didConnect,
  connected,
  disconnected,
  connectionTimeout,
  foundBreathalyzer,
  countDown,
  startBlowing,
  keepBlowing,
  analyzing,
  results,
  firmwareVersion,
  serialNumber,
  units,
  useCount,
  batteryVoltage,
  batteryLevel,
  error,
}

final Map<String, BACtrackState> methodNameToState = BACtrackState.values.fold({}, (map, state) {
  final name = state.toString().split('.')[1];
  map[name] = state;
  return map;
});

/// BACtrackStatus objects are emitted on the [BACtrackPlugin.statusStream]. Not all
/// states have an associated message. In these cases the [message] string is empty,
/// it will never be null.
///
/// Where states have associated message strings in the [BACtrackStatus] object, these strings
/// are noted below.
///
/// | BACtrackState     | Value of Message String                                     |
/// | ----------------- | ----------------------------------------------------------- |
/// | apiKeyDeclined    | error message                                               |
/// | apiKeyAuthorized  | empty                                                       |
/// | didConnect        | device name                                                 |
/// | connected         | device type                                                 |
/// | disconnected      | empty                                                       |
/// | connectionTimeout | empty                                                       |
/// | foundBreathalyzer | device identifier                                           |
/// | countDown         | current countdown value, the est. time until blow (seconds) |
/// | startBlowing      | empty                                                       |
/// | keepBlowing       | empty                                                       |
/// | analyzing         | empty                                                       |
/// | results           | blood alcohol content, the decimal value as a string        |
/// | firmwareVersion   | firmware version string                                     |
/// | serialNumber      | serial number as hex string                                 |
/// | units             | unit string                                                 |
/// | useCount          | use count as string                                         |
/// | batteryVoltage    | voltage, decimal value as string                            |
/// | batteryLevel      | level, int value as string (0=low, 1=medium, >=2=high)      |
/// | error             | error code, int value as string                             |
///
class BACtrackStatus {
  BACtrackStatus(this.state, {this.message = ''});

  /// The current state of the API or device.  States roughly correspond to method
  /// names of the BACtrack SDK's callback object.  See [BACtrackState] for details.
  final BACtrackState state;

  /// Some states have string messages associated with them.  See the documentation
  /// for the [BACtrackState] enum for details.  This string may be empty but will
  /// never be null.
  final String message;
}

/// This class provides the main interface to the BACtrack Flutter plugin.  It is
/// a singleton so only one instance will ever be created in a Flutter application.
class BACtrackPlugin {
  static const CHANNEL_ID = "com.pleasingsoftware.flutter/bactrack_plugin";
  static const MethodChannel _channel = MethodChannel(CHANNEL_ID);

  static BACtrackPlugin _instance;

  BACtrackStatus currentStatus;
  StreamController<BACtrackStatus> _statusStreamController;

  /// Use this constructor to get a reference to an object that allows you to interact with
  /// a BACtrack device.
  BACtrackPlugin() {
    _statusStreamController = StreamController.broadcast(onListen: _onListen);
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<BACtrackPlugin> instance(String apiKey) async {
    _instance ??= BACtrackPlugin();
    await _channel.invokeMethod(initMethod, apiKey);
    return _instance;
  }

  /// This [Stream] emits [BACtrackStatus] objects to allow the Flutter application
  /// to monitor the state of the BACtrack SDK and device.
  Stream<BACtrackStatus> get statusStream => _statusStreamController.stream;

  /// Connect to the nearest breathalyzer that can be found. The following states can be
  /// emitted on the [statusStream] in response:
  ///   * [BACtrackState.apiKeyAuthorized]
  ///   * [BACtrackState.apiKeyDeclined]
  ///   * [BACtrackState.didConnect]
  ///   * [BACtrackState.connected]
  ///   * [BACtrackState.connectionTimeout].
  Future connectToNearestBreathalyzer({bool withTimeout = false}) async {
    if (withTimeout) {
      await _channel.invokeMethod(connectToNearestBreathalyzerWithTimeoutMethod);
    } else {
      await _channel.invokeMethod(connectToNearestBreathalyzerMethod);
    }
  }

  /// Disconnect from the connected device. The following states can be
  /// emitted on the [statusStream] in response:
  ///   * [BACtrackState.disconnected]
  Future disconnect() async {
    await _channel.invokeMethod(disconnectMethod);
  }

  /// The dispose method should always be called when the application is done
  /// using this plugin so it has the chance to clean up its resources.
  void dispose() {
    _channel.setMethodCallHandler(null);
    _statusStreamController.close();
  }

  /// Send out the current BACtrackStatus, if there is one, every time a
  /// listener is added.
  void _onListen() {
    if (currentStatus != null) {
      _statusStreamController.add(currentStatus);
    }
  }

  Future _handleMethodCall(MethodCall call) async {
    final state = methodNameToState[call.method];
    if (state != null) {
      _updateStream(state, call.arguments?.toString());
    }
  }

  void _updateStream(BACtrackState state, String message) {
    currentStatus = BACtrackStatus(state, message: message ?? '');
    _statusStreamController.add(currentStatus);
  }
}

/// This method is for unit testing only!  It provides the ability to set up
/// a mock handler for the plugin channel.
void bacTrackPluginSetMockMethodCallHandler(Function(MethodCall) mockHandler) =>
    BACtrackPlugin._channel.setMockMethodCallHandler(mockHandler);
