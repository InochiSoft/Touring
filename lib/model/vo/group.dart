import 'dart:convert';

class GroupVO {
  String id;
  String code;
  String name;
  String created;
  String image;
  String creator;
  String type;
  String location;
  double latitude;
  double longitude;

  GroupVO({
    this.id,
    this.code,
    this.name,
    this.type,
    this.creator,
    this.created,
    this.image,
    this.location,
    this.latitude,
    this.longitude,
  });

  factory GroupVO.fromJson(Map<String, dynamic> json) {
    return GroupVO(
      id: json.containsKey('id') ? json['id'].toString() : '0',
      code: json.containsKey('code') ? json['code'].toString() : '',
      name: json.containsKey('name') ? json['name'].toString() : '',
      type: json.containsKey('type') ? json['type'].toString() : '0',
      created: json.containsKey('created') ? json['created'].toString() : '0',
      creator: json.containsKey('creator') ? json['creator'].toString() : '',
      image: json.containsKey('image') ? json['image'].toString() : '',
      location: json.containsKey('location') ? json['location'].toString() : '',
      latitude: json.containsKey('latitude') ? json['latitude'] : 0.0,
      longitude: json.containsKey('longitude') ? json['longitude'] : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id ?? '',
    'code': code ?? '',
    'name': name ?? '',
    'type': type ?? '',
    'creator': creator ?? '',
    'created': created ?? '',
    'image': image ?? '',
    'location': location ?? '',
    'latitude': latitude ?? 0.0,
    'longitude': longitude ?? 0.0,
  };

  @override
  String toString() {
    var jsonData = json.encode(toJson());
    return jsonData;
  }
}
