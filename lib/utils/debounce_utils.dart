import 'dart:async';
import 'package:flutter/material.dart';

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
  }
}

mixin DebounceMixin<T extends StatefulWidget> on State<T> {
  final Map<String, Debouncer> _debouncers = {};

  Debouncer getDebouncer(String key, {Duration? delay}) {
    if (!_debouncers.containsKey(key)) {
      _debouncers[key] = Debouncer(
        delay: delay ?? const Duration(milliseconds: 500),
      );
    }
    return _debouncers[key]!;
  }

  void debounce(String key, void Function() action, {Duration? delay}) {
    getDebouncer(key, delay: delay).call(action);
  }

  @override
  void dispose() {
    for (var debouncer in _debouncers.values) {
      debouncer.dispose();
    }
    _debouncers.clear();
    super.dispose();
  }
}
