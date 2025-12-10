import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../features/providers.dart';
import 'provisioning_screen.dart';

class BleScanScreen extends ConsumerStatefulWidget {
  const BleScanScreen({super.key});

  @override
  ConsumerState<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends ConsumerState<BleScanScreen> {
  bool _isScanning = false;
  final List<ScanResult> _scanResults = [];

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartScan();
  }

  Future<void> _checkPermissionsAndStartScan() async {
    // Request permissions
    if (await Permission.bluetoothScan.request().isGranted &&
        await Permission.bluetoothConnect.request().isGranted &&
        await Permission.location.request().isGranted) {
      _startScan();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth permissions required'),
          ),
        );
      }
    }
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    final service = ref.read(bleProvisioningServiceProvider);
    
    service.scanForDevices(timeout: const Duration(seconds: 10)).listen(
      (result) {
        setState(() {
          // Update or add result
          final index = _scanResults.indexWhere(
            (r) => r.device.remoteId == result.device.remoteId,
          );
          if (index >= 0) {
            _scanResults[index] = result;
          } else {
            _scanResults.add(result);
          }
        });
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scan error: $error')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan for Devices'),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isScanning)
            const LinearProgressIndicator()
          else
            Container(
              color: Colors.green.withOpacity(0.1),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scan complete. ${_scanResults.length} device(s) found.',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _scanResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Scanning for devices...'
                              : 'No devices found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _scanResults.length,
                    itemBuilder: (context, index) {
                      final result = _scanResults[index];
                      final deviceName = result.advertisementData.localName.isEmpty
                          ? 'Unknown Device'
                          : result.advertisementData.localName;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.bluetooth),
                          ),
                          title: Text(deviceName),
                          subtitle: Text(
                            'ID: ${result.device.remoteId}\nRSSI: ${result.rssi} dBm',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          isThreeLine: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProvisioningScreen(
                                  device: result.device,
                                  deviceName: deviceName,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _startScan,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  @override
  void dispose() {
    final service = ref.read(bleProvisioningServiceProvider);
    service.stopScan();
    super.dispose();
  }
}
