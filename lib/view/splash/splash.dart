import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';
import 'package:touring/constant/constant.dart';
import 'package:touring/layout/layout.dart';
import 'package:touring/layout/model/vo/screen.dart';

class SplashPage extends StatefulWidget {
  SplashPage({Key key}) : super(key: key);

  @override
  SplashPageState createState() => SplashPageState();
}

class SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> _bodyList = [];

    String version = '1.0.0';

    Widget _item =
    Container(
      padding: EdgeInsets.only(
        top: 10,
        bottom: 10,
        left: 32,
        right: 32,
      ),
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      color: kColorPrimary,
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 140.0,
              height: 140.0,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: ExactAssetImage('assets/image/logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 10,),
            Text("VTS MOBILE",
              style: TextStyle(
                color: kColorBorder,
                fontSize: 24.0,
              ),
            ),
            FutureBuilder(
              future: PackageInfo.fromPlatform(),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasData) {
                    if (snapshot.data != null) {
                      PackageInfo packageInfo = snapshot.data;
                      version = packageInfo.version;
                      return Text("Version: " + version,
                        style: TextStyle(
                          color: kColorBorder,
                          fontSize: 12.0,
                        ),
                      );
                    }
                  }
                }
                return Text("Version: " + version,
                  style: TextStyle(
                    color: kColorBorder,
                    fontSize: 12.0,
                  ),
                );
              },
            ),
            SizedBox(height: 20,),
          ],
        ),
      ),
    );

    Widget _content = SliverList(
      delegate: SliverChildListDelegate(
        [
          _item
        ],
      ),
    );

    _bodyList.add(_content);

    return Scaffold(
      body: LayoutUI(
        screen: ScreenVO(
          template: Templates.page,
          body: _bodyList,
        ),
      ),
    );
  }
}
