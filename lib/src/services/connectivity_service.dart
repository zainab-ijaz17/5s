import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final List<void Function(bool isOnline)> _listeners = [];

  bool _lastOnline = true;

  bool get lastKnownOnline => _lastOnline;

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _hasInternet(results);
  }

  bool _hasInternet(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );
  }

  void addListener(void Function(bool isOnline) onChanged) {
    _listeners.add(onChanged);
    onChanged(_lastOnline);
  }

  void startListening() {
    if (_subscription != null) return;
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final online = _hasInternet(results);
      if (online == _lastOnline) return;
      _lastOnline = online;
      for (final listener in List<void Function(bool)>.from(_listeners)) {
        listener(online);
      }
    });
    isOnline().then((online) {
      _lastOnline = online;
      for (final listener in List<void Function(bool)>.from(_listeners)) {
        listener(online);
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _listeners.clear();
  }
}
