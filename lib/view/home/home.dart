
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:touring/constant/constant.dart';
import 'package:touring/helper/clipper.dart';
import 'package:touring/layout/layout.dart';
import 'package:touring/layout/model/vo/screen.dart';
import 'package:touring/model/config/user.dart';
import 'package:touring/model/vo/group.dart';
import 'package:touring/model/vo/menu.dart';
import 'package:touring/model/vo/user.dart';
import 'package:touring/view/group/create.dart';
import 'package:touring/view/group/info.dart';
import 'package:touring/view/group/join.dart';
import 'package:touring/view/group/list.dart';
import 'package:touring/view/login/login.dart';

class HomePage extends StatefulWidget {
  HomePage({Key key}) : super(key: key);
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  final List<MenuVO> _menuIndexes = [];
  final List<GroupVO> _groupIndexes = [];
  List<Widget> _actionList = [];

  UserVO _userLogin;
  String _userName = '';
  String _userId = '';
  bool _isLoggedIn = false;
  int _listMode = 0;

  final UserConfig _userCfg = UserConfig();
  CollectionReference _queryUser;
  CollectionReference _queryGroup;

  @override
  void initState() {
    super.initState();
    _queryUser = FirebaseFirestore.instance.collection('users');
    _queryGroup = FirebaseFirestore.instance.collection('groups');
    _initAction();
    _initMenu();
    _getUser();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _getUser() async {
    var _userCfg = UserConfig();
    _userLogin = await _userCfg.getUser();
    setState(() {
      if (_userLogin != null){
        _userName = _userLogin.name;
        _userId = _userLogin.uid;
        _getListGroup();
      }
    });
  }

  void _getListGroup2() async {
    if (_userId.isNotEmpty){
      var _snapshotUser = await _queryUser.doc(_userId).collection('groups').get();
      if (_snapshotUser.size > 0){
        setState(() {
          _groupIndexes.clear();
        });
        for (var i = 0; i < _snapshotUser.docs.length; i++){
          var element = _snapshotUser.docs[i];
          var tmpGroup = GroupVO.fromJson(element.data());
          setState(() {
            _groupIndexes.add(tmpGroup);
          });
          var id = tmpGroup.id;
          await _queryGroup.doc(id).get().then((value) {
            if (value.exists){
              var group = GroupVO.fromJson(value.data());
              group.code = id;
              setState(() {
                _groupIndexes[i] = group;
              });
            }
          });
        }
      }
    }
  }

  void _getListGroup() async {
    if (_userId.isNotEmpty){
      _groupIndexes.clear();
      _queryUser.doc(_userId).collection('groups').snapshots().listen((_snapshotUser) {
        if (_snapshotUser.docs.isNotEmpty){
          setState(() {
            _listMode = 1;
            _groupIndexes.clear();
          });
        }
        for (var i = 0; i < _snapshotUser.docs.length; i++){
          var element = _snapshotUser.docs[i];
          var tmpGroup = GroupVO.fromJson(element.data());
          setState(() {
            _groupIndexes.add(tmpGroup);
          });
          var id = tmpGroup.id;
          _queryGroup.doc(id).snapshots().listen((value) {
            var group = GroupVO.fromJson(value.data());
            group.code = id;
            setState(() {
              _groupIndexes[i] = group;
            });
          });
          /*
          _queryGroup.doc(id).get().then((value) {
            if (value.exists){
              var group = GroupVO.fromJson(value.data());
              group.code = id;
              setState(() {
                _groupIndexes[i] = group;
              });
            }
          });
          */
        }
      });
    }
  }

  void _refreshList(bool reload){
    if (reload){
      _getListGroup();
    }
  }

  void _initMenu() {
    _menuIndexes.clear();

    var menu = MenuVO();

    menu = MenuVO();
    menu.id = 1;
    menu.count = 8;
    menu.text = 'Buat Grup';
    menu.textColor = Colors.blue[800];
    menu.shadowColor = Colors.blue[300];
    menu.backColor = Colors.blue[200];
    menu.colors = [
      Colors.blue[200],
      Colors.blue[400],
      Colors.blue[600],
    ];
    menu.icon = Icons.group_add;
    _menuIndexes.add(menu);

    menu = MenuVO();
    menu.id = 2;
    menu.count = 6;
    menu.text = 'Gabung Grup';
    menu.textColor = Colors.yellow[800];
    menu.shadowColor = Colors.yellow[300];
    menu.backColor = Colors.yellow[200];
    menu.colors = [
      Colors.yellow[200],
      Colors.yellow[400],
      Colors.yellow[600],
    ];
    menu.icon = Icons.group_work;
    _menuIndexes.add(menu);

  }

  void _initAction(){
    _actionList.clear();
    _actionList = [
      IconButton(
        icon: Icon(Icons.logout),
        tooltip: 'Keluar',
        onPressed: () {
          _logout();
        },
      ),
    ];
  }

  void _menuClick(int index){
    switch(index){
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateGroupPage(),
          ),
        ).then((value){
          _refreshList(value);
        });
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JoinGroupPage(),
          ),
        ).then((value){
          _refreshList(value);
        });
        break;
    }
  }

  void _groupClick(int index){
    var group = _groupIndexes[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfoGroupPage(
          group: group,
        ),
      ),
    ).then((value){
      _refreshList(value);
    });
  }

/*
  StreamSubscription<Position> positionStream = Geolocator.getPositionStream(timeInterval: 60).listen(
          (Position position) {
        print(position == null ? 'Unknown' : position.latitude.toString() + ', ' + position.longitude.toString());
        // locationOptions
      });
*/

  Widget _itemMenu(int index) {
    var menu = _menuIndexes[index];
    var text = menu.text;

    var textColor = menu.textColor;
    var textShadow = menu.shadowColor;
    var backColor = menu.backColor;

    var colors1 = menu.colors;
    var colors2 = menu.colors;

    Widget icon = Icon(
      menu.icon,
      size: 40.0,
      color: textColor,
    );

    Widget content = Container(
      padding: EdgeInsets.all(0.0),
      height: double.infinity,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          icon,
          SizedBox(
            height: 5.0,
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 20.0,
              color: textColor,
              shadows: [
                Shadow(
                  color: textShadow,
                  blurRadius: 4.0,
                  offset: Offset(2.0, 2.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: EdgeInsets.all(kItemSpace),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(0),
          bottomLeft: Radius.circular(14),
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Card(
            margin: EdgeInsets.all(0),
            elevation: 4.0,
            color: backColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(0),
                bottomLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(0),
              ),
              side: BorderSide(
                color: backColor,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: Material(
              color: backColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(0),
                bottomLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(0),
              ),
              child: InkWell(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  bottomLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(0),
                ),
                child: content,
                onTap: () {
                  _menuClick(index);
                },
              ),
            ),
          ),
          ClipPath(
            clipper: CurveSmall(),
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors1,
                  begin: Alignment.topLeft,
                  end: Alignment(1, 1),
                  tileMode: TileMode.repeated,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  bottomLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(0),
                ),
              ),
            ),
          ),
          ClipPath(
            clipper: CurveBottom(),
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors2,
                  begin: Alignment.topRight,
                  end: Alignment(1, 1),
                  tileMode: TileMode.repeated,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  bottomLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemGroup(int index) {
    var group = _groupIndexes[index];
    var text = group.name;
    var code = group.code;
    var location = group.location;

    var textColor = Colors.green[800];
    var shadowColor = Colors.green[300];
    var backColor = Colors.green[200];
    var colors = [
      Colors.green[200],
      Colors.green[400],
      Colors.green[600],
    ];

    var type = group.type;

    if (type == '1'){
      textColor = Colors.green[800];
      shadowColor = Colors.green[300];
      backColor = Colors.green[200];
      colors = [
        Colors.green[200],
        Colors.green[400],
        Colors.green[600],
      ];
    }

    Widget icon = Icon(
      Icons.group_rounded,
      size: 30.0,
      color: textColor,
    );

    Widget content = Container(
      padding: EdgeInsets.all(0.0),
      height: double.infinity,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              icon,
              SizedBox(
                width: 5.0,
              ),
              Text(
                text,
                style: TextStyle(
                  fontSize: 20.0,
                  color: textColor,
                  shadows: [
                    Shadow(
                      color: shadowColor,
                      blurRadius: 4.0,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            code,
            style: TextStyle(
              fontSize: 14.0,
              color: textColor,
            ),
          ),
          SizedBox(
            height: 5.0,
          ),
          Text(
            location,
            style: TextStyle(
              fontSize: 14.0,
              color: textColor,
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: EdgeInsets.all(kItemSpace),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(0),
          bottomLeft: Radius.circular(14),
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Card(
            margin: EdgeInsets.all(0),
            elevation: 4.0,
            color: backColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(0),
                bottomLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(0),
              ),
              side: BorderSide(
                color: backColor,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: Material(
              color: backColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(0),
                bottomLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(0),
              ),
              child: InkWell(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  bottomLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(0),
                ),
                child: content,
                onTap: () {
                  _groupClick(index);
                },
              ),
            ),
          ),
          ClipPath(
            clipper: CurveSmall(),
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment(1, 1),
                  tileMode: TileMode.repeated,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  bottomLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(0),
                ),
              ),
            ),
          ),
          ClipPath(
            clipper: CurveBottom(),
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topRight,
                  end: Alignment(1, 1),
                  tileMode: TileMode.repeated,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  bottomLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    _isLoggedIn = await googleSignIn.isSignedIn();
    if (_isLoggedIn) {
      await googleSignIn.signOut();
    }

    _isLoggedIn = await googleSignIn.isSignedIn();
    if (!_isLoggedIn) {
      await firebaseAuth.signOut();
      _userCfg.clearUser();
      Navigator.of(context).pop();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(),
        ),
      );
    }

    /*
    var message = await UserProvider().logout(_userLogin);
    if (message != null){
      if (message.isNotEmpty){
        Toast.show(message, context, duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(),
          ),
        );
      }
    }
    */
  }

  @override
  Widget build(BuildContext context) {
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
              padding: EdgeInsets.only(left: 8.0, right: 8.0),
              child: Text(
                'Dasbor',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(top: 8.0),
              padding: EdgeInsets.only(left: 8.0, right: 8.0),
              child: Text(
                'Halo $_userName!',
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
      actions: _actionList,
    );

    final assetName = 'assets/image/destinations.svg';
    final Widget cover = SvgPicture.asset(
      assetName,
      width: MediaQuery.of(context).size.width,
      semanticsLabel: 'Destinations',
    );

    Widget _header = SliverToBoxAdapter(
      child: Center(
        child: Container(
          color: kColorPrimary,
          child: cover,
        ),
      ),
    );

    Widget _title = SliverToBoxAdapter(
      child: Center(
        child: Container(
          margin: EdgeInsets.only(top: 20.0,),
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: 8.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                child: Text(
                  'Daftar Grup',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
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
                child: Text(
                  'Daftar grup yang Anda ikuti',
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
      ),
    );

    Widget _listGroup = SliverToBoxAdapter(
      child: Center(
        child: Container(
          padding: EdgeInsets.all(10.0,),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(20.0)),
            border: Border.all(
              color: kColorBorder,
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Text('Anda belum bergabung dengan grup'),
        ),
      ),
    );

    if (_listMode == 1){
      _listGroup = SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          mainAxisExtent: 140.0,
          maxCrossAxisExtent: 360.0,
          mainAxisSpacing: 0.0,
          crossAxisSpacing: 0.0,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index)
          {
            return _itemGroup(index);
          },
          childCount: _groupIndexes.length,
        ),
      );
    }

    Widget _listMenu = SliverGrid(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        mainAxisExtent: 130.0,
        maxCrossAxisExtent: 300.0,
        mainAxisSpacing: 0.0,
        crossAxisSpacing: 0.0,
        childAspectRatio: 1.0,
      ),
      delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index)
        {
          return _itemMenu(index);
        },
        childCount: _menuIndexes.length,
      ),
    );

    var _bodyList = <Widget>[
      _appBar,
      _header,
      _listMenu,
      _title,
      _content,
      _listGroup,
    ];

    Widget _homePage = Scaffold(
      body: LayoutUI(
        screen: ScreenVO(
          template: Templates.home,
          body: _bodyList,
        ),
      ),
    );

    return _homePage;
  }
}
