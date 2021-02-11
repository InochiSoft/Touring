import 'dart:convert';

class MemberVO {
  String id;
  String name;
  double latitude;
  double longitude;
  double distanceMember;
  double distanceDestination;
  double speed;

  MemberVO({
    this.id,
    this.name,
    this.latitude,
    this.longitude,
    this.distanceMember,
    this.distanceDestination,
  });

  factory MemberVO.fromJson(Map<String, dynamic> json) {
    return MemberVO(
      id: json.containsKey('id') ? json['id'].toString() : '0',
      latitude: json.containsKey('latitude') ? json['latitude'] : 0.0,
      longitude: json.containsKey('longitude') ? json['longitude'] : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id ?? '',
    'latitude': latitude ?? 0.0,
    'longitude': longitude ?? 0.0,
  };

  @override
  String toString() {
    var jsonData = json.encode(toJson());
    return jsonData;
  }
}
