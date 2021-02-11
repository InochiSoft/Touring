import 'dart:convert';

class PositionVO {
  String created;
  double latitude;
  double longitude;

  PositionVO({
    this.created,
    this.latitude,
    this.longitude,
  });

  factory PositionVO.fromJson(Map<String, dynamic> json) {
    return PositionVO(
      created: json.containsKey('created') ? json['created'].toString() : '0',
      latitude: json.containsKey('latitude') ? json['latitude'] : 0.0,
      longitude: json.containsKey('longitude') ? json['longitude'] : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'created': created ?? '0',
    'latitude': latitude ?? 0.0,
    'longitude': longitude ?? 0.0,
  };

  @override
  String toString() {
    var jsonData = json.encode(toJson());
    return jsonData;
  }
}
