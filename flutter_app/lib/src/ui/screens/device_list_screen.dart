import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/providers.dart';
import 'ble_scan_screen.dart';
import 'device_dashboard_screen.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(userDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final repository = ref.read(firebaseRepositoryProvider);
              await repository.signOut();
            },
          ),
        ],
      ),
      body: devicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices_other,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No devices registered',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a device to start monitoring',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.bolt),
                  ),
                  title: Text(device.deviceName),
                  subtitle: Text(
                    'Model: ${device.model}\nFW: ${device.fwVersion}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeviceDashboardScreen(
                          deviceId: device.deviceId,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BleScanScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
    );
  }
}
