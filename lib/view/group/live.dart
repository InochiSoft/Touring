import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:touring/constant/constant.dart';
import 'package:touring/layout/layout.dart';
import 'package:touring/layout/model/vo/screen.dart';
import 'package:touring/model/config/user.dart';
import 'package:touring/model/vo/group.dart';
import 'package:touring/model/vo/member.dart';
import 'package:touring/model/vo/menu.dart';
import 'package:touring/model/vo/position.dart';
import 'package:touring/model/vo/user.dart';

class LiveGroupPage extends StatefulWidget {
  final GroupVO group;
  LiveGroupPage({Key key, this.group}) : super(key: key);

  @override
  LiveGroupPageState createState() => LiveGroupPageState();
}

class LiveGroupPageState extends State<LiveGroupPage> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  LatLng _currLatLng;
  LatLng _destLatLng;
  Marker _destMarker;
  Marker _currMarker;

  GoogleMapController _googleMapController;
  final Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};
  final Map<String, MemberVO> _members = <String, MemberVO>{};
  final Map<String, LatLng> _positions = <String, LatLng>{};

  final Set<Polyline> _polylines = {};

  final List<MenuVO> _menuIndexes = [];
  List<Widget> _actionList = [];

  UserVO _userLogin;
  GroupVO _group;
  MemberVO _selectedMember;

  String _userName = '';
  String _userId = '';
  var _positionStream;
  var _speed = 0.0;

  CollectionReference _queryUser;
  CollectionReference _queryGroup;
  CollectionReference _queryMembers;
  CollectionReference _queryLives;

  double _lastLatitude = 0.0000000;
  double _lastLongitude = 0.0000000;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _currLatLng = LatLng(-6.9971703, 107.5439868);
    _destLatLng = _currLatLng;
    _queryUser = FirebaseFirestore.instance.collection('users');
    _queryGroup = FirebaseFirestore.instance.collection('groups');
    _queryLives = FirebaseFirestore.instance.collection('lives');
    _initUserMember();
    _getUser();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _getUser() async {
    var _userCfg = UserConfig();
    _userLogin = await _userCfg.getUser();
    if (_userLogin != null){
      _userName = _userLogin.name;
      _userId = _userLogin.uid;
      _setUserMember();

      if (_group != null) {
        _getCurrentLocation();
      }
    }
  }

  void _initUserMember(){
    _members['0'] = MemberVO();
    _members['0'].id = '';
    _members['0'].name = '';
    _members['0'].distanceMember = 0.0;
    _members['0'].distanceDestination = 0.0;
    _members['0'].speed = 0.0;

    _selectedMember = _members['0'];
  }

  void _setUserMember(){
    _members[_userId] = MemberVO();
    _members[_userId].id = _userId;
    _members[_userId].name = _userName;
    _members[_userId].distanceMember = 0.0;
    _members[_userId].distanceDestination = 0.0;
    _members[_userId].speed = 0.0;

    _selectedMember = _members[_userId];

  }

  void _initMenu() {
    _menuIndexes.clear();

    var menu = MenuVO();

    menu = MenuVO();
    menu.id = 1;
    menu.count = 8;
    menu.text = 'Buat Grup';
    menu.textColor = Colors.green[800];
    menu.shadowColor = Colors.green[300];
    menu.backColor = Colors.green[200];
    menu.colors = [
      Colors.green[200],
      Colors.green[400],
      Colors.green[600],
    ];
    menu.icon = Icons.group_add;
    _menuIndexes.add(menu);

    menu = MenuVO();
    menu.id = 2;
    menu.count = 6;
    menu.text = 'Gabung Grup';
    menu.textColor = Colors.blue[800];
    menu.shadowColor = Colors.blue[300];
    menu.backColor = Colors.blue[200];
    menu.colors = [
      Colors.blue[200],
      Colors.blue[400],
      Colors.blue[600],
    ];
    menu.icon = Icons.group_work;
    _menuIndexes.add(menu);

  }

  void _initAction(context){
    _actionList.clear();
    _actionList = [
      IconButton(
        icon: Icon(Icons.logout),
        tooltip: 'Keluar',
        onPressed: () {

        },
      ),
    ];
  }

  Future<void> _initMap(GoogleMapController controller) async {
    final icon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(size: Size(48.0, 48.0,)), 'assets/image/green_bike.png');

    _googleMapController = controller;
    _markers.clear();
    _members.clear();

    _setUserMember();

    setState(() {
      _currMarker = Marker(
        icon: icon,
        markerId: MarkerId(_userId),
        position: _currLatLng,
        infoWindow: InfoWindow(
          title: 'Anda',
        ),
        onTap: (){
          setState(() {
            _selectedMember = _members[_userId];
          });
        },
      );

      if (_group != null){
        var destLatitude = _group.latitude;
        var destLongitude = _group.longitude;
        _destLatLng = LatLng(destLatitude, destLongitude);
        _destMarker = Marker(
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          markerId: MarkerId(_group.code),
          position: _destLatLng,
          infoWindow: InfoWindow(
            title: '${_group.location}',
            snippet: 'Posisi Lokasi Tujuan',
          ),
        );

        _markers[MarkerId(_group.code)] = _destMarker;
      }

      _markers[MarkerId(_userId)] = _currMarker;
    });

    if (_group != null){
      final iconMember = await BitmapDescriptor.fromAssetImage(
          ImageConfiguration(size: Size(48.0, 48.0,)), 'assets/image/black_bike.png');

      _queryLives.doc(_group.code).collection('members')
          .doc(_userId).collection('positions')
          .doc('last').snapshots().listen((element) {
        var position = PositionVO.fromJson(element.data());
        _currLatLng = LatLng(position.latitude, position.longitude);
        _lastLatitude = position.latitude;
        _lastLongitude = position.longitude;
      });

      _queryGroup.doc(_group.code).collection('members').snapshots().listen((_snapshotGroup) {
        for (var i = 0; i < _snapshotGroup.docs.length; i++){
          var element = _snapshotGroup.docs[i];
          var member = MemberVO.fromJson(element.data());
          var memberId = member.id;

          if (memberId != _userId){

            PositionVO firstPosition;
            PositionVO lastPosition;

            _queryUser.doc(memberId).snapshots().listen((_snapshotUser) {
              if (_snapshotUser.exists){
                var userMember = UserVO.fromJson(_snapshotUser.data());
                member.id = memberId;
                member.name = userMember.name;

                _queryLives.doc(_group.code).collection('members')
                    .doc(memberId).collection('positions')
                    .doc('first').snapshots().listen((element) {
                  firstPosition = PositionVO.fromJson(element.data());

                  _queryLives.doc(_group.code).collection('members')
                      .doc(memberId).collection('positions')
                      .doc('last').snapshots().listen((element) {
                    lastPosition = PositionVO.fromJson(element.data());
                    var memberLatLng = LatLng(lastPosition.latitude, lastPosition.longitude);

                    var distanceMember = Geolocator.distanceBetween(
                        _lastLatitude, _lastLongitude, lastPosition.latitude, lastPosition.longitude);

                    var distanceDest = Geolocator.distanceBetween(
                        _destLatLng.latitude, _destLatLng.longitude, lastPosition.latitude, lastPosition.longitude);

                    member.distanceMember = distanceMember;
                    member.distanceDestination = distanceDest;
                    member.speed = 0.0;

                    var firstCreated = int.parse(firstPosition.created);
                    var lastCreated = int.parse(lastPosition.created);
                    var balanceMilli = (lastCreated - firstCreated);
                    var balance = balanceMilli / 1000;

                    var firstLat = firstPosition.latitude;
                    var firstLon = firstPosition.longitude;

                    var lastLat = lastPosition.latitude;
                    var lastLon = lastPosition.longitude;

                    var distanceMeter = Geolocator.distanceBetween(firstLat, firstLon, lastLat, lastLon);
                    if (distanceMeter > 0){
                      if (balance > 0){
                        var time = balance / 3600.0;
                        var distanceKM = distanceMeter / 1000.0;
                        var speed = distanceKM / time;
                        member.speed = speed;
                      }
                    }

                    var memberMarker = Marker(
                      icon: iconMember,
                      markerId: MarkerId(memberId),
                      position: memberLatLng,
                      infoWindow: InfoWindow(
                          title: '${userMember.name}',
                      ),
                      onTap: (){
                        setState(() {
                          _selectedMember = _members[memberId];
                        });
                      },
                    );

                    setState(() {
                      _markers[MarkerId(memberId)] = memberMarker;
                      _members[memberId] = member;
                    });
                  });
                });
              }
            });
          }
        }
      });
    }
  }

  void _getCurrentLocation() async {
    await _queryLives.doc(_group.code).collection('members').doc(_userId).delete();
    var position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    var time = DateTime.now().millisecondsSinceEpoch;
    var data = {
      'created' : time,
      'latitude' : position.latitude,
      'longitude' : position.longitude,
    };

    if (_lastLatitude.toStringAsFixed(7) != position.latitude.toStringAsFixed(7)) {
      if (_lastLongitude.toStringAsFixed(7) !=
          position.longitude.toStringAsFixed(7)) {
        await _queryLives.doc(_group.code).collection('members')
            .doc(_userId).collection('positions')
            .doc('first').set(data);

        setState(() {
          _currLatLng = LatLng(position.latitude, position.longitude);
          _lastLatitude = position.latitude;
          _lastLongitude = position.longitude;
        });
      }
    }
    _updateLocation();
    _updateSpeed();
  }

  void _updateLocation(){
    _positionStream = Geolocator.getPositionStream(
      desiredAccuracy: LocationAccuracy.high,
      distanceFilter: 25,
    ).listen((Position position){
      var time = DateTime.now().millisecondsSinceEpoch;
      var data = {
        'created' : time,
        'latitude' : position.latitude,
        'longitude' : position.longitude,
      };

      if (_lastLatitude.toStringAsFixed(7) != position.latitude.toStringAsFixed(7)){
        if (_lastLongitude.toStringAsFixed(7) != position.longitude.toStringAsFixed(7)){
          _queryLives.doc(_group.code).collection('members')
              .doc(_userId).collection('positions')
              .doc('last').set(data).then((value) {

            _queryLives.doc(_group.code).collection('members')
                .doc(_userId).collection('records').get().then((value){
              var size = value.size;
              var num = size.toString();

              _queryLives.doc(_group.code).collection('members')
                  .doc(_userId).collection('records')
                  .doc(num..padLeft(9, '0'))
                  .set(data);
            });

            setState(() {
              _lastLatitude = position.latitude;
              _lastLongitude = position.longitude;

              _currLatLng = LatLng(position.latitude, position.longitude);
              //_updateLines();
            });
          });
        }
      }
    });

    /*
    if (_positionStream != null){
      _positionStream.cancel();
    }
    */
  }

  void _updateLines(){
    _queryLives.doc(_group.code).collection('members')
        .doc(_userId).collection('records')
        .snapshots()
        .listen((_snapshotPos) {
          var size = _snapshotPos.docs.length;
          for (var i = 0; i < size; i++){
            var element = _snapshotPos.docs[i];
            var position = PositionVO.fromJson(element.data());
            var memberLatLng = LatLng(position.latitude, position.longitude);
            _positions[element.id] = memberLatLng;
          }
          setState(() {
            _polylines.clear();
            _polylines.add(Polyline(
              polylineId: PolylineId(_userId),
              visible: true,
              points: _positions.values.toList(),
              width: 4,
              color: Colors.blue,
            ));
          });
    });
  }

  void _updateSpeed(){
    PositionVO firstPosition;
    PositionVO lastPosition;

    _queryLives.doc(_group.code).collection('members')
        .doc(_userId).collection('positions')
        .doc('first').get().then((value){
          if (value.exists){
            firstPosition = PositionVO.fromJson(value.data());
            _queryLives.doc(_group.code).collection('members')
                .doc(_userId).collection('positions')
                .doc('last').get().then((value){
              if (value.exists){
                lastPosition = PositionVO.fromJson(value.data());

                var firstCreated = int.parse(firstPosition.created);
                var lastCreated = int.parse(lastPosition.created);
                var balanceMilli = (lastCreated - firstCreated);
                var balance = balanceMilli / 1000;

                var firstLat = firstPosition.latitude;
                var firstLon = firstPosition.longitude;

                var lastLat = lastPosition.latitude;
                var lastLon = lastPosition.longitude;

                var distanceDest = Geolocator.distanceBetween(
                    _destLatLng.latitude, _destLatLng.longitude, lastPosition.latitude, lastPosition.longitude);

                var distanceMeter = Geolocator.distanceBetween(firstLat, firstLon, lastLat, lastLon);
                if (distanceMeter > 0){
                  if (balance > 0){
                    var time = balance / 3600.0;
                    var distanceKM = distanceMeter / 1000.0;
                    setState(() {
                      _speed = distanceKM / time;
                    });
                  }
                }
                _members[_userId].distanceMember = 0.0;
                _members[_userId].distanceDestination = distanceDest;
                _members[_userId].speed = _speed;
                //var speed =
              }
            });
          }
    });
  }

  @override
  Widget build(BuildContext context) {
    _initAction(context);
    _getUser();
    _initMenu();

    Widget _appBar = SliverAppBar(
      toolbarHeight: 80.0,
      elevation: 1.0,
      backgroundColor: kColorPrimary,
      iconTheme: IconThemeData(color: Colors.black),
      title: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              child: Text(
                'Live',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              child: Text(
                'Posisi Anggota Grup',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16.0,
                ),
              ),
            ),
          ],
        ),
      ),
      floating: true,
      pinned: true,
    );

    Widget _map = SliverToBoxAdapter(
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height - 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: GoogleMap(
                onMapCreated: _initMap,
                compassEnabled: true,
                rotateGesturesEnabled: true,
                mapToolbarEnabled: true,
                tiltGesturesEnabled: true,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                initialCameraPosition: CameraPosition(
                  target: _currLatLng,
                  zoom: 15,
                ),
                markers: _markers.values.toSet(),
                polylines: _polylines,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer(),
                  ),
                },
              ),
            ),
            SizedBox(height: 12,),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nama Anggota',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                          ),
                        ),
                        SizedBox(height: 5.0,),
                        Text(
                          'Jarak dengan Anda',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                          ),
                        ),
                        SizedBox(height: 5.0,),
                        Text(
                          'Jarak ke Tujuan',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                          ),
                        ),
                        SizedBox(height: 5.0,),
                        Text(
                          'Kecepatan',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                          ),
                        ),
                        SizedBox(height: 5.0,),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.0,),
                  SizedBox(width: 10.0,),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedMember.name}',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5.0,),
                        Text(
                          '${_selectedMember.distanceMember.toStringAsFixed(2)} meter',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                          ),
                        ),
                        SizedBox(height: 5.0,),
                        Text(
                          '${_selectedMember.distanceDestination.toStringAsFixed(2)} meter',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                          ),
                        ),
                        SizedBox(height: 5.0,),
                        Text(
                          '${_selectedMember.speed.toStringAsFixed(0)} KMPJ',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                          ),
                        ),
                        SizedBox(height: 5.0,),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    var _bodyList = <Widget>[
      _appBar,
      _map,
    ];

    Widget _liveGroupPage =
    Scaffold(
      body: LayoutUI(
        screen: ScreenVO(
          template: Templates.home,
          body: _bodyList,
        ),
      ),
    );
    return _liveGroupPage;
  }
}
