import 'package:freezed_annotation/freezed_annotation.dart';

part 'provisioning_data.freezed.dart';
part 'provisioning_data.g.dart';

@freezed
class ProvisioningData with _$ProvisioningData {
  const factory ProvisioningData({
    required String ssid,
    required String pass,
    required String tz,
    required String deviceName,
    @Default('1.0') String protoVersion,
  }) = _ProvisioningData;

  factory ProvisioningData.fromJson(Map<String, dynamic> json) =>
      _$ProvisioningDataFromJson(json);
}
