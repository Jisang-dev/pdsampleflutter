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

class InitApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

enum Timeline { morning, afternoon }

class _MyAppState extends State<InitApp> {
  final _formKey = new GlobalKey<FormState>();
  String _guideName;
  final controller1 = TextEditingController();
  String _guideNumber;
  final controller2 = TextEditingController();
  String _busCode;
  final controller3 = TextEditingController();
  String _busNumber;
  final controller4 = TextEditingController();
  bool _isLoading = false;
  SharedPreferences prefs;
  Timeline _timeline = (new DateTime.now().hour < 12) ? Timeline.morning : Timeline.afternoon;
  String _commitDate = DateTime.now().day % 3 == 1 ? '첫째날(금) 09-13': (DateTime.now().day % 3 == 2 ? '둘째날(토) 09-14': '셋째날(일) 09-15');

  @override
  void initState() {
    super.initState();
    currentUser();
  }

  void currentUser() async {
    prefs = await SharedPreferences.getInstance();
    await _user().then((data) {
      if (data['ok']) {
        controller1.text = data['bus_info']['bus_guide_name'];
        controller2.text = data['bus_info']['bus_guide_phone'];
        controller3.text = data['bus_info']['bus_number'];
        controller4.text = data['bus_info']['bus_driver_phone'];
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
          child: FutureBuilder<Map<String, dynamic>> (
            future: _user(),
            builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return new ListView(
                  // Important: Remove any padding from the ListView.
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    Container(
                        height: 90.0,
                        child: DrawerHeader(
                          child:  Text("2019SIC 주차 지원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,),),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
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
                      child: Text(snapshot.data['bus_info']['bus_name'] + "\n" + "버스 n대 중 1호차" + "\n" + snapshot.data['bus_info']['bus_guide_name'] + "\n" + snapshot.data['bus_info']['bus_guide_phone']),
                    ),
                    Container(
                      color: Colors.grey[300],
                      padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
                      child: Text("첫째날(금요일) - 제1관터미널" + "\n" + "둘째날(토요일) - 제2관터미널" + "\n" + "셋째날(일요일) - 제1관터미널"),
                    ),
                    ListTile(
                      title: Text('주차장', style: TextStyle(fontWeight: FontWeight.bold),),
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
                            child: Text("제1관 터미널", style: TextStyle(color: Colors.blue),),
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
                            child: Text("제1관 주차장 내부", style: TextStyle(color: Colors.blue),),
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
                            child: Text("제2관 터미널", style: TextStyle(color: Colors.blue),),
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
                      title: Text('앱 사용법', style: TextStyle(fontWeight: FontWeight.bold),),
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
                                url = "https://blog.naver.com/hyla981020/221505617243";
                                if (await canLaunch(url)) {
                                  await launch(
                                    url,
                                    forceSafariVC: true,
                                    forceWebView: true,
                                    enableJavaScript: true,
                                  );
                                }
                              } else {
                                url = "https://blog.naver.com/hyla981020/221505617243";
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
                            child: Text("개인정보취급방침", style: TextStyle(color: Colors.blue),),
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
                  ],
                );
              } else {
                return new ListView(
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
                      title: Text("로딩중입니다..."),
                    ),
                  ],
                );
              }
            },
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
                    _commitDate = value;
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
            _guideNameInput(),
            _busDriverInput(),
            _busCodeInput(),
            _memo(),
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

  Widget _busCodeInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
      child: new TextFormField(
        controller: controller3,
        maxLines: 1,
        keyboardType: TextInputType.text,
        autofocus: false,
        decoration: new InputDecoration(
            labelText: '차량 번호 (예: 12가 3456)',
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
            confirm(_commitDate + " " + (_timeline == Timeline.morning ? "오전" : "오후") + "\n\n" + "인솔자 이름:"+ controller1.text + "\n\n" + "인솔자 전화번호:"+ controller2.text + "\n\n" + "차량 번호:"+ controller3.text + "\n\n" + "기사 연락처:"+ controller4.text + "\n\n" + "위 정보가 맞습니까?");
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
        "bus_guide_number": _guideNumber,
        "bus_number": _busCode,
        "bus_driver_phone": _busNumber,
        "status": _status, /// 킨텍스 거리에 따라 바뀌어야 함
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

      await fetchPost(prefs.getString('token'), _guideName, _guideNumber, _busCode, _busNumber, "start").then((post) async {
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
        }
      }).catchError((e) async {
        await alert("네트워크를 확인해주세요.");
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