// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripDataAdapter extends TypeAdapter<TripData> {
  @override
  final int typeId = 1;

  @override
  TripData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripData(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
      totalDistanceMeters: fields[3] as double,
      averageSpeedKmh: fields[4] as double,
      maxSpeedKmh: fields[5] as double,
      durationSeconds: fields[6] as int,
      stateIndex: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TripData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.totalDistanceMeters)
      ..writeByte(4)
      ..write(obj.averageSpeedKmh)
      ..writeByte(5)
      ..write(obj.maxSpeedKmh)
      ..writeByte(6)
      ..write(obj.durationSeconds)
      ..writeByte(7)
      ..write(obj.stateIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
