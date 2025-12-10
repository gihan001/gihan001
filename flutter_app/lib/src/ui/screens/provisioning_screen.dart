import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../domain/provisioning_data.dart';
import '../../domain/device.dart';
import '../../features/providers.dart';

class ProvisioningScreen extends ConsumerStatefulWidget {
  final BluetoothDevice device;
  final String deviceName;

  const ProvisioningScreen({
    super.key,
    required this.device,
    required this.deviceName,
  });

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceNameController = TextEditingController();
  
  bool _isProvisioning = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _deviceNameController.text = widget.deviceName;
    _prefillWiFiSSID();
  }

  Future<void> _prefillWiFiSSID() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      
      if (result.contains(ConnectivityResult.wifi)) {
        // Note: Getting actual SSID requires additional permissions on Android
        // For now, we'll just indicate WiFi is available
        setState(() {
          _statusMessage = 'Connected to WiFi. Please enter your network name.';
        });
      }
    } catch (e) {
      // Ignore errors in prefilling
    }
  }

  Future<void> _startProvisioning() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProvisioning = true;
      _statusMessage = 'Connecting to device...';
      _isSuccess = false;
    });

    try {
      FirebaseAnalytics.instance.logEvent(name: 'provisioning_attempt');
      
      final bleService = ref.read(bleProvisioningServiceProvider);
      
      // Connect to device
      await bleService.connectToDevice(widget.device);
      
      setState(() {
        _statusMessage = 'Sending credentials...';
      });

      // Prepare provisioning data
      final provisioningData = ProvisioningData(
        ssid: _ssidController.text,
        pass: _passwordController.text,
        tz: 'Asia/Colombo', // TODO: Get from device timezone
        deviceName: _deviceNameController.text,
      );

      // Send provisioning data
      await bleService.provisionDevice(provisioningData);

      setState(() {
        _statusMessage = 'Waiting for device to connect...';
      });

      // Wait for result
      final result = await bleService.waitForProvisioningResult(
        timeout: const Duration(seconds: 30),
      );

      if (result['status'] == 'ok') {
        setState(() {
          _isSuccess = true;
          _statusMessage = 'Device provisioned successfully!';
        });

        FirebaseAnalytics.instance.logEvent(name: 'provisioning_success');

        // Register device in Firestore
        final repository = ref.read(firebaseRepositoryProvider);
        final newDevice = Device(
          deviceId: widget.device.remoteId.toString(),
          deviceName: _deviceNameController.text,
          model: 'ESP32-Energy-Monitor',
          registeredAt: DateTime.now(),
          lastSeen: DateTime.now(),
          fwVersion: '1.0.0',
          owner: repository.currentUserId!,
        );

        await repository.registerDevice(newDevice);

        // Navigate back after delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        setState(() {
          _statusMessage = 'Error: ${result['msg'] ?? 'Unknown error'}';
        });
        
        FirebaseAnalytics.instance.logEvent(
          name: 'provisioning_failure',
          parameters: {'error': result['msg'] ?? 'unknown'},
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      
      FirebaseAnalytics.instance.logEvent(
        name: 'provisioning_failure',
        parameters: {'error': e.toString()},
      );
    } finally {
      setState(() {
        _isProvisioning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provision Device'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('ID: ${widget.device.remoteId}'),
                      Text('Name: ${widget.deviceName}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.devices),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a device name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: 'WiFi SSID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter WiFi SSID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'WiFi Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter WiFi password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_statusMessage != null)
                Card(
                  color: _isSuccess
                      ? Colors.green.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        if (_isProvisioning)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _isSuccess ? Icons.check_circle : Icons.info,
                            color: _isSuccess ? Colors.green : Colors.blue,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: _isSuccess ? Colors.green : Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isProvisioning ? null : _startProvisioning,
                icon: const Icon(Icons.send),
                label: const Text('Provision Device'),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.amber.withOpacity(0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber),
                          SizedBox(width: 8),
                          Text(
                            'Security Note',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This version uses basic BLE security. '
                        'For production, upgrade to encrypted provisioning (Option A).',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }
}
