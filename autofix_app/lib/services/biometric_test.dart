import 'package:flutter/material.dart';
import 'biometric_auth_service.dart';

class BiometricTestScreen extends StatefulWidget {
  const BiometricTestScreen({super.key});

  @override
  State<BiometricTestScreen> createState() => _BiometricTestScreenState();
}

class _BiometricTestScreenState extends State<BiometricTestScreen> {
  final BiometricAuthService _biometricService = BiometricAuthService();
  String _status = 'Not tested yet';
  List<String> _biometricTypes = [];

  Future<void> _testBiometricAvailability() async {
    setState(() {
      _status = 'Checking biometric availability...';
    });

    try {
      final canCheck = await _biometricService.canCheckBiometrics();
      final isSupported = await _biometricService.isDeviceSupported();
      final types = await _biometricService.getAvailableBiometrics();
      
      final typeNames = types.map((type) => _biometricService.getBiometricTypeName(type)).toList();
      
      setState(() {
        _status = 'Can check biometrics: $canCheck\nDevice supported: $isSupported\nAvailable types: ${typeNames.join(', ')}';
        _biometricTypes = typeNames;
      });
    } catch (e) {
      setState(() {
        _status = 'Error checking biometrics: $e';
      });
    }
  }

  Future<void> _testBiometricAuthentication() async {
    setState(() {
      _status = 'Attempting biometric authentication...';
    });

    try {
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Test biometric authentication for AutoFix',
        useErrorDialogs: true,
        stickyAuth: true,
      );
      
      setState(() {
        _status = authenticated 
          ? 'Authentication successful! ✅' 
          : 'Authentication failed or cancelled ❌';
      });
    } catch (e) {
      setState(() {
        _status = 'Error during authentication: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Biometric Test',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(_status),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testBiometricAvailability,
              child: const Text('Check Biometric Availability'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testBiometricAuthentication,
              child: const Text('Test Biometric Authentication'),
            ),
            const SizedBox(height: 16),
            if (_biometricTypes.isNotEmpty) ...[
              const Text('Available Biometric Types:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (var type in _biometricTypes)
                Text('• $type'),
            ],
          ],
        ),
      ),
    );
  }
}
