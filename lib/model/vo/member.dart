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
    this.speed,
  });

  factory MemberVO.fromJson(Map<String, dynamic> json) {
    return MemberVO(
      id: json.containsKey('id') ? json['id'].toString() : '',
      latitude: json.containsKey('latitude') ? json['latitude'] : 0.0,
      longitude: json.containsKey('longitude') ? json['longitude'] : 0.0,
      distanceMember: json.containsKey('distanceMember') ? json['distanceMember'] : 0.0,
      distanceDestination: json.containsKey('distanceDestination') ? json['distanceDestination'] : 0.0,
      speed: json.containsKey('speed') ? json['speed'] : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id ?? '',
    'latitude': latitude ?? 0.0,
    'longitude': longitude ?? 0.0,
    'distanceMember': distanceMember ?? 0.0,
    'distanceDestination': distanceDestination ?? 0.0,
    'speed': speed ?? 0.0,
  };

  @override
  String toString() {
    var jsonData = json.encode(toJson());
    return jsonData;
  }
}
