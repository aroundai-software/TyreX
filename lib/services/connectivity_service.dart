// lib/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool> connectionStatusController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => connectionStatusController.stream;
  bool _hasConnection = true;

  bool get hasConnection => _hasConnection;

  Future<void> initialize() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);

      _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
        _updateConnectionStatus(results);
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing connectivity service: $e');
      }
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (_hasConnection != hasConnection) {
      _hasConnection = hasConnection;
      connectionStatusController.add(hasConnection);

      if (kDebugMode) {
        print('Connection status changed: ${hasConnection ? "Connected" : "Disconnected"}');
      }
    }
  }

  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking connection: $e');
      }
      return false;
    }
  }

  void dispose() {
    connectionStatusController.close();
  }
}