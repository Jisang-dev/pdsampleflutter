import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:math';

class Maps extends StatefulWidget {
  Maps({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState(title: this.title);
}

class _MyHomePageState extends State<Maps> {

  _MyHomePageState({this.title});

  final String title;

  PhotoViewController controller;
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
    controller = PhotoViewController()
      ..outputStateStream.listen(listener);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void listener(PhotoViewControllerValue value){
    if (preScale == null) {
      preScale = value.scale;
    }
    setState(() {
      x += value.position.dx - preX - (value.scale - preScale) * temp.dx * 7;
      y -= value.position.dy - preY + (value.scale - preScale) * temp.dy * 7;
    });
    print(x);
    print(y);
    preScale = value.scale;
    preX = value.position.dx;
    preY = value.position.dy;
  }

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
                child: PhotoView(
                  controller: controller,
                  imageProvider: AssetImage("assets/return1_b.jpg"),
                  minScale: 0.1,
                  maxScale: 4.0,
                  backgroundDecoration: BoxDecoration(
                    color: Colors.white,
                  ),
                ),
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