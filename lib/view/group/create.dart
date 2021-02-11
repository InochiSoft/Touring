import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:toast/toast.dart';
import 'package:touring/constant/constant.dart';
import 'package:touring/helper/clipper.dart';
import 'package:touring/layout/layout.dart';
import 'package:touring/layout/model/vo/screen.dart';
import 'package:touring/model/config/user.dart';
import 'package:touring/model/vo/group.dart';
import 'package:touring/model/vo/menu.dart';
import 'package:touring/model/vo/user.dart';
import 'package:touring/view/login/login.dart';
import 'package:touring/model/vo/locations.dart' as locations;

class CreateGroupPage extends StatefulWidget {
  CreateGroupPage({Key key}) : super(key: key);

  @override
  CreateGroupPageState createState() => CreateGroupPageState();
}

class CreateGroupPageState extends State<CreateGroupPage> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  Position _currPosition;
  LatLng _currLatLng;
  LatLng _destLatLng;
  String _currentAddress;
  MarkerId _selectedMarker;
  Marker _destMarker;
  Marker _currMarker;
  bool _isRefresh = false;

  final TextEditingController _textNameController = TextEditingController();
  final TextEditingController _textLocationController = TextEditingController();

  GoogleMapController _googleMapController;
  final Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};

  final List<MenuVO> _menuIndexes = [];
  List<Widget> _actionList = [];

  UserVO _userLogin;

  CollectionReference _queryUser;
  CollectionReference _queryGroup;
  CollectionReference _queryMembers;

  @override
  void initState() {
    super.initState();
    _currLatLng = LatLng(-6.9971703, 107.5439868);
    _destLatLng = _currLatLng;
    _getCurrentLocation();
    _queryUser = FirebaseFirestore.instance.collection('users');
    _queryGroup = FirebaseFirestore.instance.collection('groups');
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _getUser() async {
    var _userCfg = UserConfig();
    _userLogin = await _userCfg.getUser();
  }

  void _getCurrentLocation() async {
    var position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currPosition = position;
      _currLatLng = LatLng(_currPosition.latitude, _currPosition.longitude);
    });
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

  void _onMapTapped(latLng){
    setState(() {
      _destLatLng = latLng;
      var id = 'YourDestination';
      var newMarker = Marker(
        markerId: MarkerId('YourDestination'),
        position: latLng,
        infoWindow: InfoWindow(
          title: 'Lokasi Tujuan',
          snippet: 'Posisi lokasi tujuan',
        ),
      );
      _destMarker = newMarker.copyWith(
        iconParam: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
      );
      _markers.clear();
      _markers[_currMarker.markerId] = _currMarker;
      _markers[MarkerId(id)] = _destMarker;
    });

    print(latLng.latitude);
    print(latLng.longitude);
  }

  Future<void> _createGroup() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Buat Grup'),
          content: Container(
            height: 120.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _textNameController,
                  decoration: InputDecoration(hintText: 'Nama Grup'),
                ),
                SizedBox(height: 10.0,),
                TextField(
                  controller: _textLocationController,
                  decoration: InputDecoration(hintText: 'Nama Lokasi'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            MaterialButton(
              child: Text('Batal'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            MaterialButton(
              child: Text('Simpan'),
              onPressed: () {
                if (_textNameController.text.isNotEmpty &&
                    _textLocationController.text.isNotEmpty){
                  var groupVO = GroupVO();
                  groupVO.creator = _userLogin.uid;
                  groupVO.longitude = _destLatLng.longitude;
                  groupVO.latitude = _destLatLng.latitude;
                  groupVO.name = _textNameController.text;
                  groupVO.location = _textLocationController.text;

                  _queryGroup.add(groupVO.toJson()).then((value) {
                    var id = value.id;
                    _queryMembers = _queryGroup.doc(id).collection('members');
                    _queryMembers.doc(_userLogin.uid).set({
                      'id' : _userLogin.uid,
                      'latitude' : _currLatLng.latitude,
                      'longitude' : _currLatLng.longitude,
                    });
                    _queryUser.doc(_userLogin.uid).collection('groups').doc(id).set({'id': id});
                    _isRefresh = true;
                    Toast.show('Grup ${groupVO.name} berhasil dibuat',
                      context,
                      duration: Toast.LENGTH_LONG,
                      gravity: Toast.BOTTOM,
                    );
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initMap(GoogleMapController controller) async {
    setState(() {
      var id = 'YourLocation';
      _googleMapController = controller;
      _markers.clear();
      _currMarker = Marker(
        markerId: MarkerId(id),
        position: _currLatLng,
        infoWindow: InfoWindow(
          title: 'Lokasi Anda',
          snippet: 'Posisi lokasi Anda saat ini',
        ),
      );
      _markers[MarkerId(id)] = _currMarker;
      /*
      for (final office in googleOffices.offices) {
        final marker = Marker(
          markerId: MarkerId(office.name),
          position: LatLng(office.lat, office.lng),
          infoWindow: InfoWindow(
            title: office.name,
            snippet: office.address,
          ),
        );
        _markers[office.name] = marker;
      }
      */
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
                'Buat Grup',
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
                'Pilih Titik Destinasi Grup',
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
        height: MediaQuery.of(context).size.height - 160,
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
                onTap: _onMapTapped,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer(),
                  ),
                },
              ),
            ),
            SizedBox(height: 12,),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.only(left: 16.0, ),
                      child: Text(
                        'Latitude: ${_destLatLng.latitude.toString()}',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12,),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.only(right: 16.0, ),
                      child: Text(
                        'Longitude: ${_destLatLng.longitude.toString()}',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    Widget _content = SliverToBoxAdapter(
      child: Center(
        child: Container(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: 16.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                color: Color.fromRGBO(0, 0, 0, 255),
                child: MaterialButton(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(5.0,),),
                  ),
                  color: kColorPrimary,
                  onPressed: () {
                    _createGroup();
                  },
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.check_circle,
                          color: Colors.black45,
                        ),
                        SizedBox(width: 12,),
                        Text('Buat',
                          style: TextStyle(
                            fontSize: 18.0,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    var _bodyList = <Widget>[
      _appBar,
      _map,
      _content,
    ];

    Widget _createGroupPage =
    WillPopScope(
      onWillPop: () {
        Navigator.pop(context, _isRefresh);
        return Future(() => true);
      },
      child: Scaffold(
        body: LayoutUI(
          screen: ScreenVO(
            template: Templates.home,
            body: _bodyList,
          ),
        ),
      ),
    );
    return _createGroupPage;
  }
}