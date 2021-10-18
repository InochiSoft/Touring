import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:toast/toast.dart';
import 'package:touring/constant/color.dart';
import 'package:touring/constant/constant.dart';
import 'package:touring/layout/layout.dart';
import 'package:touring/layout/model/vo/screen.dart';
import 'package:touring/model/config/user.dart';
import 'package:touring/model/vo/group.dart';
import 'package:touring/model/vo/member.dart';
import 'package:touring/model/vo/menu.dart';
import 'package:touring/model/vo/position.dart';
import 'package:touring/model/vo/user.dart';

enum _PositionItemType {
  log,
  position,
}

class _PositionItem {
  _PositionItem(this.type, this.displayValue, this.position);

  final _PositionItemType type;
  final String displayValue;
  final Position position;
}

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

  GoogleMapController _googleMapController;
  final Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};
  final Map<String, MemberVO> _members = <String, MemberVO>{};

  final Set<Polyline> _polylines = {};

  final List<MenuVO> _menuIndexes = [];
  List<Widget> _actionList = [];

  UserVO _userLogin;
  GroupVO _group;
  MemberVO _selectedMember;
  MemberVO _selectedUser;
  MemberVO _selectedHeader;

  String _userName = '';
  String _userId = '';

  CollectionReference _queryUser;
  CollectionReference _queryGroup;
  CollectionReference _queryLives;

  dynamic languages;
  String language;
  double volume = 1.0;
  double pitch = 1.0;
  double rate = 0.5;
  bool isCurrentLanguageInstalled = false;

  FlutterTts flutterTts;

  var _currPosition = PositionVO();
  var _lastPosition = PositionVO();

  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;

  final List<_PositionItem> _positionItems = <_PositionItem>[];
  StreamSubscription<Position> _positionStreamSubscription;
  bool positionStreamStarted = false;

  @override
  void initState() {
    super.initState();
    initTts();
    _group = widget.group;
    _currLatLng = LatLng(0, 0);
    _destLatLng = _currLatLng;
    _initUserMember();
    _getUser();
  }

  @override
  void dispose() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription.cancel();
      _positionStreamSubscription = null;
    }
    flutterTts.stop();
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
        var time = DateTime.now().millisecondsSinceEpoch;

        _lastPosition.lastTime = time;
        _lastPosition.lastLatitude = 0.0;
        _lastPosition.lastLongitude = 0.0;
        _lastPosition.currentTime = time;
        _lastPosition.currentLatitude = 0.0;
        _lastPosition.currentLongitude = 0.0;

        _queryUser = FirebaseFirestore.instance.collection('users');
        _queryGroup = FirebaseFirestore.instance.collection('groups');
        _queryLives = FirebaseFirestore.instance.collection('lives');

        _queryLives.doc(_group.code).collection('members')
            .doc(_userId).get().then((value){
          if (!value.exists){
            _queryLives.doc(_group.code).collection('members')
                .doc(_userId).set(_lastPosition.toJson()).then((value) {
              _getCurrentPosition();
            });
          } else {
            _getCurrentPosition();
          }
        });

      }
    }
  }

  void _toggleListening() {
    final positionStream = _geolocatorPlatform.getPositionStream(
        timeInterval: kTimeInterval
    );
    _positionStreamSubscription = positionStream.handleError((error) {
      _positionStreamSubscription.cancel();
      _positionStreamSubscription = null;
    }).listen((position){
      setState(() {
        _updatePositionList(
            _PositionItemType.position,
            position.toString(),
            position
        );
      });
    });

    /*
    if (_positionStreamSubscription == null) {
      //_positionStreamSubscription.pause();
    }

    setState(() {
      if (_positionStreamSubscription == null) {
        return;
      }

      String statusDisplayValue;
      if (_positionStreamSubscription.isPaused) {
        _positionStreamSubscription.resume();
        statusDisplayValue = 'resumed';
      } else {
        _positionStreamSubscription.pause();
        statusDisplayValue = 'paused';
      }

      _updatePositionList(
          _PositionItemType.log,
          'Listening for position updates $statusDisplayValue',
          null
      );
    });
    */
  }

  void _updatePositionList(_PositionItemType type, String displayValue, Position position) {
    print(displayValue);
    _positionItems.add(_PositionItem(type, displayValue, position));
    if (type == _PositionItemType.position){
      if (position != null){
        _updateLocation(position);
        _updatePositions();
      }
    }
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handlePermission();

    if (!hasPermission) {
      return;
    }

    final position = await _geolocatorPlatform.getCurrentPosition();

    _toggleListening();

    _updatePositionList(
        _PositionItemType.position,
        position.toString(),
        position
    );
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Toast.show(kLocationServicesDisabledMessage,
        this.context,
        duration: Toast.LENGTH_LONG,
        gravity: Toast.BOTTOM,
      );

      _updatePositionList(
          _PositionItemType.log,
          kLocationServicesDisabledMessage,
          null
      );

      return false;
    }

    permission = await _geolocatorPlatform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocatorPlatform.requestPermission();
      if (permission == LocationPermission.denied) {
        Toast.show(kPermissionDeniedMessage,
          this.context,
          duration: Toast.LENGTH_LONG,
          gravity: Toast.BOTTOM,
        );

        _updatePositionList(
            _PositionItemType.log,
            kPermissionDeniedMessage,
            null
        );

        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Toast.show(kPermissionDeniedForeverMessage,
        this.context,
        duration: Toast.LENGTH_LONG,
        gravity: Toast.BOTTOM,
      );
      _updatePositionList(
          _PositionItemType.log,
          kPermissionDeniedForeverMessage,
          null
      );

      return false;
    }

    Toast.show(kPermissionGrantedMessage,
      this.context,
      duration: Toast.LENGTH_LONG,
      gravity: Toast.BOTTOM,
    );

    _updatePositionList(
        _PositionItemType.log,
        kPermissionGrantedMessage,
        null
    );
    return true;
  }

  void _initUserMember(){
    _members['0'] = MemberVO();
    _members['0'].id = '';
    _members['0'].name = '';
    _members['0'].distanceMember = 0.0;
    _members['0'].distanceDestination = 0.0;
    _members['0'].speed = 0.0;

    _selectedMember = _members['0'];
    _selectedUser = _members['0'];
  }

  void _setUserMember() async {
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
    _googleMapController = controller;
    _markers.clear();
    _members.clear();

    _setUserMember();

    setState(() {
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
    });
  }

  void _updateLocation(Position position) async {
    var destLatitude = _group.latitude;
    var destLongitude = _group.longitude;
    _destLatLng = LatLng(destLatitude, destLongitude);

    var currentTime = DateTime.now().millisecondsSinceEpoch;
    double currentLatitude = position.latitude;
    double currentLongitude = position.longitude;

    _currPosition.currentTime = currentTime;
    _currPosition.currentLatitude = currentLatitude;
    _currPosition.currentLongitude = currentLongitude;

    var distance = Geolocator.distanceBetween(
        _lastPosition.currentLatitude, _lastPosition.currentLongitude,
        currentLatitude, currentLongitude);

    var distanceDest = Geolocator.distanceBetween(
        _destLatLng.latitude, _destLatLng.longitude,
        currentLatitude, currentLongitude);

    if (distance > 0.0){
      _queryLives.doc(_group.code).collection('members')
          .doc(_userId).collection('records').get().then((value){
        var size = value.size;
        var num = (size + 1).toString();
        int lastTime = currentTime;

        double lastLatitude = currentLatitude;
        double lastLongitude = currentLongitude;

        if (size > 0){
          var lastData = value.docs[size - 1].data();
          if (lastData != null){
            var lastRecord = PositionVO.fromJson(lastData);
            if (lastRecord != null){
              lastTime = lastRecord.currentTime;
              lastLatitude = lastRecord.currentLatitude;
              lastLongitude = lastRecord.currentLongitude;
              if (lastLatitude == null) lastLatitude = 0.0;
              if (lastLongitude == null) lastLongitude = 0.0;
            }
            if (lastTime == 0) lastTime = currentTime;
          }
        }

        _currPosition.lastTime = lastTime;
        _currPosition.lastLatitude = lastLatitude;
        _currPosition.lastLongitude = lastLongitude;

        _queryLives.doc(_group.code).collection('members')
            .doc(_userId).collection('records')
            .doc(num.padLeft(9, '0'))
            .set(_currPosition.toJson()).then((value){

          _queryLives.doc(_group.code).collection('members')
              .doc(_userId).update(_currPosition.toJson()).then((value) {

            _lastPosition = _currPosition;
          });
        });

        var distanceMove = Geolocator.distanceBetween(
            lastLatitude, lastLongitude,
            currentLatitude, currentLongitude);

        double speed = 0.0;

        var balanceMilli = (currentTime - lastTime);
        if (balanceMilli > 0){
          var balance = balanceMilli / 1000;

          if (distanceMove > 0){
            if (balance > 0){
              var time = balance / 3600.0;
              var distanceKM = distanceMove / 1000.0;
              speed = distanceKM / time;
            }
          }
        }

        _queryGroup.doc(_group.code).collection('members')
            .doc(_userId).update({
          'latitude' : position.latitude,
          'longitude' : position.longitude,
          'distanceDestination' : distanceDest,
          'speed' : speed,
        });

      });
    }
  }

  void _updatePositions() async {
    _members.clear();

    List<MemberVO> memberDistances = [];
    List<MemberVO> memberSpeeds = [];

    final iconUser = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(size: Size(48.0, 48.0,)), 'assets/image/green_bike.png');

    final iconMember = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(size: Size(48.0, 48.0,)), 'assets/image/black_bike.png');

    final iconHeader = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(size: Size(48.0, 48.0,)), 'assets/image/red_bike.png');

    var destLatitude = _group.latitude;
    var destLongitude = _group.longitude;
    _destLatLng = LatLng(destLatitude, destLongitude);

    _queryGroup.doc(_group.code).collection('members')
        .snapshots().listen((_snapshotGroup) {

      double lowestDistance = 0.0;

      memberDistances.clear();
      memberSpeeds.clear();

      for (var i = 0; i < _snapshotGroup.docs.length; i++) {
        var element = _snapshotGroup.docs[i];
        var member = MemberVO.fromJson(element.data());
        var memberId = member.id;
        var currentLatitude = member.latitude;
        var currentLongitude = member.longitude;
        var distanceDestination = member.distanceDestination;

        if (i == 0) lowestDistance = distanceDestination;

        var memberLatLng = LatLng(currentLatitude, currentLongitude);
        var memberMarker = createMarker(iconMember, memberId, memberLatLng, member.name);

        memberDistances.add(member);
        memberSpeeds.add(member);

        setState(() {
          _markers[MarkerId(memberId)] = memberMarker;
          _members[memberId] = member;

          if (memberId == _userId){
            _currLatLng = LatLng(currentLatitude, currentLongitude);
            var userMarker = createMarker(iconUser, _userId, _currLatLng, 'Anda');

            _selectedMember = _members[_userId];
            _selectedUser = _members[_userId];
            _markers[MarkerId(_userId)] = userMarker;
            _googleMapController.moveCamera(CameraUpdate.newLatLng(_currLatLng));
          }
        });

        if (distanceDestination <= lowestDistance){
          lowestDistance = distanceDestination;
          _selectedHeader = _members[memberId];
        }

        _queryUser.doc(memberId).snapshots().listen((_snapshotUser) {
          if (_snapshotUser.exists){
            var userMember = UserVO.fromJson(_snapshotUser.data());
            var memberId = member.id;
            member.name = userMember.name;
            setState(() {
              _members[memberId] = member;

              var memberLatLng = LatLng(_members[memberId].latitude, _members[memberId].longitude);
              var anyMarker = createMarker(iconUser, memberId, memberLatLng, _members[memberId].name);
              _markers[MarkerId(memberId)] = anyMarker;

              if (_selectedMember != null){
                if (_selectedMember.id == memberId){
                  _selectedMember = _members[memberId];
                  var memberLatLng = LatLng(_selectedMember.latitude, _selectedMember.longitude);
                  var selectMarker = createMarker(iconUser, memberId, memberLatLng, _selectedMember.name);
                  _markers[MarkerId(memberId)] = selectMarker;
                }
              }
              if (_selectedUser != null){
                if (_selectedUser.id == memberId){
                  _selectedUser = _members[_userId];
                  var memberLatLng = LatLng(_selectedUser.latitude, _selectedUser.longitude);
                  var userMarker = createMarker(iconUser, memberId, memberLatLng, 'Anda');
                  _markers[MarkerId(memberId)] = userMarker;
                }
              }
              if (_selectedHeader != null){
                if (_selectedHeader.id == memberId){
                  _selectedHeader = _members[memberId];
                  var memberLatLng = LatLng(_selectedHeader.latitude, _selectedHeader.longitude);
                  var headerMarker = createMarker(iconHeader, memberId, memberLatLng, _selectedHeader.name);
                  _markers[MarkerId(memberId)] = headerMarker;
                }
              }
            });
          }
        });
      }

      if (_selectedHeader != null){
        setState(() {
          var memberId = _selectedHeader.id;
          var currentLatitude = _selectedHeader.latitude;
          var currentLongitude = _selectedHeader.longitude;
          var memberLatLng = LatLng(currentLatitude, currentLongitude);
          var headerMarker = createMarker(iconHeader, memberId, memberLatLng, _selectedHeader.name);
          _markers[MarkerId(_selectedHeader.id)] = headerMarker;
        });
      }

      memberDistances.sort((x, y) => x.distanceDestination.compareTo(y.distanceDestination));
      memberSpeeds.sort((x, y) => x.speed.compareTo(y.speed));

      var vd = 0.01;
      var vs = 0.15;

      int memberCount = memberDistances.length;
      for (var i = 0; i < memberCount; i++) {
        var currId = memberDistances[i].id;
        var headerId = memberDistances[0].id;

        double frontDistance = memberDistances[0].distanceDestination / 1000;
        double backDistance = 0;
        double currDistance = memberDistances[i].distanceDestination / 1000;
        double currSpeed = memberDistances[i].speed;
        double currRangeFront = 0.0;
        double currRangeBack = 0.0;
        double safeSpeed = currSpeed * vd * memberCount;
        double safeRange = currSpeed * vs;

        if (i > 0){
          frontDistance = memberDistances[i - 1].distanceDestination / 1000;
          currRangeFront = currDistance - frontDistance;
        }

        if (i < (memberCount - 1)){
          backDistance = memberDistances[i + 1].distanceDestination / 1000;
          currRangeBack = backDistance - currDistance;
        }

        print("index: $i, currRangeFront: $currRangeFront,"
            " currRangeBack: $currRangeBack,"
            " safeSpeed: $safeSpeed, safeRange: $safeRange"
        );

        if (headerId == _userId){
          if (currRangeBack > safeSpeed){
            print("Kurangi Kecepatan");
            var newVoiceText = 'Mohon kurangi kecepatan. '
                'Anda melampaui sejauh ${(currRangeBack * 1000).ceil()} meter.'
                'Kecepatan Anda saat ini ${currSpeed.ceil()} Kilometer per Jam';
            _speak(newVoiceText);
          }
        } else if (currId == _userId){
          if (i > 0){
            //Peringatan tertinggal
            if (currRangeFront > safeRange){
              print("Tambah Kecepatan");
              var newVoiceText = 'Mohon tambah kecepatan. '
                  'Anda tertinggal sejauh ${(currRangeFront * 1000).ceil()} meter.'
                  'Kecepatan Anda saat ini ${currSpeed.ceil()} Kilometer per Jam';
              _speak(newVoiceText);
            }
            if (currRangeFront > safeSpeed){
              print("Tambah Kecepatan");
              var newVoiceText = 'Mohon tambah kecepatan. '
                  'Anda tertinggal sejauh ${(currRangeFront * 1000).ceil()} meter.'
                  'Kecepatan Anda saat ini ${currSpeed.ceil()} Kilometer per Jam';
              _speak(newVoiceText);
            }
          } else {
            //Peringatan kurangi kecepatan
            if (currRangeBack > safeRange){
              print("Kurangi Kecepatan");
              var newVoiceText = 'Mohon kurangi kecepatan. '
                  'Anda melampaui sejauh ${(currRangeBack * 1000).ceil()} meter.'
                  'Kecepatan Anda saat ini ${currSpeed.ceil()} Kilometer per Jam';
              _speak(newVoiceText);
            }
            if (currRangeBack > safeSpeed){
              print("Kurangi Kecepatan");
              var newVoiceText = 'Mohon kurangi kecepatan. '
                  'Anda melampaui sejauh ${(currRangeBack * 1000).ceil()} meter.'
                  'Kecepatan Anda saat ini ${currSpeed.ceil()} Kilometer per Jam';
              _speak(newVoiceText);
            }
          }
        }
      }
      //distances.sort();
      //speeds.sort();

    });
  }

  Marker createMarker(icon, id, latLng, title){
    return Marker(
      icon: icon,
      markerId: MarkerId(id),
      position: latLng,
      infoWindow: InfoWindow(
        title: title,
      ),
      onTap: (){
        setState(() {
          _selectedMember = _members[id];
          if (_selectedUser != null){
            double destUser = _selectedUser.distanceDestination;
            double destMember = _selectedMember.distanceDestination;
            var distance = destMember - destUser;
            if (distance < 0){
              distance = distance * -1;
            }
            _members[id].distanceMember = distance;
            _selectedMember = _members[id];
          }
        });
      },
    );
  }

  Future _getLanguages() async {
    languages = await flutterTts.getLanguages;
    if (languages != null) setState(() => languages);
  }

  Future _getEngines() async {
    var engines = await flutterTts.getEngines;
    if (engines != null) {
      for (dynamic engine in engines) {
        print(engine);
      }
    }
  }

  Future _speak(_newVoiceText) async {
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    if (_newVoiceText != null) {
      if (_newVoiceText.isNotEmpty) {
        await flutterTts.awaitSpeakCompletion(true);
        await flutterTts.speak(_newVoiceText);
      }
    }
  }

  Future _stop() async {
    var result = await flutterTts.stop();
  }

  Future _pause() async {
    var result = await flutterTts.pause();
  }

  void initTts() {
    flutterTts = FlutterTts();

    _getLanguages();

    //if (isAndroid) {
    _getEngines();
    //}

    flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        print("Cancel");
      });
    });
/*

    if (isWeb || isIOS) {
      flutterTts.setPauseHandler(() {
        setState(() {
          print("Paused");
          ttsState = TtsState.paused;
        });
      });

      flutterTts.setContinueHandler(() {
        setState(() {
          print("Continued");
          ttsState = TtsState.continued;
        });
      });
    }
*/

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print('error: $msg');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _initAction(context);
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
