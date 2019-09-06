import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pdsample/main.dart';
import 'package:pdsample/change.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdsample/init.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' show utf8, json;
import 'package:pdsample/temp.dart';

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
  static const RETURN_REQUEST = 20;
  static const RETURN_READY = 21;
  static const RETURN_CALL = 22;
  static const RETURN_APPROACH = 23;
  static const RETURN_TERMINAL = 24;
  static const RETURN_RIDE = 25;
  static const RETURN_END = 26;
}

Map<String, dynamic> dataInt = new Map();

class ReceiveApp extends StatefulWidget {
  ReceiveApp(String com) {
    commit = com;
    dataInt['첫째날(금) 09-13'] = 0;
    dataInt['둘째날(토) 09-14'] = 1;
    dataInt['셋째날(일) 09-15'] = 2;
  }

  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<ReceiveApp> with TickerProviderStateMixin {
  bool _isLoading = false;

  bool confirm1 = false;
  bool confirm2 = false;
  bool confirm3 = false;
  bool confirm4 = false;
  bool confirm5 = false;

  AnimationController _animationController;

  String _commitDate = commit;

  SharedPreferences prefs;

  Map<String, dynamic> info;
  Map<String, dynamic> summary;
  String type;

  Widget circle = Center(child: CircularProgressIndicator());

  Map<int, String> mapCode = {
    11: "",
    12: "",
    21: "",
    22: "",
    31: "",
    41: "",

    301: "1-",
    302: "2-",
    303: "3-",
    304: "4-",
    305: "5-",
    306: "6-",

    321: "",

    341: "",

    361: "A-",
    362: "B-",
    363: "C-",
    364: "D-",
    365: "E-",

    401: "1-",
    402: "2-",
    403: "3-",
    404: "4-",
    405: "5-",

    901: "대기 ",
    902: "대기 ",
    903: "대기 ",
  };

  String terminal = "";


  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

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

          terminal = summary['bus_return'][dataInt[_commitDate]] + " " + mapCode[summary['bus_return_code'][dataInt[_commitDate]]] + "" + (summary['bus_return_slot'][dataInt[_commitDate]] != null ? (summary['bus_return_slot'][dataInt[_commitDate]] + 1).toString() : "");
        });
      }
    });
    await _user().then((data) async {
      if (data != null && data['ok']) {
        setState(() {
          info = data['bus_info'];
        });

        if (info['bus_driver_phone'] == null || info['bus_number'] == null || info['bus_driver_phone'].toString().length < 4 || info['bus_number'].toString().length < 7) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditBus(this)),
          );
        }

        // 터미널 도착할 경우
        if (info['bus_step'] == Step.RETURN_END || info['bus_step'] == Step.RETURN_RIDE) {
          confirm1 = confirm2 = confirm3 = confirm4 = confirm5 = true;
        } else if (info['bus_step'] == Step.RETURN_TERMINAL) {
          confirm1 = confirm2 = confirm3 = confirm4 = true;
        } else if (info['bus_step'] == Step.RETURN_APPROACH) {
          confirm1 = confirm2 = confirm3 = true;
        } else if (info['bus_step'] == Step.RETURN_CALL) {
          confirm1 = confirm2 = true;
        } else if (info['bus_step'] == Step.RETURN_READY) {
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
        title: '오후 화면',
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
            child: Text(_commitDate + " 오후", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900]), ),
          ),
          (info != null) ? Container(
        padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text((info['bus_name']  ?? "")  + "/" + (info['bus_guide_name']  ?? "")  + "/" + (info['bus_guide_phone'] ?? "" ), style: TextStyle(fontSize: 13.0),),
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
                  child: Text(terminal, style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.pink),),
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
                ),///
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
          (confirm1 && !confirm2) ? FadeTransition(
            opacity: _animationController,
            child: Icon(Icons.arrow_downward, color:  Colors.yellow[900],),
          ) : Container(
            child: Icon(Icons.arrow_downward, color: !confirm2 ?  Colors.red[900] : Colors.green[900],),
          ),
          call(),
          (confirm2 && !confirm3) ? FadeTransition(
            opacity: _animationController,
            child: Icon(Icons.arrow_downward, color:  Colors.yellow[900],),
          ) : Container(
            child: Icon(Icons.arrow_downward, color: !confirm3 ?  Colors.red[900] : Colors.green[900],),
          ),
          arrive(),
          (confirm3 && !confirm4) ? FadeTransition(
            opacity: _animationController,
            child: Icon(Icons.arrow_downward, color:  Colors.yellow[900],),
          ) : Container(
            child: Icon(Icons.arrow_downward, color: !confirm4 ?  Colors.red[900] : Colors.green[900],),
          ),
          terminalArrive(),
          (confirm4 && !confirm5) ? FadeTransition(
            opacity: _animationController,
            child: Icon(Icons.arrow_downward, color:  Colors.yellow[900],),
          ) : Container(
            child: Icon(Icons.arrow_downward, color: !confirm5 ?  Colors.red[900] : Colors.green[900],),
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
          title: Text("승차 준비 완료", style: TextStyle(fontSize: 20),),
          subtitle: Text("버스 승객이 모두 모였을 경우 누릅니다.",),
          onTap: () {
            setState(() {
              !confirm1 ? alert("승차 준비가 완료되어, 버스 출발을 요청하시겠습니까?", 1) : alert("버스 출발 요청을 취소하겠습니까?", 6);
            });
          },
        ),
      ),
    );
  }

  Widget call() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        color: !confirm2 ? Colors.grey[100] : Colors.red[300],
        child: ListTile(
          dense: true,
          leading: Icon(Icons.fiber_manual_record, color: Colors.blue,),
          title: Text("버스 호출", style: TextStyle(fontSize: 20),),
          subtitle: Text("버스기사에게 연락이 완료되어 버스가 터미널에 올 때 진행됩니다.",),
          onTap: () {
            setState(() {
              !confirm2 ? alert("아직 기사에게 연락되지 않았습니다. 새로고침을 눌러 다시 확인해주세요.", 0) : alert("기사에게 연락되었습니다. 잠시만 기다려주세요.", 0);
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
        color: !confirm3 ? Colors.grey[100] : Colors.red[300],
        child: ListTile(
          dense: true,
          leading: Icon(Icons.fiber_manual_record, color: Colors.blue),

          title: Text("버스 진입", style: TextStyle(fontSize: 20),),
          subtitle: Text("버스가 터미널 근처에 진입할 때 진행됩니다.",),
          onTap: () {
            setState(() {
              !confirm3 ? alert("아직 버스가 근처에 없습니다. 새로고침을 눌러 다시 확인해주세요.", 0) : alert("연락이 완료되었습니다. 곧 버스가 터미널에 도착하니 잠시 기다려주세요.", 0);
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
        color: !confirm4 ? Colors.grey[100] : Colors.red[300],
        child: ListTile(
          dense: true,
          leading: Icon(Icons.fiber_manual_record, color: Colors.blue),
          trailing: Container(
            child: ButtonTheme(
              minWidth: 10.0,
              height: 1,
              child: RaisedButton(
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                color: confirm4 ? Colors.blue : Colors.grey,
                onPressed: _map,
                child: Container(
                  padding: EdgeInsets.all(10.0),
                  child: Text("확인", style: TextStyle(fontSize: 10.0, color: Colors.white,),),
                ),
              ),
            ),
          ),
          title: Text("위치 확인", style: TextStyle(fontSize: 20),),
          subtitle: Text("버스가 도착하면 색상이 바뀝니다. 그때 오른쪽 버튼을 눌러 위치를 확인해주세요.",),
          onTap: () {
            setState(() {
              !confirm4 ? alert("버스가 아직 도착하지 않았습니다. 새로고침을 눌러 다시 확인해주세요.", 0) : alert("버스가 도착하였습니다. 위치를 확인해주세요.", 0);
            });
          },
        ),
      ),
    );
  }

  Widget terminalDepart() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        color: !confirm5 ? Colors.grey[100] : Colors.orange[200],
        child: ListTile(
          dense: true,
          leading: Icon(Icons.looks_two, color: !confirm5 ? Colors.red : Colors.green,),
          title: Text("승차 완료, 출발 (앱종료)", style: TextStyle(fontSize: 20),),
          subtitle: Text("모두 승차하고, 버스가 터미널을 떠날 때 누릅니다.",),
          onTap: () {
            !confirm5 ? alert("버스에 승객이 모두 승차하였고, 터미널을 빠져나왔습니까?", 4) : alert("버스에 승객이 승차하지 않았습니까? 또는 아직 터미널을 빠져나오지 않았습니까?", 9);
          },
        ),
      ),
    );
  }

  Widget finish() {
    return ListTile(
      title: confirm5 ? Text("수고하셨습니다!", style: TextStyle(fontSize: 14), textAlign: TextAlign.center,) : null,
    );
  }

  void _map() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Maps(title: summary["bus_return_code"][dataInt[_commitDate]] ?? 0, terminal: terminal,)), /// 터미널에 따라 지도 모양 다르게
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
                    if (confirm4) {
                      status(prefs.getString("token"), "rEnd").then((post) {
                        if (post.ok) {
                          setState(() {
                            confirm5 = true;
                            _isLoading = false;
                          });
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
                    if (!confirm2) {
                      status(prefs.getString("token"), "request").then((post) {
                        if (post.ok) {
                          setState(() {
                            confirm1 = false;
                            _isLoading = false;
                          });
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
                      confirm();
                      setState(() {
                        _isLoading = false;
                      });
                    }
                    setState(() {
                      _isLoading = false;
                    });
                    break;
                  case 9:
                    status(prefs.getString("token"), "rTerminal").then((post) {
                      if (post.ok) {
                        setState(() {
                          confirm5 = false;
                          _isLoading = false;
                        });
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