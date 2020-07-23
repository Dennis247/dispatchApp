import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String currentLocation;
  String locationError;
  String motionChange;
  String bgState;
  String motionACtivity;
  @override
  void initState() {
    super.initState();
    // 1.  Listen to events (See docs for all 12 available events).
    bg.BackgroundGeolocation.onLocation(_onLocation, _onLocationError);
    bg.BackgroundGeolocation.onMotionChange(_onMotionChange);
    bg.BackgroundGeolocation.onActivityChange(_onActivityChange);
    bg.BackgroundGeolocation.onConnectivityChange(_onConnectivityChange);
    bg.BackgroundGeolocation.onHttp(_onHttp);

    // 2.  Configure the plugin
    bg.BackgroundGeolocation.ready(bg.Config(
            reset: true,
            debug: true,
            logLevel: bg.Config.LOG_LEVEL_VERBOSE,
            desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
            distanceFilter: 10.0,
            encrypt: false,
            stopOnTerminate: false,
            startOnBoot: true,
            enableHeadless: true))
        .then((bg.State state) {
      print("[ready] ${state.toMap()}");
      setState(() {
        bgState = state.toMap().toString();
        // _enabled = state.enabled;
        // _isMoving = state.isMoving;
      });
    }).catchError((error) {
      print('[ready] ERROR: $error');
    });
  }

  void _onLocation(bg.Location location) {
    print('[location] - $location');
    setState(() {
      currentLocation =
          "latitude  : ${location.coords.latitude}  \n   longitude ${location.coords.longitude}";
    });
  }

  void _onLocationError(bg.LocationError error) {
    print('[location] ERROR - $error');
    setState(() {
      locationError = "error  : $error";
    });
  }

  void _onMotionChange(bg.Location location) {
    print('[motionchange] - $location');
  }

  void _onActivityChange(bg.ActivityChangeEvent event) {
    print('[activitychange] - $event');
    setState(() {
      // _motionActivity = event.activity;
      motionACtivity = event.activity;
    });
  }

  void _onHttp(bg.HttpEvent event) async {
    print('[${bg.Event.HTTP}] - $event');
  }

  void _onConnectivityChange(bg.ConnectivityChangeEvent event) {
    print('$event');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Demo Location"),
      ),
      body: Container(
          child: Column(
        children: <Widget>[
          Text("Current Location is $currentLocation"),
          Text("Error  is $locationError"),
          Text("Motion Change is $motionChange"),
          Text("Bg State  is $bgState"),
          Text("Motion Activity  is $motionACtivity"),
        ],
      )),
    );
  }
}
