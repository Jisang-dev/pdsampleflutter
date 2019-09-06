import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pdsample/main.dart';
import 'package:pdsample/change.dart';
import 'package:pdsample/temp.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdsample/init.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' show utf8, json;
import 'dart:math';

int timestamp;
int cycle = 60000;
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

  static deg2rad(degree) {
    return degree * (pi/180);
  }

  static get_harversion_distance(x1, y1) {
    // Harversion Formula 이용하여 킨텍스와 버스의 거리를 구함(단위:Km)
    if (x1 == null || y1 == null) {
      return null;
    }

    /// 킨텍스 : 37.667094, 126.743893
    // 역곡역 : 37.485470, 126.811923
    var R = 6371; // 지구의 반경(단위: km)
    var dLat = deg2rad(x1 - 37.667094);
    var dLng = deg2rad(y1 - 126.743893);

    var a = sin(dLat/2) * sin(dLat/2) + (cos(deg2rad(x1)) * cos(deg2rad(37.667094)) * sin(dLng/2) * sin(dLng/2));
    var b = 2 * R * atan2(sqrt(a), sqrt(1-a));
    return b;
  }
}

Map<String, dynamic> dataInt = new Map();

class Send1App extends StatefulWidget {
  Send1App(String com) {
    commit = com;
    dataInt['첫째날(금) 09-13'] = 0;
    dataInt['둘째날(토) 09-14'] = 1;
    dataInt['셋째날(일) 09-15'] = 2;
  }

  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<Send1App> with TickerProviderStateMixin {
  bool _isLoading = false;
  SharedPreferences prefs;
  StreamSubscription<LocationData> streamListen;

  Map<String, dynamic> info;
  Map<String, dynamic> summary;
  String type;

  bool confirm1 = false;
  bool confirm2 = false;
  bool confirm3 = false;
  bool confirm4 = false;

  AnimationController _animationController;

  String _commitDate = commit;

  Location location;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  static const platform = const MethodChannel('sample.hyla981020.com/bg');

  int _count = 0;

  Future<void> _setBackground() async { // for iOS and androidOS
    _count = 0;
    try {
      await platform.invokeMethod('initLocation');
    } on Exception catch (e) {
      print(e.toString());
    }
  }

  void currentUser() async {
    prefs = await SharedPreferences.getInstance();
    await _summary().then((data) {
      if (data != null && data['ok']) {
        setState(() {
          print(data);
          summary = data;
          type = (summary == null) ? "" :
          summary['bus_target_code'][0] == 21 && summary['bus_target_code'][1] == 11 ? "금" :
          summary['bus_target_code'][0] == 22 && summary['bus_target_code'][1] == 11 ? "금A" :
          summary['bus_target_code'][0] == 11 && summary['bus_target_code'][1] == 21 ? "토" :
          summary['bus_target_code'][0] == 11 && summary['bus_target_code'][1] == 22 ? "토A" :
          summary['bus_target_code'][0] == 12 && summary['bus_target_code'][1] == 12 ? "일" :
          summary['bus_target_code'][0] == 11 && summary['bus_target_code'][1] == 11 ? "'1' 구역" :
          summary['bus_target_code'][0] == 21 && summary['bus_target_code'][1] == 21 ? "'2' 구역" :
          summary['bus_target_code'][0] == 41 && summary['bus_target_code'][1] == 41 ? "해외/국내 대표단" : "중국어 대회";
        });
      }
    });
    await _user().then((data) async {
      if (data != null && data['ok']) {
        setState(() {
          info = data['bus_info'];
        });

        if (info['bus_step'] >= Step.DEPARTURE_TERMINAL) {
          setState(() {
            confirm1 = confirm2 = confirm3 = confirm4 = true;
          });
        } else if (info['bus_step'] == Step.DEPARTURE_CP_2) {
          setState(() {
            confirm1 = confirm2 = confirm3 = true;
          });
          if (Platform.isAndroid) {
            cycle = 5000;
            _count = 0;
          } else {
            try {
              await platform.invokeMethod('cp2'); // 아이폰 주기 관리
            } on Exception catch (e) {
              print(e.toString());
            }
          }
        } else if (info['bus_step'] == Step.DEPARTURE_CP_1) {
          setState(() {
            confirm1 = confirm2 = true;
          });
          if (Platform.isAndroid) {
            cycle = 30000;
            _count = 0;
          } else {
            try {
              await platform.invokeMethod('cp1'); // 아이폰 주기 관리
            } on Exception catch (e) {
              print(e.toString());
            }
          }
        } else if (info['bus_step'] == Step.DEPARTURE_START) {
          setState(() {
            confirm1 = true;
          });
          if (Platform.isAndroid) {
            cycle = 60000;
            _count = 0;
          } else {
            try {
              await platform.invokeMethod('start'); // 아이폰 주기 관리
            } on Exception catch (e) {
              print(e.toString());
            }
          }
        }
      }
    });
  }

  @override
  void initState() {
    _animationController = new AnimationController(vsync: this, duration: Duration(seconds: 1));
    _animationController.repeat();
    super.initState();
    if (Platform.isAndroid) {
      location = new Location();
      location.requestPermission();
      streamListen = location.onLocationChanged().listen((LocationData currentLocation) {}); // 초기 gps 설정
      cycle = 60000;
    }
    currentUser();
    timestamp = (Platform.isAndroid ? DateTime.now().millisecondsSinceEpoch : 0);

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print('on message $message');
        await alertMessage();
        currentUser();
      },
      onResume: (Map<String, dynamic> message) async {
        print('on resume $message');
        currentUser();
      },
      onLaunch: (Map<String, dynamic> message) async {
        print('on launch $message');
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
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> alertMessage() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("진행상태가 갱신되었습니다."),
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

  void background(String latlang) async {
    var latlng = latlang.split(",");
    await fetchPost(prefs.getString("token"), (double.parse(latlng[0])*1000000).toInt(), (double.parse(latlng[1])*1000000).toInt()).then((post) async {
      if (post.ok) {
        print("success");
        if (!confirm3 && Step.get_harversion_distance(double.parse(latlng[0]), double.parse(latlng[1])) < 5) {
          setState(() {
            confirm1 = confirm2 = confirm3 = true;
          });
          try {
            await platform.invokeMethod('cp2'); // 아이폰 주기 관리
          } on Exception catch (e) {
            print(e.toString());
          }
        } else if (!confirm2 && Step.get_harversion_distance(double.parse(latlng[0]), double.parse(latlng[1])) < 20) {
          setState(() {
            confirm1 = confirm2 = true;
          });
          try {
            await platform.invokeMethod('cp1'); // 아이폰 주기 관리
          } on Exception catch (e) {
            print(e.toString());
          }
        }
      } else {
        print(post.reason);
      }
    });
  }

  Future<Init> fetchPost(String _token, int latitude, int longitude) async {
    final response = await http.post (
      "https://ip2019.tk/guide/api/location",
      body: json.encode({
        "token" : _token,
        "lat": latitude,
        "lng": longitude,
      }),
      headers: {
        "content-type" : "application/json",
        "accept" : "application/json",
      },
    );
    return Init.fromJson(json.decode(response.body));
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
    if (Platform.isAndroid) {
      if (streamListen != null) { streamListen.cancel(); }
      location = null;
    }
    Navigator.pushReplacement(
      context,
      new MaterialPageRoute(
          builder: (BuildContext context) => new MyApp()
      ),
    );
    try {
      await platform.invokeMethod('stop');
    } on Exception catch (e) {
      e.toString();
    }
  }

  void _change() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChangeApp()),
    );
  }

  void sample() async {
    if (location == null) {
      location = new Location();
    }
    if (streamListen != null) { streamListen.cancel(); }
//    await location.changeSettings(distanceFilter: 400, accuracy: LocationAccuracy.BALANCED);
    if (await location.requestPermission()) {
      streamListen = location.onLocationChanged().listen((LocationData currentLocation) async {
        if (currentLocation.time.toInt() > _count * cycle + timestamp) {
          await fetchPost(prefs.getString("token"), (currentLocation.latitude*1000000).toInt(), (currentLocation.longitude*1000000).toInt()).then((post) {
            if (post.ok) {
              print("success");
              if (!confirm3 && Step.get_harversion_distance(currentLocation.latitude, currentLocation.longitude) < 5) {
                setState(() {
                  confirm1 = confirm2 = confirm3 = true;
                });
                cycle = 5000;
                _count = 0;
              } else if (!confirm2 && Step.get_harversion_distance(currentLocation.latitude, currentLocation.longitude) < 20) {
                setState(() {
                  confirm1 = confirm2 = true;
                });
                cycle = 30000;
                _count = 0;
              }
            } else {
              print(post.reason);
            }
          });
          _count++;
          if (_count < (currentLocation.time.toInt() - timestamp) ~/ cycle) {
            _count = (currentLocation.time.toInt() - timestamp) ~/ cycle;
          }
        }
      });
    }
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

  Future<Map<String, dynamic>> _summary() async {
    prefs = await SharedPreferences.getInstance();
    final response = await http.get (
      "https://ip2019.tk/guide/api/summary?token=" + prefs.getString("token"),
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
        title: '오전 화면',
        theme: ThemeData(
          primaryColor: Colors.green[900],
          bottomAppBarColor: Colors.grey[300],
        ),
        home: Scaffold(
          appBar: new AppBar(
            // Here we take the value from the MyHomePage object that was created by
            // the App.build method, and use it to set our appbar title.
            title: new Text("SIC2019 주차 지원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,),),
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
            child: (info != null && summary != null) ?
            ListView(
              // Important: Remove any padding from the ListView.
              padding: EdgeInsets.zero,
              children: <Widget>[
                Container(
                  height: 90.0,
                  child: DrawerHeader(
                    child:  Text("SIC2019 주차 지원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),),
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
                  child: Text((info['bus_name'] ?? "") + "\n" + "버스 " + summary['bus_total'].toString() + "대 중 " + summary['bus_index'].toString() + "호차\n" + (info['bus_guide_name'] ?? "") + "\n" + (info['bus_guide_phone'] ?? "")),
                ),
                Container(
                  color: Colors.grey[300],
                  padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
                  child: Text("첫째날(금요일)\n    오전: " + summary['bus_target'][0] + "\n    오후: " + summary['bus_return'][0] + "\n\n"
                      + "둘째날(토요일)\n    오전: " + summary['bus_target'][1] + "\n    오후: " + summary['bus_return'][1] + "\n\n"
                      + "셋째날(일요일)\n    오전: " + summary['bus_target'][2] + "\n    오후: " + summary['bus_return'][2]),
                ),
                ListTile(
                  title: Text('버스 인솔자용 파일: ' + type, style: TextStyle(fontWeight: FontWeight.bold),),
                  leading: Icon(Icons.insert_drive_file),
                ),
                Container(
                  color: Colors.grey[100],
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: GestureDetector(
                    onTap: () async {
                      String url =
                      summary['bus_target_code'][0] == 21 && summary['bus_target_code'][1] == 11 ? "https://drive.google.com/file/d/17PGJjwb9qQ-if7FvL_ZsrHpeSO8nOn-L/view" :
                      summary['bus_target_code'][0] == 22 && summary['bus_target_code'][1] == 11 ? "https://drive.google.com/file/d/12xa0copHjNNmCa_x1ncBDMujFd4QxLM0/view" :
                      summary['bus_target_code'][0] == 11 && summary['bus_target_code'][1] == 21 ? "https://drive.google.com/file/d/1jur9t1AlcRkdlEIN38JFU30-YmeL2XOC/view" :
                      summary['bus_target_code'][0] == 11 && summary['bus_target_code'][1] == 22 ? "https://drive.google.com/file/d/1F1-LhjS3QqVWxEjzT89SIVB5O95gG-xo/view" :
                      summary['bus_target_code'][0] == 12 && summary['bus_target_code'][1] == 12 ? "https://drive.google.com/file/d/120PXgkzdUpFRsgacsu4zSq_YdPozHmYB/view" :
                      summary['bus_target_code'][0] == 11 && summary['bus_target_code'][1] == 11 ? "https://drive.google.com/file/d/1Ikv4bp79ipY35dRa5ufQPVccJDhMGy34/view" :
                      summary['bus_target_code'][0] == 21 && summary['bus_target_code'][1] == 21 ? "https://drive.google.com/file/d/1ID7pjflNW_zKS0Nwmo6CGziHkLqLf9ju/view" :
                      summary['bus_target_code'][0] == 31 && summary['bus_target_code'][1] == 31 ? "https://drive.google.com/file/d/1iNZpN9-nE8wkDe8HOCcUpfBb_ILeGjOR/view" :
                      summary['bus_target_code'][0] == 41 && summary['bus_target_code'][1] == 41 ? "https://drive.google.com/file/d/1P3ysjLbv9M9WC7bCCDGYxyceIlO1nDv9/view" : "https://drive.google.com/file/d/1Ikv4bp79ipY35dRa5ufQPVccJDhMGy34/view";
                      if (Platform.isAndroid) {
                        if (await canLaunch(url)) {
                          await launch(
                            url,
                            forceSafariVC: true,
                            forceWebView: true,
                            enableJavaScript: true,
                          );
                        }
                      } else {
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
                    child: Text("PDF 파일 (클릭 시 사이트로 이동)", style: TextStyle(color: Colors.blue,),),
                  ),
                ),
                Platform.isAndroid ? Container(
                  color: Colors.grey[100],
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: GestureDetector(
                    onTap: () async {
                      String url =
                      summary['bus_target_code'][0] == 21 && summary['bus_target_code'][1] == 11 ? "https://drive.google.com/uc?authuser=0&id=17PGJjwb9qQ-if7FvL_ZsrHpeSO8nOn-L&export=download" :
                      summary['bus_target_code'][0] == 22 && summary['bus_target_code'][1] == 11 ? "https://drive.google.com/uc?authuser=0&id=12xa0copHjNNmCa_x1ncBDMujFd4QxLM0&export=download" :
                      summary['bus_target_code'][0] == 11 && summary['bus_target_code'][1] == 21 ? "https://drive.google.com/uc?authuser=0&id=1jur9t1AlcRkdlEIN38JFU30-YmeL2XOC&export=download" :
                      summary['bus_target_code'][0] == 11 && summary['bus_target_code'][1] == 22 ? "https://drive.google.com/uc?authuser=0&id=1F1-LhjS3QqVWxEjzT89SIVB5O95gG-xo&export=download" :
                      summary['bus_target_code'][0] == 12 && summary['bus_target_code'][1] == 12 ? "https://drive.google.com/uc?authuser=0&id=120PXgkzdUpFRsgacsu4zSq_YdPozHmYB&export=download" :
                      summary['bus_target_code'][0] == 11 && summary['bus_target_code'][1] == 11 ? "https://drive.google.com/uc?authuser=0&id=1Ikv4bp79ipY35dRa5ufQPVccJDhMGy34&export=download" :
                      summary['bus_target_code'][0] == 21 && summary['bus_target_code'][1] == 21 ? "https://drive.google.com/uc?authuser=0&id=1ID7pjflNW_zKS0Nwmo6CGziHkLqLf9ju&export=download" :
                      summary['bus_target_code'][0] == 31 && summary['bus_target_code'][1] == 31 ? "https://drive.google.com/uc?authuser=0&id=1iNZpN9-nE8wkDe8HOCcUpfBb_ILeGjOR&export=download" :
                      summary['bus_target_code'][0] == 41 && summary['bus_target_code'][1] == 41 ? "https://drive.google.com/uc?authuser=0&id=1P3ysjLbv9M9WC7bCCDGYxyceIlO1nDv9&export=download" : "https://drive.google.com/uc?authuser=0&id=1Ikv4bp79ipY35dRa5ufQPVccJDhMGy34&export=download";
                      if (Platform.isAndroid) {
                        if (await canLaunch(url)) {
                          await launch(
                            url,
                            enableJavaScript: true,
                          );
                        }
                      } else {
                        try {
                          await launch(
                            url,
                            enableJavaScript: true,
                          );
                        } catch (e) {
                          print(e.toString());
                        }
                      }
                    },
                    child: Text("PDF 파일 (클릭 시 기기 다운로드)", style: TextStyle(color: Colors.blue,),),
                  ),
                ) : Container(),
                Container(
                  padding: EdgeInsets.fromLTRB(50, 50, 50, 0),
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
                    child:  Text("SIC2019 주차 지원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),),
                    decoration: BoxDecoration(
                      color: Colors.green[900],
                    ),
                  ),
                ),
                Text("접근 권한 오류", textAlign: TextAlign.center,),
                Container(
                  padding: EdgeInsets.fromLTRB(50, 0, 50, 0),
                  child: RaisedButton(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: currentUser,
                    child: new Text('새로고침',
                        style: new TextStyle(fontSize: 20.0, color: Colors.green[900])),
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
            child: Text(_commitDate + " 오전", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900]), ),
          ),
          (info != null) ? Container(
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text((info['bus_name'] ?? "") + "/" + (info['bus_guide_name'] ?? "") + "/" + (info['bus_guide_phone'] ?? ""), style: TextStyle(fontSize: 13.0),),
                ),
                Container(
                  alignment: Alignment.centerRight,
                  child: ButtonTheme(
                    minWidth: 10.0,
                    height: 1,
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
                    height: 1,
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
          (info != null && summary != null) ? Container(
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text("터미널(주차장) 정보", style: TextStyle(fontSize: 14.0,),),
                ),
                Expanded(
                  child: Text(summary['bus_target'][dataInt[_commitDate] ?? "오류"], style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.pink),),
                ),
                Container(
                  alignment: Alignment.centerRight,
                  child: ButtonTheme(
                    minWidth: 10.0,
                    height: 1,
                    child: RaisedButton(
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      color: Colors.blue,
                      onPressed: _map,
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
          new SizedBox(
            height: 12.0,
            child: new Center(
              child: new Container(
                height: 12.0,
                color: Colors.green[900],
              ),
            ),
          ),
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            child: Text("버스 이용 확인", style: TextStyle(fontWeight: FontWeight.bold,),),
          ),
          depart(),
          (confirm1 && !confirm4) ? FadeTransition(
            opacity: _animationController,
            child: Icon(Icons.arrow_downward, color:  Colors.yellow[900],),
          ) : Container(
            child: Icon(Icons.arrow_downward, color: !confirm4 ?  Colors.red[900] : Colors.green[900],),
          ),
          terminalArrive(),
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
          title: Text("출발", style: TextStyle(fontSize: 20),),
          subtitle: Text("버스가 출발하였을 때 누릅니다. \nGPS가 켜져있는지도 확인해주세요.",),
          onTap: () {
            !confirm1 ? alert("버스가 출발하였습니까?", 1) : alert("버스가 출발하지 않았습니까?", 6);
          },
        ),
      ),
    );
  }

  Widget terminalArrive() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        color: !confirm4 ? Colors.grey[100] : Colors.orange[200],
        child: ListTile(
          dense: true,
          leading: Icon(Icons.looks_two, color: !confirm4 ? Colors.red : Colors.green,),
          title: Text("주차장 도착, 앱 종료", style: TextStyle(fontSize: 20),),
          subtitle: Text("버스가 주차장에 도착하였을 때 누릅니다.",),
          onTap: () {
            !confirm4 ? alert("버스가 주차장에 정차하였습니까?", 4) : alert("버스가 아직 주차장에 정차하지 않았습니까?", 9);
          },
        ),
      ),);
  }

  Widget finish() {
    return ListTile(
      title: confirm4 ? Text("수고하셨습니다!", style: TextStyle(fontSize: 14), textAlign: TextAlign.center,) : null,
    );
  }

  void _map() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Maps(title: summary["bus_target_code"][dataInt[_commitDate]] ?? 0,)), /// 터미널에 따라 지도 모양 다르게
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

  Future<void> network() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("네트워크 오류"),
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

  void _terminate() {
    Navigator.pushReplacement(
      context,
      new MaterialPageRoute(
          builder: (BuildContext context) => new TerminateApp()
      ),
    );
  }

  Future<void> terminate() async {
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
                _terminate();
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
                    status(prefs.getString("token"), "start").then((post) {
                      if (post.ok) {
                        setState(() {
                          confirm1 = true;
                          _isLoading = false;
                        });
                        platform.setMethodCallHandler((call) {
                          if (call.method == "background") {
                            background(call.arguments);
                          }
                        });
                        if (Platform.isAndroid) {
                          sample();
                        }
                        _setBackground();
                        success();
                      } else {
                        setState(() {
                          _isLoading = false;
                        });
                        network();
                      }
                    }).catchError((e) {
                      print(e.toString());
                      setState(() {
                        _isLoading = false;
                      });
                      network();
                    });
                    setState(() {
                      _isLoading = false;
                    });
                    break;
                  case 4:
                    if (confirm1) {
                      status(prefs.getString("token"), "end").then((post) {
                        if (post.ok) {
                          setState(() {
                            confirm4 = true;
                            _isLoading = false;
                          });
                          if (Platform.isAndroid) {
                            if (streamListen != null) { streamListen.cancel(); }
                            location = null;
                          }
                          try {
                            platform.invokeMethod('stop'); // await
                          } on Exception catch (e) {
                            e.toString();
                          }
                          terminate();
                        } else {
                          setState(() {
                            _isLoading = false;
                          });
                          network();
                        }
                      }).catchError((e) {
                        print(e.toString());
                        setState(() {
                          _isLoading = false;
                        });
                        network();
                      });
                    } else {
                      confirm();
                      setState(() {
                        _isLoading = false;
                      });
                    }
                    setState(() {
                      _isLoading = false;
                    });
                    break;
                  case 6:
                    if (!confirm4) {
                      status(prefs.getString("token"), "dReady").then((post) {
                        if (post.ok) {
                          setState(() {
                            confirm1 = false;
                            _isLoading = false;
                          });
                          if (Platform.isAndroid) {
                            if (streamListen != null) { streamListen.cancel(); }
                            location = null;
                          }
                          try {
                            platform.invokeMethod('stop'); // await
                          } on Exception catch (e) {
                            e.toString();
                          }
                          success();
                        } else {
                          setState(() {
                            _isLoading = false;
                          });
                          network();
                        }
                      }).catchError((e) {
                        print(e.toString());
                        setState(() {
                          _isLoading = false;
                        });
                        network();
                      });
                    } else {
                      confirm02();
                      setState(() {
                        _isLoading = false;
                      });
                    }
                    setState(() {
                      _isLoading = false;
                    });
                    break;
                  case 9:
                    status(prefs.getString("token"), "start").then((post) {
                      if (post.ok) {
                        setState(() {
                          confirm4 = false;
                          _isLoading = false;
                        });
                        platform.setMethodCallHandler((call) {
                          if (call.method == "background") {
                            background(call.arguments);
                          }
                        });
                        if (Platform.isAndroid) {
                          sample();
                        }
                        _setBackground();
                        success();
                      } else {
                        setState(() {
                          _isLoading = false;
                        });
                        network();
                      }
                    }).catchError((e) {
                      print(e.toString());
                      setState(() {
                        _isLoading = false;
                      });
                      network();
                    });
                    setState(() {
                      _isLoading = false;
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
          title: Text('SIC2019 주차 지원', style: TextStyle(fontWeight: FontWeight.bold,),),
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
          title: Text('SIC2019 주차 지원', style: TextStyle(fontWeight: FontWeight.bold,),),
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
