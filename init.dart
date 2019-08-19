// 이 화면은 초기 버스 정보값(버스기사 번호 등)을 받기 위한 화면으로 사용될 예정입니다.
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdsample/main.dart';
import 'package:pdsample/send.dart';
import 'package:pdsample/receive.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdsample/change.dart';
import 'package:package_info/package_info.dart';

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

class Post {
  final bool ok;
  final String token;
  final String reason;

  Post({this.ok, this.token, this.reason});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      ok: json['ok'],
      token: json['token'],
      reason: json['reason'],
    );
  }
}

class Init {
  final bool ok;
  final String reason;

  Init({this.ok, this.reason});

  factory Init.fromJson(Map<String, dynamic> json) {
    return Init(
      ok : json['ok'],
      reason : json['reason'],
    );
  }
}

Future<Map<String, dynamic>> version() async {
  final response = await http.get (
    "https://ip2019.tk/guide/version",
    headers: {
      "content-type" : "application/json",
      "accept" : "application/json",
    },
  );
  return json.decode(utf8.decode(response.bodyBytes));
}

class InitApp extends StatelessWidget {
// This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: '2019 국제대회 주차부',
      theme: new ThemeData(
// This is the theme of your application.
//
// Try running your application with "flutter run". You'll see the
// application has a blue toolbar. Then, without quitting the app, try
// changing the primarySwatch below to Colors.green and then invoke
// "hot reload" (press "r" in the console where you ran "flutter run",
// or press Run > Flutter Hot Reload in IntelliJ). Notice that the
// counter didn't reset back to zero; the application is not restarted.
        primaryColor: Colors.green[900],
      ),
      home: new InitPage(title: '주차부 버스 인솔자용',),
    );
  }
}

class InitPage extends StatefulWidget {
  InitPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyAppState createState() => new _MyAppState();
}

enum Timeline { morning, afternoon }

class _MyAppState extends State<InitPage> {
  final _formKey = new GlobalKey<FormState>();
  String _guideName;
  String _guideNumber;
  String _busCode;
  final controller3 = TextEditingController();
  String _busNumber;
  final controller4 = TextEditingController();
  bool _isLoading = false;

  SharedPreferences prefs;
  Map<String, dynamic> info;
  PackageInfo packageInfo;

  Timeline _timeline = (new DateTime.now().hour < 12) ? Timeline.morning : Timeline.afternoon;
  String _commitDate = DateTime.now().day % 3 == 1 ? '첫째날(금) 09-13': (DateTime.now().day % 3 == 2 ? '둘째날(토) 09-14': '셋째날(일) 09-15');

  @override
  void initState() {
    super.initState();
    currentUser();
  }

  void currentUser() async {
    prefs = await SharedPreferences.getInstance();
    packageInfo = await PackageInfo.fromPlatform();

    await version().then((data) async {
      if (data != null && data['reason'] > int.parse(packageInfo.buildNumber)) { // 최근 앱 버전 확인
        print(data['reason']);
        alertMessage();
      }
    }).catchError((e) {
      print(e.toString());
    });

    await _user().then((data) {
      if (data != null && data['ok']) {
        setState(() {
          info = data['bus_info'];
          print(info);
          _guideName = data['bus_info']['bus_guide_name'] ?? "";
          _guideNumber = data['bus_info']['bus_guide_phone'] ?? "";
          _busCode = data['bus_info']['bus_number'] ?? "";
          _busNumber = data['bus_info']['bus_driver_phone'] ?? "";
          controller3.text = data['bus_info']['bus_number'] ?? "";
          controller4.text = data['bus_info']['bus_driver_phone'] ?? "";
        });
      }
    });
  }

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
                _showCircularProgress(),
              ],
            ),
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
                child: Text("첫째날(금요일) - (준비중)" + "\n" + "둘째날(토요일) - (준비중)" + "\n" + "셋째날(일요일) - (준비중)"),
              ),
//              ListTile(
//                title: Text('앱 사용법 (준비중)', style: TextStyle(fontWeight: FontWeight.bold),),
//                leading: Icon(Icons.announcement),
//              ),
//              Container(
//                color: Colors.grey[100],
//                padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
//                child: Column(
//                  crossAxisAlignment: CrossAxisAlignment.start,
//                  children: <Widget>[
//                    GestureDetector(
//                      onTap: () async {
//                        String url;
//                        if (Platform.isAndroid) {
//                          url = "https://jisang-dev.github.io/hyla981020/terminal.html";
//                          if (await canLaunch(url)) {
//                            await launch(
//                              url,
//                              forceSafariVC: true,
//                              forceWebView: true,
//                              enableJavaScript: true,
//                            );
//                          }
//                        } else {
//                          url = "https://jisang-dev.github.io/hyla981020/terminal.html";
//                          try {
//                            await launch(
//                              url,
//                              forceSafariVC: true,
//                              forceWebView: true,
//                              enableJavaScript: true,
//                            );
//                          } catch (e) {
//                            print(e.toString());
//                          }
//                        }
//                      },
//                      child: Text("대회장으로", style: TextStyle(color: Colors.blue),),
//                    ),
//                    GestureDetector(
//                      onTap: () async {
//                        String url;
//                        if (Platform.isAndroid) {
//                          url = "https://jisang-dev.github.io/hyla981020/terminal.html";
//                          if (await canLaunch(url)) {
//                            await launch(
//                              url,
//                              forceSafariVC: true,
//                              forceWebView: true,
//                              enableJavaScript: true,
//                            );
//                          }
//                        } else {
//                          url = "https://jisang-dev.github.io/hyla981020/terminal.html";
//                          try {
//                            await launch(
//                              url,
//                              forceSafariVC: true,
//                              forceWebView: true,
//                              enableJavaScript: true,
//                            );
//                          } catch (e) {
//                            print(e.toString());
//                          }
//                        }
//                      },
//                      child: Text("집으로", style: TextStyle(color: Colors.blue),),
//                    ),
//                  ],
//                ),
//              ),
              Container(
                padding: EdgeInsets.fromLTRB(50, 200, 50, 0),
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
      ),
    );
  }

  Widget _showCircularProgress() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    return Container(height: 0.0, width: 0.0,);
  }

  Future<void> alertMessage() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("어플리케이션 업데이트가 필요합니다."),
          actions: <Widget>[
            FlatButton(
              child: Text('네'),
              onPressed: () async {
                Navigator.of(context).pop();
                String url;
                if (Platform.isAndroid) {
                  url = "https://play.google.com/store/apps/details?id=com.hyla981020.pdsample";
                  if (await canLaunch(url)) {
                    await launch(
                      url,
                      enableJavaScript: true,
                    );
                  }
                } else {
                  url = "https://testflight.apple.com/join/4TrWy4Vt";
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
            ),
          ],
        );
      },
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
            Text("기본 정보 입력", textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green[900], fontSize: 20.0, fontWeight: FontWeight.bold)
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                DropdownButton<String>(
                  items: <String>['첫째날(금) 09-13', '둘째날(토) 09-14', '셋째날(일) 09-15'].map((String value) {
                    return new DropdownMenuItem<String>(
                      value: value,
                      child: new Text(value, style: TextStyle(fontSize: 14),),
                    );
                  }).toList(),
                  value: _commitDate,
                  onChanged: (value) {
                    setState(() {
                      _commitDate = value;
                    });
                  },
                ),
                Radio(
                  value: Timeline.morning,
                  groupValue: _timeline,
                  onChanged: (Timeline value) {
                    setState(() { _timeline = value; });
                  },
                ),
                Text("오전", style: TextStyle(fontSize: 14),),
                Radio(
                  value: Timeline.afternoon,
                  groupValue: _timeline,
                  onChanged: (Timeline value) {
                    setState(() { _timeline = value; });
                  },
                ),
                Text("오후", style: TextStyle(fontSize: 14),),
              ],
            ),
            _timeline == Timeline.morning ? Container(
              child: Column(
                children: <Widget>[
                  _busCodeInput(),
                  _memo(),
                ],
              ),
            ) : Container(),
            _submit(),
            Text("\n\n주차 안내부 : 010-5613-1935", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey),),
          ],
        ),
      ),
    );
  }

  Widget _busCodeInput() {
    return Padding(
      padding: EdgeInsets.zero,
      child: new TextFormField(
        controller: controller3,
        maxLines: 1,
        keyboardType: TextInputType.text,
        autofocus: true,
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
            confirm(_commitDate + " " + (_timeline == Timeline.morning ? "오전"  + "\n\n" + "버스 차량 번호:"+ controller3.text + "\n\n" + "기사 연락처:"+ controller4.text : "오후") + "\n\n" + "위 정보가 맞습니까?");
          },
          child: new Text('확인',
              style: new TextStyle(fontSize: 20.0, color: Colors.white)),
        ),
    );
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
      MaterialPageRoute(builder: (context) => ChangeApp(title: "비밀번호 변경",)),
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

  Future<Init> fetchPost(String _token, String _guideName, String _guideNumber, String _busCode, String _busNumber, String _status) async {
    final response = await http.post (
      "https://ip2019.tk/guide/api/info",
      body: json.encode({
        "token" : _token,
        "bus_guide_name": _guideName,
        "bus_guide_phone": _guideNumber,
        "bus_number": _busCode,
        "bus_driver_phone": _busNumber,
        "status": _status,
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
    setState(() {
      _isLoading = true;
    });
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();

      await fetchPost(prefs.getString('token'), _guideName, _guideNumber, _busCode, _busNumber, _timeline == Timeline.morning ? (info['bus_step'] > Step.DEPARTURE_START && info['bus_step'] <= Step.DEPARTURE_END ? "default" : "dReady") : (info['bus_step'] > Step.RETURN_REQUEST && info['bus_step'] <= Step.RETURN_END ? "default" : "request")).then((post) async {
        if (post.ok) {
          if (_timeline == Timeline.morning) {
            Navigator.pushReplacement(
              context,
              new MaterialPageRoute(
                  builder: (BuildContext context) => new SendApp(_commitDate)
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              new MaterialPageRoute(
                  builder: (BuildContext context) => new ReceiveApp(_commitDate)
              ),
            );
          }
        } else {
          await alert(post.reason != null ? post.reason : "관리자 문의");
          setState(() {
            _isLoading = false;
          });
        }
      }).catchError((e) async {
        await alert("네트워크를 확인해주세요.");
        setState(() {
          _isLoading = false;
        });
      });
    }
    setState(() {
      _isLoading = false;
    });
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