import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdsample/store.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pdsample/main.dart';
import 'package:pdsample/receive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdsample/init.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' show utf8, json;

int timestamp;
String commit;

class SendApp extends StatefulWidget {
  SendApp(String com) {
    commit = com;
  }

  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<SendApp> {
  String _email = "temporary10@pdsample.com"; // 계정 이름
  bool _isLoading = false;
  SharedPreferences prefs;
  StreamSubscription<LocationData> streamListen;

  bool step1 = false;
  bool step2 = false;
  bool step3 = false;
  bool step4 = false;
  bool step5 = false;

//  bool check = false;

  bool confirm1 = false;
  bool confirm2 = false;
  bool confirm3 = false;
  bool confirm4 = false;
  bool confirm5 = false;

  Timeline _timeline = Timeline.morning;
  String _commitDate = commit;

  Location location;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  static const platform = const MethodChannel('sample.hyla981020.com/bg');

  int _count = 0;

  Future<void> _setBackground() async { // for iOS and androidOS
    try {
      await platform.invokeMethod('initLocation');
    } on Exception catch (e) {
      print(e.toString());
    }
  }

  void currentUser() async {
    prefs = await SharedPreferences.getInstance();
  }

  @override
  void initState() {
    super.initState();
    getEmail();
    currentUser();
    timestamp = (Platform.isAndroid ? Timestamp.fromDate(DateTime.now()).millisecondsSinceEpoch : Timestamp.fromDate(DateTime.now()).seconds);
    platform.setMethodCallHandler((call) {
      if (call.method == "background") {
        background(call.arguments);
      }
    });
    if (Platform.isAndroid) {
      sample();
    }
    _setBackground();

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print('on message $message');
//        setState(() async {
//          await Firestore.instance.collection('01').document(_email).get().then((data) {
//            final cell = Cell.fromSnapshot(data);
//            check = cell.access;
//            if (check) {
//              confirm1 = confirm2 = confirm3 = true;
//            }
//          });
//        });
      },
      onResume: (Map<String, dynamic> message) async {
        print('on resume $message');
//        setState(() async {
//          await Firestore.instance.collection('01').document(_email).get().then((data) {
//            final cell = Cell.fromSnapshot(data);
//            check = cell.access;
//            if (check) {
//              confirm1 = confirm2 = confirm3 = true;
//            }
//          });
//        });
      },
      onLaunch: (Map<String, dynamic> message) async {
        print('on launch $message');
//        setState(() async {
//          await Firestore.instance.collection('01').document(_email).get().then((data) {
//            final cell = Cell.fromSnapshot(data);
//            check = cell.access;
//            if (check) {
//              confirm1 = confirm2 = confirm3 = true;
//            }
//          });
//        });
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
      Firestore.instance.collection('01').document(_email).get().then((data) {
        final cell = Cell.fromSnapshot(data);
        Firestore.instance.runTransaction((transaction) async {
          await transaction
              .update(cell.reference, {'token': token});
        });
      });
    });
  }

  void getEmail() async {
    await Firestore.instance.collection('01').document(_email).get().then((data) {
      final cell = Cell.fromSnapshot(data);
      setState(() {
        confirm1 = (cell.depart != null && cell.depart != "");
        confirm2 = (cell.pass1 != null && cell.pass1 != "");
        confirm3 = (cell.pass2 != null && cell.pass2 != "");
        confirm4 = (cell.tArrive != null && cell.tArrive != "");
        confirm5 = (cell.tDepart != null && cell.tDepart != "");
      });
      step1 = step2 = step3 = step4 = step5 = false;
    });
  }

  void background(String latlang) async {
    var latlng = latlang.split(",");
    Firestore.instance.collection('01').document(_email).get().then((data) {
      final cell = Cell.fromSnapshot(data);
      Firestore.instance.runTransaction((transaction) async {
        await transaction
            .update(cell.reference, {'lat': double.parse(latlng[0])});
        await transaction
            .update(cell.reference, {'long': double.parse(latlng[1])});
      });
    });
    await fetchPost(prefs.getString("token"), (double.parse(latlng[0])*1000000).toInt(), (double.parse(latlng[1])*1000000).toInt());
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

  void logout() async {
    await prefs.setString('id', null);
    await prefs.setString('pw', null);
    await prefs.setString('token', null);
    if (Platform.isAndroid) {
      streamListen.cancel();
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

  void sample() async {
    location = new Location();
//    await location.changeSettings(distanceFilter: 400, accuracy: LocationAccuracy.BALANCED);
    if (await location.requestPermission()) {
      streamListen = location.onLocationChanged().listen((LocationData currentLocation) async {
        if (_count < 150 && currentLocation.time.toInt() > _count * 60000 + timestamp) {
          Firestore.instance.collection('01').document(_email).get().then((data) {
            final cell = Cell.fromSnapshot(data);
            Firestore.instance.runTransaction((transaction) async {
              await transaction
                  .update(cell.reference, {'lat': currentLocation.latitude});
              await transaction
                  .update(cell.reference, {'long': currentLocation.longitude});
            });
          });
          await fetchPost(prefs.getString("token"), (currentLocation.latitude*1000000).toInt(), (currentLocation.longitude*1000000).toInt()).then((post) {
            if (post.ok) {
              print("success");
            } else {
              print(post.reason);
            }
          });
          _count++;
          if (_count < (currentLocation.time.toInt() - timestamp) ~/ 60000) {
            _count = (currentLocation.time.toInt() - timestamp) ~/ 60000;
          }
        }
        if (_count > 150) {
          streamListen.cancel();
          location = null;
          try {
            await platform.invokeMethod('stop');
          } on Exception catch (e) {
            e.toString();
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
        title: new Text("2019SIC 주차 지원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,),),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              getEmail();
            },
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          _showBody(),
          _showCircularProgress(),
        ],
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
                      child:  Text("2019SIC 주차 지원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,),),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
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
    )
    );
  }

  Widget _showCircularProgress() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    } return Container(height: 0.0, width: 0.0,);
  }

  Widget _showBody(){
    return new Container(
      padding: EdgeInsets.all(16.0),
      child: new ListView(
        shrinkWrap: true,
        children: <Widget>[
          Text(_commitDate + " 오전", style: TextStyle(fontSize: 14),),
          depart(),
          departDetail(),
          middle(),
          middleDetail(),
          arrive(),
          arriveDetail(),
          terminalArrive(),
          terminalArriveDetail(),
          terminalDepart(),
          terminalDepartDetail(),
          finish(),
        ],
      ),
    );
  }

  Widget depart() {
    return ListTile(
      title: Text("출발"),
      onTap: () {
        setState(() {
          step1 = !step1;
          step2 = step3 = step4 = step5 = false;
        });
      },
      trailing: confirm1 ? Icon(Icons.check_circle, color: Colors.green) : (step1 ? Icon(Icons.arrow_drop_up) : Icon(Icons.arrow_drop_down)),
    );
  }

  Widget departDetail() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      height: step1 ? 50 : 0,
      child: step1 ? MaterialButton (
        elevation: 5.0,
        minWidth: 10.0,
        height: 42.0,
        color: Colors.blue,
        child:new Text('버스 출발',
            style: new TextStyle(fontSize: 20.0, color: Colors.white)),
        onPressed: () {
          !confirm1 ? alert("버스가 출발하였습니까?", 1) : alert("버스가 출발하지 않았습니까?", 6);
        },
      ) : null,
      color: Colors.grey,
    );
  }

  Widget middle() {
    return ListTile(
      title: Text("1차지점 통과"),
      onTap: () {
        setState(() {
          step2 = !step2;
          step1 = step3 = step4 = step5 = false;
        });
      },
      trailing: confirm2 ? Icon(Icons.check_circle, color: Colors.green) : (step2 ? Icon(Icons.arrow_drop_up) : Icon(Icons.arrow_drop_down)),
    );
  }

  Widget middleDetail() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      height: step2 ? 50 : 0,
      child: step2 ? MaterialButton (
        elevation: 5.0,
        minWidth: 10.0,
        height: 42.0,
        color: Colors.blue,
        child:new Text('1차지점 통과',
            style: new TextStyle(fontSize: 20.0, color: Colors.white)),
        onPressed: () {
          !confirm2 ? alert("버스가 1차지점을 통과하였습니까?", 2) : alert("버스가 아직 1차지점을 출발하지 않았습니까?", 7);
        },
      ) : null,
      color: Colors.grey,
    );
  }

  Widget arrive() {
    return ListTile(
      title: Text("2차 지점 통과, 도착(예정)"),
      onTap: () {
        setState(() {
          step3 = !step3;
          step1 = step2 = step4 = step5 = false;
        });
      },
      trailing: confirm3 ? Icon(Icons.check_circle, color: Colors.green) : (step3 ? Icon(Icons.arrow_drop_up) : Icon(Icons.arrow_drop_down)),
    );
  }

  Widget arriveDetail() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      height: step3 ? 50 : 0,
      child: step3 ?
      MaterialButton (
        elevation: 5.0,
        minWidth: 10.0,
        height: 42.0,
        color: Colors.blue,
        child:new Text('2차 지점 통과, 도착(예정)',
            style: new TextStyle(fontSize: 20.0, color: Colors.white)),
        onPressed: () {
          !confirm3 ? alert("버스가 2차 지점을 통과하였거나, 킨텍스 근처에 성공적으로 도착하셨습니까?", 3) : alert("버스가 아직 2차 지점이나 근처에 도착하지 않았습니까?", 8);
        },
      ) : null,
      color: Colors.grey,
    );
  }

  Widget terminalArrive() {
    return confirm3 ? ListTile( // check -> confirm
      title: Text("터미널도착"),
      onTap: () {
        setState(() {
          step4 = !step4;
          step1 = step2 = step3 = step5 = false;
        });
      },
      trailing: confirm4 ? Icon(Icons.check_circle, color: Colors.green) : (step4 ? Icon(Icons.arrow_drop_up) : Icon(Icons.arrow_drop_down)),
    ) : ListTile();
  }

  Widget terminalArriveDetail() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      height: step4 ? 50 : 0,
      child: step4 ? MaterialButton (
        elevation: 5.0,
        minWidth: 10.0,
        height: 42.0,
        color: Colors.blue,
        child:new Text('터미널도착',
            style: new TextStyle(fontSize: 20.0, color: Colors.white)),
        onPressed: () {
          !confirm4 ? alert("버스가 터미널에 정차하였습니까?", 4) : alert("버스가 아직 터미널에 정차하지 않았습니까?", 9);
        },
      ) : null,
      color: Colors.grey,
    );
  }

  Widget terminalDepart() {
    return confirm3 ? ListTile( // check -> confirm
      title: Text("터미널출발"),
      onTap: () {
        setState(() {
          step5 = !step5;
          step1 = step2 = step3 = step4 = false;
        });
      },
      trailing: confirm5 ? Icon(Icons.check_circle, color: Colors.green) : (step5 ? Icon(Icons.arrow_drop_up) : Icon(Icons.arrow_drop_down)),
    ) : ListTile();
  }

  Widget terminalDepartDetail() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      height: step5 ? 50 : 0,
      child: step5 ? MaterialButton (
        elevation: 5.0,
        minWidth: 10.0,
        height: 42.0,
        color: Colors.blue,
        child:new Text('터미널출발',
            style: new TextStyle(fontSize: 20.0, color: Colors.white)),
        onPressed: () {
          !confirm5 ? alert("버스 승객이 모두 하차하였고, 버스가 터미널을 빠져나왔습니까?", 5) : alert("버스가 아직 터미널을 출발하지 않았습니까?", 10);
        },
      ) : null,
      color: Colors.grey,
    );
  }

  Widget finish() {
    return ListTile(
      title: confirm5 ? Text("수고하셨습니다!") : null,
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
          title: Text("이후 단계가 이미 실행되었습니다. 다음 단계를 먼저 확인해주세요."),
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
                switch (process) {
                  case 1:
                    setState(() {
                      _isLoading = true;
                    });
                      Firestore.instance.collection('01')
                          .document(_email)
                          .updateData(<String, dynamic>{'depart': (DateTime.now().hour < 10 ? "0" + DateTime.now().hour.toString() : DateTime.now().hour.toString()) + ":" + (DateTime.now().minute < 10 ? "0" + DateTime.now().minute.toString() : DateTime.now().minute.toString())})
                          .then((a) {
                        setState(() {
                          confirm1 = true;
                          _isLoading = false;
                        });
                        success();
                      });
                    break;
                  case 2:
                    setState(() {
                      _isLoading = true;
                    });
                    if (confirm1) {
                        Firestore.instance.collection('01')
                            .document(_email)
                            .updateData(<String, dynamic>{'pass1': (DateTime.now().hour < 10 ? "0" + DateTime.now().hour.toString() : DateTime.now().hour.toString()) + ":" + (DateTime.now().minute < 10 ? "0" + DateTime.now().minute.toString() : DateTime.now().minute.toString())})
                            .then((a) {
                          setState(() {
                            confirm2 = true;
                            _isLoading = false;
                          });
                          success();
                        });
                    } else {
                      confirm();
                    }
                    break;
                  case 3:
                    setState(() {
                      _isLoading = true;
                    });
                    if (confirm2) {
                        Firestore.instance.collection('01')
                            .document(_email)
                            .updateData(<String, dynamic>{'pass2': (DateTime.now().hour < 10 ? "0" + DateTime.now().hour.toString() : DateTime.now().hour.toString()) + ":" + (DateTime.now().minute < 10 ? "0" + DateTime.now().minute.toString() : DateTime.now().minute.toString())})
                            .then((a) {
                          setState(() {
                            confirm3 = true;
                            _isLoading = false;
                          });
                          success();
                        });
                    } else {
                      confirm();
                    }
                    break;
                  case 4:
                    setState(() {
                      _isLoading = true;
                    });
                    if (confirm3) {
                        Firestore.instance.collection('01')
                            .document(_email)
                            .updateData(<String, dynamic>{'tArrive': (DateTime.now().hour < 10 ? "0" + DateTime.now().hour.toString() : DateTime.now().hour.toString()) + ":" + (DateTime.now().minute < 10 ? "0" + DateTime.now().minute.toString() : DateTime.now().minute.toString())})
                            .then((a) {
                          setState(() {
                            confirm4 = true;
                            _isLoading = false;
                          });
                          success();
                        });
                    } else {
                      confirm();
                    }
                    break;
                  case 5:
                    setState(() {
                      _isLoading = true;
                    });
                    if (confirm4) {
                        Firestore.instance.collection('01')
                            .document(_email)
                            .updateData(<String, dynamic>{'tDepart': (DateTime.now().hour < 10 ? "0" + DateTime.now().hour.toString() : DateTime.now().hour.toString()) + ":" + (DateTime.now().minute < 10 ? "0" + DateTime.now().minute.toString() : DateTime.now().minute.toString())})
                        .then((a) {
                          setState(() {
                            confirm5 = true;
                            _isLoading = false;
                          });
                          success();
                        });
                    } else {
                      confirm();
                    }
                    break;
                  case 6:
                    setState(() {
                      _isLoading = true;
                    });
                    if (!confirm2) {
                        Firestore.instance.collection('01')
                            .document(_email)
                            .updateData(<String, dynamic>{'depart': null}).then((a) {
                          setState(() {
                            confirm1 = false;
                            _isLoading = false;
                          });
                          success();
                        });
                    } else {
                      confirm02();
                    }
                    break;
                  case 7:
                    setState(() {
                      _isLoading = true;
                    });
                    if (!confirm3) {
                        Firestore.instance.collection('01')
                            .document(_email)
                            .updateData(<String, dynamic>{'pass1': null}).then((a) {
                          setState(() {
                            confirm2 = false;
                            _isLoading = false;
                          });
                          success();
                        });
                    } else {
                      confirm02();
                    }
                    break;
                  case 8:
                    setState(() {
                      _isLoading = true;
                    });
                    if (!confirm4) {
                        Firestore.instance.collection('01')
                            .document(_email)
                            .updateData(<String, dynamic>{'pass2': null}).then((a) {
                          setState(() {
                            confirm3 = false;
                            _isLoading = false;
                          });
                          success();
                        });
                    } else {
                      confirm02();
                    }
                    break;
                  case 9:
                    setState(() {
                      _isLoading = true;
                    });
                    if (!confirm5) {
                        Firestore.instance.collection('01')
                            .document(_email)
                            .updateData(<String, dynamic>{'tArrive': null}).then((a) {
                          setState(() {
                            confirm4 = false;
                            _isLoading = false;
                          });
                          success();
                        });
                    } else {
                      confirm02();
                    }
                    break;
                  case 10:
                    setState(() {
                      _isLoading = true;
                    });
                      Firestore.instance.collection('01')
                          .document(_email)
                          .updateData(<String, dynamic>{'tDepart': null}).then((a) {
                        setState(() {
                          confirm5 = false;
                          _isLoading = false;
                        });
                        success();
                      });
                    break;
                }
                setState(() {
                  step1 = step2 = step3 = step4 = step5 = false;
                });
                // 데이터 전송
              },
            ),
          ],
        );
      },
    );
  }
}