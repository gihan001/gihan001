import 'package:freezed_annotation/freezed_annotation.dart';

part 'device.freezed.dart';
part 'device.g.dart';

@freezed
class Device with _$Device {
  const factory Device({
    required String deviceId,
    required String deviceName,
    required String model,
    required DateTime registeredAt,
    required DateTime lastSeen,
    required String fwVersion,
    required String owner,
  }) = _Device;

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
}
