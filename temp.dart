import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:pdsample/init.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

  Future<Post> fetchPost(String token, String pw) async {
  final response = await http.post (
  "https://ip2019.tk/auth/api/password_change",
    body: json.encode({
      "token": token,
      "password": pw,
    }),
    headers: {
      "content-type" : "application/json",
      "accept" : "application/json",
    },
  );
  return Post.fromJson(json.decode(response.body));
}

class TempApp extends StatelessWidget {
// This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: '2019 국제대회 주차부',
      theme: new ThemeData(
        primaryColor: Colors.green[900],
      ),
      home: new TempPage(title: '주차부 버스 인솔자용',),
    );
  }
}

class TempPage extends StatefulWidget {
  TempPage({Key key, this.title}) : super(key: key);

// This widget is the home page of your application. It is stateful, meaning
// that it has a State object (defined below) that contains fields that affect
// how it looks.

// This class is the configuration for the state. It holds the values (in this
// case the title) provided by the parent (in this case the App widget) and
// used by the build method of the State. Fields in a Widget subclass are
// always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<TempPage> {
  final _formKey = new GlobalKey<FormState>();
  String _email;
  String _password;
  bool _isLoading = false;
  static const platform = const MethodChannel('sample.hyla981020.com/bg');
  SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    currentUser();
  }

  void currentUser() async {
    prefs = await SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: '초기값 입력',
      theme: ThemeData(
        primaryColor: Colors.green[900],
        bottomAppBarColor: Colors.grey[300],
      ),
      home: Scaffold(
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
          )
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
      child: Form(
        key: _formKey,
        child: new ListView(
          shrinkWrap: true,
          children: <Widget>[
            _showImage(),
            Text("시작하기 전, 원하시는 비밀번호로 변경하여 주세요.", textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.0,),),
            Padding(padding: const EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 0.0),),
            Text("비밀번호 변경", textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green[900], fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
            _showEmailInput(),
            _showPasswordInput(),
            _submit(),
            Text("\n\n주차 안내부 : 010-5613-1935", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey),),
          ],
        ),
      ),
    );
  }

  Widget _showImage() {
    return Image.asset(
      'assets/jw2019.png',
      width: 120,
      height: 56.875,
    );
  }

  Widget _showEmailInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 0.0),
      child: new TextFormField(
        maxLines: 1,
        keyboardType: TextInputType.text,
        obscureText: true,
        autofocus: true,
        decoration: new InputDecoration(
            labelText: '새 비밀번호',
            ),
        validator: (value) => (value.isEmpty || value.length < 4) ? '새 비밀번호는 4자 이상 입력해야합니다.' : null,
        onSaved: (value) => _email = value,
      ),
    );
  }

  Widget _showPasswordInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
      child: new TextFormField(
        maxLines: 1,
        keyboardType: TextInputType.text,
        obscureText: true,
        autofocus: false,
        decoration: new InputDecoration(
            labelText: '새 비밀번호 확인',
            ),
        validator: (value) => (value.isEmpty || value.length < 4) ? '새 비밀번호는 4자 이상 입력해야합니다.' : null,
        onSaved: (value) => _password = value,
      ),
    );
  }

  Widget _submit() {
    return new Padding(
      padding: EdgeInsets.fromLTRB(0.0, 30.0, 0.0, 0.0),
      child: RaisedButton(
        color: Colors.green[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: _validateAndSubmit,
        child: new Text('비밀번호 변경',
            style: new TextStyle(fontSize: 20.0, color: Colors.white)),
      ),
    );
  }

  void _validateAndSubmit() async {
    setState(() {
      _isLoading = true;
    });
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();
      if (_email == _password) {
        await fetchPost(prefs.getString('token'), _password).then((data) async {
        if (data.ok) {
          await prefs.setString('pw', _password);
          await prefs.setString('token', data.token);
          await prefs.setBool('first', false);
          Navigator.pushReplacement(
            context,
            new MaterialPageRoute(
                builder: (BuildContext context) => new InitApp()
            ),
          );
        } else {
          alert(data.reason);
          setState(() {
            _isLoading = false;
          });
        }
      }).catchError((e) {
          alert("네트워크를 확인해주세요.");
          print(e.toString());
          setState(() {
            _isLoading = false;
          });
        });
      } else {
        alert("비밀번호가 일치한지 확인해주세요.");
        setState(() {
          _isLoading = false;
        });
      }
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
}

class Maps extends StatefulWidget {
  Maps({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MapState createState() => new _MapState(title: this.title);
}

class _MapState extends State<Maps> {

  _MapState({this.title});

  final String title;

//  PhotoViewController controller;
  double preScale;
  double preX = 0;
  double preY = 0;

  double x = 160.0 - 115;
  double y = 320.0 + 60;

  Offset temp = new Offset(115, -60);

  List<Offset> places = new List<Offset>();

  @override
  void initState() {
    super.initState();
//    controller = PhotoViewController()
//      ..outputStateStream.listen(listener);
  }

  @override
  void dispose() {
//    controller.dispose();
    super.dispose();
  }

//  void listener(PhotoViewControllerValue value){
//    if (preScale == null) {
//      preScale = value.scale;
//    }
//    setState(() {
//      x += value.position.dx - preX - (value.scale - preScale) * temp.dx * 7;
//      y -= value.position.dy - preY + (value.scale - preScale) * temp.dy * 7;
//    });
//    preScale = value.scale;
//    preX = value.position.dx;
//    preY = value.position.dy;
//  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: '지도 보기',
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
          title: Text('상세 지도 확인 (준비중)', style: TextStyle(fontWeight: FontWeight.bold,),),
        ),
        body: Container(
          alignment: Alignment.center,
          child: Stack(
            children: <Widget>[
              Positioned(
//                child: PhotoView(
//                  controller: controller,
//                  imageProvider: AssetImage("assets/return1_b.jpg"),
//                  minScale: 0.1,
//                  maxScale: 4.0,
//                  backgroundDecoration: BoxDecoration(
//                    color: Colors.white,
//                  ),
//                ),
              ),
              Positioned(
                left: x,
                bottom: y,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text("1전시관 20", textAlign: TextAlign.center,),
                    Image.asset(
                      'assets/place.png',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class TerminateApp extends StatelessWidget {
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
      home: new TerminatePage(title: '주차부 버스 인솔자용',),
    );
  }
}

class TerminatePage extends StatefulWidget {
  TerminatePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _TerminateState createState() => new _TerminateState();
}

class _TerminateState extends State<TerminatePage> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: AppBar(
          title: Text('종료', style: TextStyle(fontWeight: FontWeight.bold,),),
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
        )
    );
  }

  Widget _showBody() {
    return new Center(
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          backgroundBlendMode: BlendMode.softLight,
          color: Colors.white,
        ),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            _showImage(),
            Padding(padding: const EdgeInsets.fromLTRB(0.0, 20.0, 0.0, 0.0),),
            Text("모든 과정이 완료되었습니다. 수고하셨습니다!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.bold),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 0.0),),
            Text(Platform.isAndroid ? "아래 버튼을 누르시면 앱이 종료됩니다." : "아래 버튼을 누르시면 초기화면으로 돌아갑니다.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.bold),
            ),
            _submit(),
            Text("\n\n주차 안내부 : 010-5613-1935", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey),),
          ],
        ),
      ),
    );
  }

  Widget _showImage() {
    return Image.asset(
      'assets/jw2019.png',
      width: 120,
      height: 56.875,
    );
  }

  Widget _submit() {
    return new Padding(
      padding: EdgeInsets.fromLTRB(0.0, 30.0, 0.0, 0.0),
      child: RaisedButton(
        color: Colors.green[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () {
          if (Platform.isAndroid) {
            SystemNavigator.pop();
          } else {
            Navigator.pushReplacement(
              context,
              new MaterialPageRoute(
                  builder: (BuildContext context) => new InitApp()
              ),
            );
          }
        }, // 안드로이드는 앱 종료 기능, 아이폰은 초기화면으로 넘어가도록 함
        child: new Text(Platform.isAndroid ? "앱 종료" : "초기화면으로",
            style: new TextStyle(fontSize: 20.0, color: Colors.white)),
      ),
    );
  }
}