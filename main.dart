import 'package:flutter/material.dart';
import 'send.dart';
import 'confirm.dart';
import 'store.dart';
import 'temp.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'receive.dart';
import 'package:flutter/services.dart';
import 'package:pdsample/store.dart';
import 'dart:io';
import 'dart:convert';
import 'package:pdsample/init.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

enum FormMode { LOGIN, SIGNUP }

void main() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('token', null);
  String id = prefs.getString('id');
  String pw = prefs.getString('pw');
  await fetchPost(id, pw).then((post) async {
    if (post.ok) {
      await prefs.setString('id', id);
      await prefs.setString('pw', pw);
      await prefs.setString('token', post.token);
      runApp(TempApp());
    } else {
      await prefs.setString('id', null);
      await prefs.setString('pw', null);
      runApp(MyApp());
    }
  }).catchError((e) async {
    await prefs.setString('id', null);
    await prefs.setString('pw', null);
    runApp(MyApp());
  });

}

Future<Post> fetchPost(String id, String pw) async {
  final response = await http.post (
      "https://ip2019.tk/auth/api",
      body: json.encode({
        "name": id,
        "password": pw,
      }),
      headers: {
      "content-type" : "application/json",
      "accept" : "application/json",
    },
  );
  return Post.fromJson(json.decode(response.body));
}

class MyApp extends StatelessWidget {
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
        primarySwatch: Colors.green,
      ),
      home: new MyHomePage(title: '주차부 버스 인솔자용',),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

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

class _MyHomePageState extends State<MyHomePage> {
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
// This method is rerun every time setState is called, for instance as done
// by the _incrementCounter method above.
//
// The Flutter framework has been optimized to make rerunning build methods
// fast, so that you can just rebuild anything that needs updating rather
// than having to individually change instances of widgets.
    return new Scaffold(
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
    );
  }

  Widget _showCircularProgress() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    return Container(height: 0.0, width: 0.0,);
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
        child: Form(
          key: _formKey,
          child: new ListView(
            shrinkWrap: false,
            children: <Widget>[
              _showImage(),
              Padding(padding: const EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 0.0),),
              Text("SIC2019 주차지원", textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green[900], fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
              _showEmailInput(),
              _showPasswordInput(),
              _submit(),
              Row(
                  children: <Widget>[
                    Expanded(
                        child: Divider(height: 36, color: Colors.black,)
                    ),
                    Text("  또는  "),
                    Expanded(
                        child: Divider(height: 36, color: Colors.black,)
                    ),
                  ]
              ),
              _seeAbove(),
              FlatButton(
                onPressed: () {print("Hello world");},
                child: Text("개인정보취급방침", style: TextStyle(color: Colors.blue),),
              ),
            ],
          ),
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
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        decoration: new InputDecoration(
            hintText: 'ID',
            icon: new Icon(
              Icons.account_box,
              color: Colors.green[900],
            )),
        validator: (value) => value.isEmpty ? 'ID can\'t be empty' : null,
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
            hintText: 'Password',
            icon: new Icon(
              Icons.lock,
              color: Colors.green[900],
            )),
        validator: (value) => value.isEmpty ? 'Password can\'t be empty' : null,
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
          child: new Text('자동 로그인',
              style: new TextStyle(fontSize: 20.0, color: Colors.white)),
        ),
        );
  }
  Widget _seeAbove() {
    return new Padding(
      padding: EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 0.0),
      child: RaisedButton(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () {print("Hello world");},
        child: new Text('둘러보기',
            style: new TextStyle(fontSize: 20.0, color: Colors.green[900])),
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
      await fetchPost(_email, _password).then((post) async {
        if (post.ok) {
          print(await prefs.setString('id', _email));
          await prefs.setString('pw', _password);
          await prefs.setString('token', post.token);
          Navigator.pushReplacement(
            context,
            new MaterialPageRoute(
                builder: (BuildContext context) => new TempApp()
            ),
          );
        } else {
          alert("아이디나 비밀번호를 다시 확인해주세요");
          setState(() {
            _isLoading = false;
          });
        }
      }).catchError((e) {
        alert("아이디나 비밀번호를 다시 확인해주세요");
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
}