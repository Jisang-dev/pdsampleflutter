import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:pdsample/init.dart';
import 'package:shared_preferences/shared_preferences.dart';

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