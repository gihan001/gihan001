import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../features/providers.dart';
import '../../domain/reading.dart';

class DeviceDashboardScreen extends ConsumerWidget {
  final String deviceId;

  const DeviceDashboardScreen({
    super.key,
    required this.deviceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingsAsync = ref.watch(deviceReadingsProvider(deviceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(deviceReadingsProvider(deviceId));
            },
          ),
        ],
      ),
      body: readingsAsync.when(
        data: (readings) {
          if (readings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No data available yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Waiting for device to send readings...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final latestReading = readings.first;
          final displayReadings = readings.take(50).toList().reversed.toList();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current stats cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Power',
                          value: '${latestReading.powerW.toStringAsFixed(1)} W',
                          icon: Icons.bolt,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          title: 'Voltage',
                          value: '${latestReading.voltageV.toStringAsFixed(1)} V',
                          icon: Icons.electric_bolt,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Current',
                          value: '${latestReading.currentA.toStringAsFixed(2)} A',
                          icon: Icons.flash_on,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          title: 'Energy',
                          value: '${latestReading.energyWh.toStringAsFixed(2)} Wh',
                          icon: Icons.energy_savings_leaf,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Power chart
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Power Consumption',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: _PowerChart(readings: displayReadings),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Voltage chart
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Voltage',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: _VoltageChart(readings: displayReadings),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Recent readings list
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recent Readings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...readings.take(5).map((reading) => _ReadingTile(
                                reading: reading,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerChart extends StatelessWidget {
  final List<Reading> readings;

  const _PowerChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    final spots = readings
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.powerW))
        .toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.orange.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoltageChart extends StatelessWidget {
  final List<Reading> readings;

  const _VoltageChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    final spots = readings
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.voltageV))
        .toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  final Reading reading;

  const _ReadingTile({required this.reading});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            timeFormat.format(reading.ts),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          Text(
            '${reading.powerW.toStringAsFixed(1)}W',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${reading.voltageV.toStringAsFixed(1)}V',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            '${reading.currentA.toStringAsFixed(2)}A',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
