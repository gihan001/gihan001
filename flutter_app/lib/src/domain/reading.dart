import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading.freezed.dart';
part 'reading.g.dart';

@freezed
class Reading with _$Reading {
  const factory Reading({
    required String readingId,
    required DateTime ts,
    required double powerW,
    required double voltageV,
    required double currentA,
    required double energyWh,
    required int sampleMs,
  }) = _Reading;

  factory Reading.fromJson(Map<String, dynamic> json) => _$ReadingFromJson(json);
}
