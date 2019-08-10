import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdsample/store.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pdsample/main.dart';
import 'package:pdsample/change.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdsample/init.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' show utf8, json;

String commit;

Future<Post> updateToken(String _token, String notification) async {
  final response = await http.post (
    "https://ip2019.tk/guide/api/notification",
    body: json.encode({
      "token" : _token,
      "notification": notification,
    }),
    headers: {
      "content-type" : "application/json",
      "accept" : "application/json",
    },
  );
  return Post.fromJson(json.decode(response.body));
}

class Step {
  static const DEPARTURE_INFO_REQUEST = 0;
  static const DEPARTURE_READY = 10;
  static const DEPARTURE_START = 11;
  static const DEPARTURE_CP_1 = 12;
  static const DEPARTURE_CP_2 = 13;
  static const DEPARTURE_TERMINAL = 14;
  static const DEPARTURE_END = 15;

  static const RETURN_REQUEST = 20;
  static const RETURN_READY = 21;
  static const RETURN_CALL = 22;
  static const RETURN_TERMINAL = 23;
  static const RETURN_RIDE = 24;
  static const RETURN_END = 24;
}

class ReceiveApp extends StatefulWidget {
  ReceiveApp(String com) {
    commit = com;
  }

  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<ReceiveApp> with TickerProviderStateMixin {
  String _email = "temporary10@pdsample.com"; // 계정 이름
  bool _isLoading = false;

  bool confirm1 = false;
  bool confirm2 = false;
  bool confirm3 = false;
  bool confirm4 = false;

  AnimationController _animationController;

  Timeline _timeline = Timeline.afternoon;
  String _commitDate = commit;

  Location location;

  SharedPreferences prefs;

  Map<String, dynamic> info;

  Widget circle = Center(child: CircularProgressIndicator());


  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  static const platform = const MethodChannel('sample.hyla981020.com/bg');

  int _count = 0;

  void currentUser() async {
    prefs = await SharedPreferences.getInstance();
    await _user().then((data) async {
      if (data != null && data['ok']) {
        setState(() {
          info = data['bus_info'];
        });
        await Firestore.instance.collection('01').document(_email).get().then((data) { /// firebase에서 call 정보 확인 (서버 통합 시 없어질 함수)
          final cell = Cell.fromSnapshot(data);
          confirm2 = cell.access;
          if (confirm2) {
            setState(() {
              confirm2 = confirm1 = true;
            });
          }
        });
        if (info['bus_step'] == Step.RETURN_END || info['bus_step'] == Step.RETURN_RIDE) {
          confirm1 = confirm2 = confirm3 = confirm4 = true;
        } else if (info['bus_step'] == Step.RETURN_TERMINAL) {
          confirm1 = confirm2 = confirm3 = true;
        } else if (info['bus_step'] == Step.RETURN_CALL) { /// firebase에서 python 자체 서버로 꼭 끄집어내기
          confirm1 = confirm2 = true;
        } else if (info['bus_step'] == Step.RETURN_READY) {
          print('confirm1');
          confirm1 = true;
        }
      }
    });
  }

  @override
  void initState() {
    _animationController = new AnimationController(vsync: this, duration: Duration(seconds: 1));
    _animationController.repeat();
    super.initState();
    currentUser();

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print('on message $message');
        await alertMessage();
        await Firestore.instance.collection('01').document(_email).get().then((data) {
          final cell = Cell.fromSnapshot(data);
          confirm2 = cell.access;
          if (confirm2) {
            setState(() {
              confirm2 = confirm1 = true;
            });
          }
        });
        currentUser();
      },
      onResume: (Map<String, dynamic> message) async {
        print('on resume $message');
        await Firestore.instance.collection('01').document(_email).get().then((data) {
          final cell = Cell.fromSnapshot(data);
          confirm2 = cell.access;
          if (confirm2) {
            setState(() {
              confirm2 = confirm1 = true;
            });
          }
        });
        currentUser();
      },
      onLaunch: (Map<String, dynamic> message) async {
        print('on launch $message');
        await Firestore.instance.collection('01').document(_email).get().then((data) {
          final cell = Cell.fromSnapshot(data);
          confirm2 = cell.access;
          if (confirm2) {
            setState(() {
              confirm2 = confirm1 = true;
            });
          }
        });
        currentUser();
      },
    );
    _firebaseMessaging.requestNotificationPermissions(
        const IosNotificationSettings(
          alert: true,
          badge: true,
          sound: true,
        )
    );
    _firebaseMessaging.onIosSettingsRegistered.listen((IosNotificationSettings settings) {
      print("Ios Setting Registed");
    });
    _firebaseMessaging.getToken().then((token) async {
      print(token);
      prefs = await SharedPreferences.getInstance();
      await updateToken(prefs.getString('token'), token).then((post) {
        if (post.ok) {
          print(post.ok);
        } else {
          print(post.reason);
        }
      }).catchError((e) {
        print(e.toString());
      });
      Firestore.instance.collection('01').document(_email).get().then((data) {
        final cell = Cell.fromSnapshot(data);
        Firestore.instance.runTransaction((transaction) async {
          await transaction
              .update(cell.reference, {'token': token});
        });
      });
    });
  }

  Future<Init> status(String _token, String _status) async {
    final response = await http.post (
      "https://ip2019.tk/guide/api/status",
      body: json.encode({
        "token" : _token,
        "status": _status,
      }),
      headers: {
        "content-type" : "application/json",
        "accept" : "application/json",
      },
    );
    return Init.fromJson(json.decode(response.body));
  }

  void logout() async {
    await prefs.setString('id', null);
    await prefs.setString('pw', null);
    await prefs.setString('token', null);
    Navigator.pushReplacement(
      context,
      new MaterialPageRoute(
          builder: (BuildContext context) => new MyApp()
      ),
    );
  }

  void _change() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChangeApp()),
    );
  }

  Future<Map<String, dynamic>> _user() async {
    prefs = await SharedPreferences.getInstance();
    final response = await http.get (
      "https://ip2019.tk/guide/api?token=" + prefs.getString("token"),
      headers: {
        "content-type" : "application/json",
        "accept" : "application/json",
      },
    );
    return json.decode(utf8.decode(response.bodyBytes));
  }

  Widget _showCircularProgress() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    return Container(height: 0.0, width: 0.0,);
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: '오후 화면',
        theme: ThemeData(
        primaryColor: Colors.green[900],
        bottomAppBarColor: Colors.grey[300],
    ),
    home: Scaffold(
      appBar: new AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: new Text("2019SIC 주차 지원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,),),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              currentUser();
            },
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          _showBody(),
          _showCircularProgress()

        ],
      ),
      drawer: Drawer(
        // Add a ListView to the drawer. This ensures the user can scroll
        // through the options in the drawer if there isn't enough vertical
        // space to fit everything.
        child: (info != null) ?
        ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              height: 90.0,
              child: DrawerHeader(
                child:  Text("2019SIC 주차 지원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),),
                decoration: BoxDecoration(
                  color: Colors.green[900],
                ),
              ),
            ),
            ListTile(
              title: Text('내 정보', style: TextStyle(fontWeight: FontWeight.bold),),
              leading: Icon(Icons.account_box),
            ),
            Container(
              color: Colors.grey[100],
              padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
              child: Text((info['bus_name'] ?? "") + "\n" + "버스 n대 중 1호차" + "\n" + (info['bus_guide_name'] ?? "") + "\n" + (info['bus_guide_phone'] ?? "")),
            ),
            Container(
              color: Colors.grey[300],
              padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
              child: Text("첫째날(금요일) - 1전시장 터미널" + "\n" + "둘째날(토요일) - 2전시장 터미널" + "\n" + "셋째날(일요일) - 1전시장 터미널"),
            ),
            ListTile(
              title: Text('주차장 (준비중)', style: TextStyle(fontWeight: FontWeight.bold),),
              leading: Icon(Icons.flag),
            ),
            Container(
              color: Colors.grey[100],
              padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GestureDetector(
                    onTap: () async {
                      String url;
                      if (Platform.isAndroid) {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        if (await canLaunch(url)) {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        }
                      } else {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        try {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        } catch (e) {
                          print(e.toString());
                        }
                      }
                    },
                    child: Text("1전시장 터미널", style: TextStyle(color: Colors.blue),),
                  ),
                  GestureDetector(
                    onTap: () async {
                      String url;
                      if (Platform.isAndroid) {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        if (await canLaunch(url)) {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        }
                      } else {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        try {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        } catch (e) {
                          print(e.toString());
                        }
                      }
                    },
                    child: Text("1전시장 주차장 내부", style: TextStyle(color: Colors.blue),),
                  ),
                  GestureDetector(
                    onTap: () async {
                      String url;
                      if (Platform.isAndroid) {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        if (await canLaunch(url)) {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        }
                      } else {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        try {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        } catch (e) {
                          print(e.toString());
                        }
                      }
                    },
                    child: Text("2전시장 터미널", style: TextStyle(color: Colors.blue),),
                  ),
                  GestureDetector(
                    onTap: () async {
                      String url;
                      if (Platform.isAndroid) {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        if (await canLaunch(url)) {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        }
                      } else {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        try {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        } catch (e) {
                          print(e.toString());
                        }
                      }
                    },
                    child: Text("외부", style: TextStyle(color: Colors.blue),),
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('앱 사용법 (준비중)', style: TextStyle(fontWeight: FontWeight.bold),),
              leading: Icon(Icons.announcement),
            ),
            Container(
              color: Colors.grey[100],
              padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GestureDetector(
                    onTap: () async {
                      String url;
                      if (Platform.isAndroid) {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        if (await canLaunch(url)) {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        }
                      } else {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        try {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        } catch (e) {
                          print(e.toString());
                        }
                      }
                    },
                    child: Text("대회장으로", style: TextStyle(color: Colors.blue),),
                  ),
                  GestureDetector(
                    onTap: () async {
                      String url;
                      if (Platform.isAndroid) {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        if (await canLaunch(url)) {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        }
                      } else {
                        url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                        try {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        } catch (e) {
                          print(e.toString());
                        }
                      }
                    },
                    child: Text("집으로", style: TextStyle(color: Colors.blue),),
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('참고', style: TextStyle(fontWeight: FontWeight.bold),),
              leading: Icon(Icons.insert_drive_file),
            ),
            Container(
              color: Colors.grey[100],
              padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GestureDetector(
                    onTap: () async {
                      String url;
                      if (Platform.isAndroid) {
                        url = "https://jw2019.org";
                        if (await canLaunch(url)) {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        }
                      } else {
                        url = "https://jw2019.org";
                        try {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        } catch (e) {
                          print(e.toString());
                        }
                      }
                    },
                    child: Text("jw2019.org", style: TextStyle(color: Colors.blue),),
                  ),
                  GestureDetector(
                    onTap: () async {
                      String url;
                      if (Platform.isAndroid) {
                        url = "https://blog.naver.com/hyla981020/221612010974";
                        if (await canLaunch(url)) {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        }
                      } else {
                        url = "https://blog.naver.com/hyla981020/221612010974";
                        try {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        } catch (e) {
                          print(e.toString());
                        }
                      }
                    },
                    child: Text("개인정보처리방침", style: TextStyle(color: Colors.blue),),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(50, 0, 50, 0),
              child: RaisedButton(
                color: Colors.green[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: logout,
                child: new Text('로그아웃',
                    style: new TextStyle(fontSize: 20.0, color: Colors.white)),
              ),
            ),
            Row(
                children: <Widget>[
                  Expanded(
                      child: Divider(height: 5, color: Colors.black,)
                  ),
                ]
            ),
            Container(
              padding: EdgeInsets.fromLTRB(50, 0, 50, 0),
              child: RaisedButton(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  _change();
                },
                child: new Text('비밀번호 변경',
                    style: new TextStyle(fontSize: 20.0, color: Colors.green[900])),
              ),
            ),
          ],
        )
            : ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              height: 90.0,
              child: DrawerHeader(
                child:  Text("2019SIC 주차 지원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),),
                decoration: BoxDecoration(
                  color: Colors.green[900],
                ),
              ),
            ),
            Text("접근 권한 오류", textAlign: TextAlign.center,),
            Container(
              padding: EdgeInsets.fromLTRB(50, 0, 50, 0),
              child: RaisedButton(
                color: Colors.green[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: logout,
                child: new Text('로그아웃',
                    style: new TextStyle(fontSize: 20.0, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    )
    );
  }

  Widget _showBody(){
    return new Container(
      padding: EdgeInsets.zero,
      child: new ListView(
        shrinkWrap: true,
        children: <Widget>[
          Container(
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            child: Text(_commitDate + " 오후", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900]), ),
          ),
          (info != null) ? Container(
        padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text((info['bus_name']  ?? "")  + "/" + "차량1" + "/" + (info['bus_guide_name']  ?? "")  + "/" + (info['bus_guide_phone'] ?? "" ), style: TextStyle(fontSize: 13.0),),
            ),
            Container(
              alignment: Alignment.centerRight,
              child: ButtonTheme(
                minWidth: 10.0,
                child: RaisedButton(
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  color: Colors.green[900],
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditProfile(this)),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10.0),
                    child: Text("수정", style: TextStyle(fontSize: 10.0, color: Colors.white,),),
                  ),
                ),
              ),
            ),
          ],
        ),
      ) : Container(),
          (info != null) ? Container(
            color: Colors.grey[100],
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text("버스정보 : " + (info['bus_number'] ?? "") + " (" + (info['bus_driver_phone'] ?? "") + ")", style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),),
                ),
                Container(
                  alignment: Alignment.centerRight,
                  child: ButtonTheme(
                    minWidth: 10.0,
                    child: RaisedButton(
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      color: Colors.green[900],
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EditBus(this)),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(10.0),
                        child: Text("수정", style: TextStyle(fontSize: 10.0, color: Colors.white,),),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ) : Container(),
          (info != null) ? Container(
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text("터미널(주차장) 정보", style: TextStyle(fontSize: 14.0,),),
                ),
                Expanded(
                  child: Text("1전시장 터미널", style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.pink),),
                ),
                Container(
                  alignment: Alignment.centerRight,
                  child: ButtonTheme(
                    minWidth: 10.0,
                    child: RaisedButton(
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      color: Colors.blue,
                      onPressed: () async {
                        String url;
                        if (Platform.isAndroid) {
                          url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                          if (await canLaunch(url)) {
                            await launch(
                              url,
                              forceSafariVC: true,
                              forceWebView: true,
                              enableJavaScript: true,
                            );
                          }
                        } else {
                          url = "https://jisang-dev.github.io/hyla981020/terminal.html";
                          try {
                            await launch(
                              url,
                              forceSafariVC: true,
                              forceWebView: true,
                              enableJavaScript: true,
                            );
                          } catch (e) {
                            print(e.toString());
                          }
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(10.0),
                        child: Text("지도", style: TextStyle(fontSize: 10.0, color: Colors.white,),),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ) : Container(),
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            child: Text("버스 이용 확인", style: TextStyle(fontWeight: FontWeight.bold,),),
          ),
          depart(),
          (confirm1 && !confirm2) ? FadeTransition(
            opacity: _animationController,
            child: Icon(Icons.arrow_downward, color:  Colors.yellow[900],),
          ) : Container(
            child: Icon(Icons.arrow_downward, color: !confirm2 ?  Colors.red[900] : Colors.green[900],),
          ),
          arrive(),
          (confirm2 && !confirm3) ? FadeTransition(
            opacity: _animationController,
            child: Icon(Icons.arrow_downward, color:  Colors.yellow[900],),
          ) : Container(
            child: Icon(Icons.arrow_downward, color: !confirm3 ?  Colors.red[900] : Colors.green[900],),
          ),
          terminalArrive(),
          (confirm3 && !confirm4) ? FadeTransition(
            opacity: _animationController,
            child: Icon(Icons.arrow_downward, color:  Colors.yellow[900],),
          ) : Container(
            child: Icon(Icons.arrow_downward, color: !confirm4 ?  Colors.red[900] : Colors.green[900],),
          ),
          terminalDepart(),
          finish(),
          Text("\n\n주차 안내부 : 010-5613-1935\n\n", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey),),
        ],
      ),
    );
  }


  Widget depart() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        color: !confirm1 ? Colors.grey[100] : Colors.orange[200],
        child: ListTile(
          dense: true,
          leading: Icon(Icons.looks_one, color: !confirm1 ? Colors.red : Colors.green,),
          title: Text("준비 완료, 출발 요청", style: TextStyle(fontSize: 20),),
          subtitle: Text("버스 승객이 모두 모였을 경우 누릅니다.",),
          onTap: () {
            setState(() {
              !confirm1 ? alert("버스 출발을 요청하시겠습니까?", 1) : alert("버스 출발 요청을 취소하겠습니까?", 6);
            });
          },
        ),
      ),
    );
  }

  Widget arrive() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        color: !confirm2 ? Colors.grey[100] : Colors.orange[200],
        child: ListTile(
          dense: true,
          leading: Icon(Icons.looks_two, color: !confirm2 ? Colors.red : Colors.green,),
          title: Text("요청 승인, 위치 확인", style: TextStyle(fontSize: 20),),
          subtitle: Text("주차부에서 요청을 승인할 때 자동으로 켜집니다.",),
          onTap: () {
            setState(() {
              !confirm2 ? alert("주차부에서 터미널 접근을 승인하지 않았습니다. 새로고침을 눌러 다시 확인해주세요.", 4) : alert("터미널 접근이 승인되었습니다.", 9);
            });
          },
        ),
      ),
    );
  }

  Widget terminalArrive() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        color: !confirm3 ? Colors.grey[100] : Colors.orange[200],
        child: ListTile(
          dense: true,
          leading: Icon(Icons.looks_3, color: !confirm3 ? Colors.red : Colors.green,),
          title: Text("터미널도착", style: TextStyle(fontSize: 20),),
          subtitle: Text("터미널에 버스가 도착할 때 누릅니다.",),
          onTap: () {
            !confirm3 ? alert("버스가 터미널에 정차하였습니까?", 2) : alert("버스가 아직 터미널에 정차하지 않았습니까?", 7);
          },
        ),
      ),
    );
  }

  Widget terminalDepart() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        color: !confirm4 ? Colors.grey[100] : Colors.orange[200],
        child: ListTile(
          dense: true,
          leading: Icon(Icons.looks_4, color: !confirm4 ? Colors.red : Colors.green,),
          title: Text("터미널출발", style: TextStyle(fontSize: 20),),
          subtitle: Text("킨텍스를 성공적으로 떠났을 경우 누릅니다.",),
          onTap: () {
            !confirm4 ? alert("버스 승객이 모두 승차하였고, 버스가 터미널을 빠져나왔습니까?", 3) : alert("버스가 아직 터미널을 출발하지 않았습니까?", 8);
          },
        ),
      ),
    );
  }

  Widget finish() {
    return ListTile(
      title: confirm4 ? Text("수고하셨습니다!", style: TextStyle(fontSize: 14), textAlign: TextAlign.center,) : null,
    );
  }

  Future<void> confirm() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("이전 단계를 확인해주세요."),
          actions: <Widget>[
            FlatButton(
              child: Text('네'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> confirm02() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("다음 단계가 이미 실행되었습니다. 다음 단계를 먼저 확인해주세요."),
          actions: <Widget>[
            FlatButton(
              child: Text('네'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> success() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("성공적으로 처리되었습니다."),
          actions: <Widget>[
            FlatButton(
              child: Text('네'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> alertMessage() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("접근이 승인되었습니다"),
          actions: <Widget>[
            FlatButton(
              child: Text('네'),
              onPressed: () {
                Navigator.of(context).pop();
                currentUser();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> alert(String message, int process) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message),
          actions: <Widget>[
            FlatButton(
              child: Text('아니오'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text('네'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = true;
                });
                switch (process) {
                  case 1:
                    status(prefs.getString("token"), "ready").then((post) {
                      if (post.ok) {
                        setState(() {
                          confirm1 = true;
                          _isLoading = false;
                        });
                        success();
                      }
                    });
                    setState(() {
                      _isLoading = false;
                    });
                    break;
                  case 2:
                    if (confirm2) {
                      status(prefs.getString("token"), "rTerminal").then((post) {
                        if (post.ok) {
                          setState(() {
                            confirm3 = true;
                            _isLoading = false;
                          });
                          success();
                        }
                      });
                    } else {
                      confirm();
                      setState(() {
                        _isLoading = false;
                      });
                    }
                    break;
                  case 3:
                    if (confirm3) {
                      status(prefs.getString("token"), "rEnd").then((post) {
                        if (post.ok) {
                          setState(() {
                            confirm4 = true;
                            _isLoading = false;
                          });
                          success();
                        }
                      });
                    } else {
                      confirm();
                      setState(() {
                        _isLoading = false;
                      });
                    }
                    break;
                  case 6:
                    if (!confirm2) {
                      status(prefs.getString("token"), "request").then((post) {
                        if (post.ok) {
                          setState(() {
                            confirm1 = false;
                            _isLoading = false;
                          });
                          success();
                        }
                      });
                    } else {
                      confirm02();
                      setState(() {
                        _isLoading = false;
                      });
                    }
                    break;
                  case 7:
                    if (!confirm4) {
                      status(prefs.getString("token"), "ready").then((post) {
                        if (post.ok) {
                          setState(() {
                            confirm3 = false;
                            _isLoading = false;
                          });
                          success();
                        }
                      });
                    } else {
                      confirm02();
                      setState(() {
                        _isLoading = false;
                      });
                    }
                    break;
                  case 8:
                    status(prefs.getString("token"), "rTerminal").then((post) {
                      if (post.ok) {
                        setState(() {
                          confirm4 = false;
                          _isLoading = false;
                        });
                        success();
                      }
                    });
                    break;
                  default:
                    setState(() {
                      _isLoading = false;
                    });
                    break;
                }
                // 데이터 전송
              },
            ),
          ],
        );
      },
    );
  }
}

class EditProfile extends StatefulWidget {
  _MyAppState parent;

  EditProfile(this.parent);

  @override
  createState() => new Edit(this.parent);
}

class Edit extends State<EditProfile> {
  final _formKey = new GlobalKey<FormState>();
  String _guideName;
  final controller1 = TextEditingController();
  String _guideNumber;
  final controller2 = TextEditingController();
  String _busCode;
  final controller3 = TextEditingController();
  String _busNumber;
  final controller4 = TextEditingController();
  SharedPreferences prefs;

  Timeline _timeline = (new DateTime.now().hour < 12) ? Timeline.morning : Timeline.afternoon;
  String _commitDate = DateTime.now().day % 3 == 1 ? '첫째날(금) 09-13': (DateTime.now().day % 3 == 2 ? '둘째날(토) 09-14': '셋째날(일) 09-15');

  void currentUser() async {
    prefs = await SharedPreferences.getInstance();
    await _user().then((data) {
      if (data['ok']) {
        controller1.text = data['bus_info']['bus_guide_name'];
        controller2.text = data['bus_info']['bus_guide_phone'];
        _busCode = data['bus_info']['bus_number'];
        _busNumber = data['bus_info']['bus_driver_phone'];
//        controller3.text = data['bus_info']['bus_number'];
//        controller4.text = data['bus_info']['bus_driver_phone'];
      }
    });
  }

  @override
  void initState() {
    super.initState();
    currentUser();
  }

  _MyAppState parent;

  Edit(this.parent);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '초기값 입력',
      theme: ThemeData(
        primaryColor: Colors.green[900],
        bottomAppBarColor: Colors.grey[300],
      ),
      home: Scaffold(
        appBar: AppBar(
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('2019SIC 주차 지원', style: TextStyle(fontWeight: FontWeight.bold,),),
        ),
        body: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            image: DecorationImage(image: AssetImage("assets/jwmain.png"), fit: BoxFit.cover),
          ),
          child: Stack(
            children: <Widget>[
              _showBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _showBody() {
    return new Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        backgroundBlendMode: BlendMode.softLight,
        color: Colors.white,
      ),
      child: new Form(
        key: _formKey,
        child: new ListView(
          shrinkWrap: true,
          children: <Widget>[
            Text("입력값 수정", textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green[900], fontSize: 20.0, fontWeight: FontWeight.bold)
            ),
            _guideNameInput(),
            _busDriverInput(),
//            _busCodeInput(),
//            _memo(),
            _submit(),
          ],
        ),
      ),
    );
  }

  Widget _guideNameInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
      child: new TextFormField(
        controller: controller1,
        maxLines: 1,
        keyboardType: TextInputType.text,
        autofocus: true,
        decoration: new InputDecoration(
          labelText: '인솔자 이름',
        ),
        validator: (value) => value.isEmpty ? '값을 입력하세요.' : null,
        onSaved: (value) => _guideName = value,
      ),
    );
  }

  Widget _busDriverInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
      child: new TextFormField(
        controller: controller2,
        maxLines: 1,
        keyboardType: TextInputType.phone,
        autofocus: true,
        decoration: new InputDecoration(
          labelText: '인솔자 전화번호',
        ),
        validator: (value) => value.isEmpty ? '값을 입력하세요.' : null,
        onSaved: (value) => _guideNumber = value,
      ),
    );
  }

//  Widget _busCodeInput() {
//    return Padding(
//      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
//      child: new TextFormField(
//        controller: controller3,
//        maxLines: 1,
//        keyboardType: TextInputType.text,
//        autofocus: false,
//        decoration: new InputDecoration(
//          labelText: '차량 번호 (예: 12가 3456)',
//        ),
//        validator: (value) => value.isEmpty ? '값을 입력하세요.' : null,
//        onSaved: (value) => _busCode = value,
//      ),
//    );
//  }
//
//  Widget _memo() {
//    return Padding(
//      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
//      child: new TextFormField(
//        controller: controller4,
//        maxLines: 1,
//        keyboardType: TextInputType.phone,
//        autofocus: false,
//        decoration: new InputDecoration(
//          labelText: '기사 연락처',
//        ),
//        validator: (value) => value.isEmpty ? '값을 입력하세요.' : null,
//        onSaved: (value) => _busNumber = value,
//      ),
//    );
//  }

  Widget _submit() {
    return new Padding(
      padding: EdgeInsets.fromLTRB(0.0, 45.0, 0.0, 0.0),
      child: RaisedButton(
        color: Colors.green[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () {
          confirm("인솔자 이름:"+ controller1.text + "\n\n" + "인솔자 전화번호:"+ controller2.text + /*"\n\n" +  "차량 번호:"+ controller3.text + "\n\n" + "기사 연락처:"+ controller4.text + */ "\n\n" + "위 정보가 맞습니까?");
        },
        child: new Text('확인',
            style: new TextStyle(fontSize: 20.0, color: Colors.white)),
      ),
    );
  }

  Future<Map<String, dynamic>> _user() async {
    prefs = await SharedPreferences.getInstance();
    final response = await http.get (
      "https://ip2019.tk/guide/api?token=" + prefs.getString("token"),
      headers: {
        "content-type" : "application/json",
        "accept" : "application/json",
      },
    );
    return json.decode(utf8.decode(response.bodyBytes));
  }

  Future<Init> fetchPost(String _token, String _guideName, String _guideNumber, String _busCode, String _busNumber) async {
    final response = await http.post (
      "https://ip2019.tk/guide/api/info",
      body: json.encode({
        "token" : _token,
        "bus_guide_name": _guideName,
        "bus_guide_phone": _guideNumber,
        "bus_number": _busCode,
        "bus_driver_phone": _busNumber,
        "bus_day": 0, /// 매일 바뀌어야 함
      }),
      headers: {
        "content-type" : "application/json",
        "accept" : "application/json",
      },
    );
    return Init.fromJson(json.decode(response.body));
  }

  void _validateAndSubmit() async {
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();

      await fetchPost(prefs.getString('token'), _guideName, _guideNumber, _busCode, _busNumber).then((post) async {
        if (post.ok) {
          this.parent.currentUser();
          Navigator.of(context).pop();
        } else {
          await alert(post.reason != null ? post.reason : "관리자 문의");
        }
      }).catchError((e) async {
        print(e.toString());
        await alert("네트워크를 확인해주세요.");
      });
    }
  }

  Future<void> alert(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message),
          actions: <Widget>[
            FlatButton(
              child: Text('네'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> confirm(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message),
          actions: <Widget>[
            FlatButton(
              child: Text('아니오'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text('네'),
              onPressed: () {
                Navigator.of(context).pop();
                _validateAndSubmit();
              },
            ),
          ],
        );
      },
    );
  }
}

class EditBus extends StatefulWidget {
  _MyAppState parent;

  EditBus(this.parent);

  @override
  createState() => new EditB(this.parent);
}

class EditB extends State<EditBus> {
  final _formKey = new GlobalKey<FormState>();
  String _guideName;
  final controller1 = TextEditingController();
  String _guideNumber;
  final controller2 = TextEditingController();
  String _busCode;
  final controller3 = TextEditingController();
  String _busNumber;
  final controller4 = TextEditingController();
  SharedPreferences prefs;

  Timeline _timeline = (new DateTime.now().hour < 12) ? Timeline.morning : Timeline.afternoon;
  String _commitDate = DateTime.now().day % 3 == 1 ? '첫째날(금) 09-13': (DateTime.now().day % 3 == 2 ? '둘째날(토) 09-14': '셋째날(일) 09-15');

  void currentUser() async {
    prefs = await SharedPreferences.getInstance();
    await _user().then((data) {
      if (data['ok']) {
        _guideName = data['bus_info']['bus_guide_name'];
        _guideNumber = data['bus_info']['bus_guide_phone'];
        controller3.text = data['bus_info']['bus_number'];
        controller4.text = data['bus_info']['bus_driver_phone'];
      }
    });
  }

  @override
  void initState() {
    super.initState();
    currentUser();
  }

  _MyAppState parent;

  EditB(this.parent);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '초기값 입력',
      theme: ThemeData(
        primaryColor: Colors.green[900],
        bottomAppBarColor: Colors.grey[300],
      ),
      home: Scaffold(
        appBar: AppBar(
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('2019SIC 주차 지원', style: TextStyle(fontWeight: FontWeight.bold,),),
        ),
        body: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            image: DecorationImage(image: AssetImage("assets/jwmain.png"), fit: BoxFit.cover),
          ),
          child: Stack(
            children: <Widget>[
              _showBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _showBody() {
    return new Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        backgroundBlendMode: BlendMode.softLight,
        color: Colors.white,
      ),
      child: new Form(
        key: _formKey,
        child: new ListView(
          shrinkWrap: true,
          children: <Widget>[
            Text("입력값 수정", textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green[900], fontSize: 20.0, fontWeight: FontWeight.bold)
            ),
//            _guideNameInput(),
//            _busDriverInput(),
            _busCodeInput(),
            _memo(),
            _submit(),
          ],
        ),
      ),
    );
  }
//
//  Widget _guideNameInput() {
//    return Padding(
//      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
//      child: new TextFormField(
//        controller: controller1,
//        maxLines: 1,
//        keyboardType: TextInputType.text,
//        autofocus: true,
//        decoration: new InputDecoration(
//          labelText: '인솔자 이름',
//        ),
//        validator: (value) => value.isEmpty ? '값을 입력하세요.' : null,
//        onSaved: (value) => _guideName = value,
//      ),
//    );
//  }
//
//  Widget _busDriverInput() {
//    return Padding(
//      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
//      child: new TextFormField(
//        controller: controller2,
//        maxLines: 1,
//        keyboardType: TextInputType.phone,
//        autofocus: true,
//        decoration: new InputDecoration(
//          labelText: '인솔자 전화번호',
//        ),
//        validator: (value) => value.isEmpty ? '값을 입력하세요.' : null,
//        onSaved: (value) => _guideNumber = value,
//      ),
//    );
//  }

  Widget _busCodeInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
      child: new TextFormField(
        controller: controller3,
        maxLines: 1,
        keyboardType: TextInputType.text,
        autofocus: false,
        decoration: new InputDecoration(
          labelText: '버스 차량 번호 (예: 12가 3456)',
        ),
        validator: (value) => value.isEmpty ? '값을 입력하세요.' : null,
        onSaved: (value) => _busCode = value,
      ),
    );
  }

  Widget _memo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
      child: new TextFormField(
        controller: controller4,
        maxLines: 1,
        keyboardType: TextInputType.phone,
        autofocus: false,
        decoration: new InputDecoration(
          labelText: '기사 연락처',
        ),
        validator: (value) => value.isEmpty ? '값을 입력하세요.' : null,
        onSaved: (value) => _busNumber = value,
      ),
    );
  }

  Widget _submit() {
    return new Padding(
      padding: EdgeInsets.fromLTRB(0.0, 45.0, 0.0, 0.0),
      child: RaisedButton(
        color: Colors.green[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () {
          confirm(/*"인솔자 이름:"+ controller1.text + "\n\n" + "인솔자 전화번호:"+ controller2.text + "\n\n" +  */"버스 차량 번호:"+ controller3.text + "\n\n" + "기사 연락처:"+ controller4.text +  "\n\n" + "위 정보가 맞습니까?");
        },
        child: new Text('확인',
            style: new TextStyle(fontSize: 20.0, color: Colors.white)),
      ),
    );
  }

  Future<Map<String, dynamic>> _user() async {
    prefs = await SharedPreferences.getInstance();
    final response = await http.get (
      "https://ip2019.tk/guide/api?token=" + prefs.getString("token"),
      headers: {
        "content-type" : "application/json",
        "accept" : "application/json",
      },
    );
    return json.decode(utf8.decode(response.bodyBytes));
  }

  Future<Init> fetchPost(String _token, String _guideName, String _guideNumber, String _busCode, String _busNumber) async {
    final response = await http.post (
      "https://ip2019.tk/guide/api/info",
      body: json.encode({
        "token" : _token,
        "bus_guide_name": _guideName,
        "bus_guide_phone": _guideNumber,
        "bus_number": _busCode,
        "bus_driver_phone": _busNumber,
        "bus_day": 0, /// 매일 바뀌어야 함
      }),
      headers: {
        "content-type" : "application/json",
        "accept" : "application/json",
      },
    );
    return Init.fromJson(json.decode(response.body));
  }

  void _validateAndSubmit() async {
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();

      await fetchPost(prefs.getString('token'), _guideName, _guideNumber, _busCode, _busNumber).then((post) async {
        if (post.ok) {
          this.parent.currentUser();
          Navigator.of(context).pop();
        } else {
          await alert(post.reason != null ? post.reason : "관리자 문의");
        }
      }).catchError((e) async {
        print(e.toString());
        await alert("네트워크를 확인해주세요.");
      });
    }
  }

  Future<void> alert(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message),
          actions: <Widget>[
            FlatButton(
              child: Text('네'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> confirm(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message),
          actions: <Widget>[
            FlatButton(
              child: Text('아니오'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text('네'),
              onPressed: () {
                Navigator.of(context).pop();
                _validateAndSubmit();
              },
            ),
          ],
        );
      },
    );
  }
}