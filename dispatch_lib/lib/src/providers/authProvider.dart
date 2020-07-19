import 'dart:convert';

import 'package:dispatch_lib/src/models/constants.dart';
import 'package:dispatch_lib/src/models/dispatch.dart';
import 'package:dispatch_lib/src/models/response.dart';
import 'package:dispatch_lib/src/models/rider.dart';
import 'package:dispatch_lib/src/models/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';

final dispatchRef = FirebaseDatabase.instance.reference().child('dispatch');

User loggedInUser;
Rider loggedInRider;
final userRef = FirebaseDatabase.instance.reference().child('users');
final riderRef = FirebaseDatabase.instance.reference().child('riders');
final tokenRef = FirebaseDatabase.instance.reference().child('tokens');

class AUthProvider with ChangeNotifier {
  FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  bool isLoggedIn = false;
  bool hasOnboarded = false;
  Future<ResponseModel> login(String email, String password) async {
    try {
      final authResult = await firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);
      final dataSnapShot = await userRef.child(authResult.user.uid).once();
      FirebaseMessaging messaging = FirebaseMessaging();
      final token = await messaging.getToken();
      loggedInUser = User(
          dataSnapShot.value['id'],
          dataSnapShot.value['fullname'],
          dataSnapShot.value['phoneNumber'],
          dataSnapShot.value['email'],
          password,
          dataSnapShot.value['userType'],
          dataSnapShot.value['token']);
      await userRef.child(authResult.user.uid).set({
        "id": authResult.user.uid,
        "email": loggedInUser.email,
        "fullname": loggedInUser.fullName,
        "phoneNumber": loggedInUser.phoneNumber,
        "userType": loggedInUser.userType,
        "token": token
      });
      storeAutoData(loggedInUser);
      storeAppOnBoardingData(loggedInUser.id);
      return ResponseModel(true, "User SignIn Sucessfull");
    } catch (e) {
      return ResponseModel(false, e.toString());
    }
  }

  Future<ResponseModel> signUp(User user) async {
    try {
      final authResult = await firebaseAuth.createUserWithEmailAndPassword(
          email: user.email, password: user.password);
      FirebaseMessaging messaging = FirebaseMessaging();
      final token = await messaging.getToken();
      await userRef.child(authResult.user.uid).set({
        "id": authResult.user.uid,
        "email": user.email,
        "fullname": user.fullName,
        "phoneNumber": user.phoneNumber,
        "userType": user.userType,
        "token": token
      });
      loggedInUser = new User(authResult.user.uid, user.fullName, user.fullName,
          user.email, user.password, user.userType, user.token);
      final autoLoggedUser = User(
          authResult.user.uid,
          user.email,
          user.fullName,
          user.phoneNumber,
          user.password,
          user.userType,
          user.token);
      storeAutoData(autoLoggedUser);
      storeAppOnBoardingData(loggedInUser.id);
      return ResponseModel(true, "User SignUp Sucessfull");
    } catch (e) {
      return ResponseModel(false, e.toString());
    }
  }

  Future<ResponseModel> logOut() async {
    try {
      await firebaseAuth.signOut();
      loggedInUser = null;
      deleteAutoData();
      return ResponseModel(true, "User LogOut Sucessfull");
    } catch (e) {
      return ResponseModel(false, e.toString());
    }
  }

  Future<Tuple3<ResponseModel, Rider, Dispatch>> getPickUpDetails(
      String riderId, String dispatchId) async {
    Rider rider;
    Dispatch dispatch;
    Tuple3<ResponseModel, Rider, Dispatch> responseModel;
    try {
      await riderRef.child(riderId).once().then((DataSnapshot dataSnapshot) {
        final value = dataSnapshot.value as Map<dynamic, dynamic>;
        rider = new Rider(
            value['id'],
            value['fullname'],
            value['phoneNumber'],
            value['email'],
            value['password'],
            value['hasActiveDispatch'],
            value['token']);
      });

      await dispatchRef
          .child(dispatchId)
          .once()
          .then((DataSnapshot dataSnapshot) {
        final value = dataSnapshot.value as Map<dynamic, dynamic>;
        dispatch = new Dispatch(
            id: value['id'],
            userId: value['userId'],
            trackingNo: value['trackingNo'],
            dispatchRiderId: value['dispatchRiderId'],
            dispatchDate: DateTime.parse(value['dispatchDate'].toString()),
            pickUpLocation: value['pickUpLocation'],
            dispatchDestination: value['dispatchDestination'],
            dispatchBaseFare:
                double.parse(value['dispatchBaseFare'].toString()),
            dispatchTotalFare:
                double.parse(value['dispatchTotalFare'].toString()),
            dispatchType: value['dispatchType'],
            dispatchStatus: value['dispatchStatus'],
            currentLocation: value['currentLocation'],
            estimatedDIspatchDuration: value['estimatedDIspatchDuration'],
            estimatedDistance: value['estimatedDistance'],
            dispatchReciever: value['dispatchReciever'],
            dispatchRecieverPhone: value['dispatchRecieverPhone'],
            dispatchDescription: value['dispatchDescription']);
      });

      responseModel = Tuple3<ResponseModel, Rider, Dispatch>(
          ResponseModel(true, "rider fetched Sucessfull"), rider, dispatch);
    } catch (e) {
      responseModel = Tuple3<ResponseModel, Rider, Dispatch>(
          ResponseModel(false, e.toString()), null, null);
    }
    return responseModel;
  }

  Future<ResponseModel> updateProfile(
      String fullname, String phoneNumber) async {
    try {
      userRef
          .child(loggedInUser.id)
          .update({'fullname': fullname, 'phoneNumber': phoneNumber});
      loggedInUser = User(
          loggedInUser.id,
          fullname,
          phoneNumber,
          loggedInUser.email,
          loggedInUser.password,
          loggedInUser.userType,
          loggedInUser.token);
      return ResponseModel(true, "User Profile Updated Sucessfully");
    } catch (e) {
      return ResponseModel(false, e.toString());
    }
  }

  Future<ResponseModel> updatePassword(String password) async {
    try {
      FirebaseUser user = await FirebaseAuth.instance.currentUser();
      await user.updatePassword(password);
      return ResponseModel(true, "Password Update Sucessfull");
    } catch (e) {
      return ResponseModel(false, e.toString());
    }
  }

  void storeAutoData(User user) async {
    final sharedPrefs = await SharedPreferences.getInstance();
    final logOnData = json.encode({
      'id': user.id,
      'fullName': user.fullName,
      'password': user.password,
      'email': user.email,
      'phoneNumber': user.phoneNumber,
      'token': user.token
    });
    sharedPrefs.setString(Constants.autoLogOnData, logOnData);
  }

  void storeAutoRiderData(Rider rider) async {
    final sharedPrefs = await SharedPreferences.getInstance();
    final logOnData = json.encode({
      'id': rider.id,
      'fullName': rider.fullName,
      'password': rider.password,
      'email': rider.email,
      'phoneNumber': rider.phoneNumber,
      'hasActiveDispatch': rider.hasActiveDispatch,
      'token': rider.token
    });
    sharedPrefs.setString(Constants.autoLogOnData, logOnData);
  }

  void storeAppOnBoardingData(String userId) async {
    final sharedPrefs = await SharedPreferences.getInstance();
    final logOnData = json.encode({
      'id': userId,
    });
    sharedPrefs.setString(Constants.onBoardingData, logOnData);
  }

  void deleteAutoData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(Constants.autoLogOnData);
  }

  Future<bool> tryAutoLogin() async {
    checkUserOnBoarding();
    final sharedPref = await SharedPreferences.getInstance();
    if (!sharedPref.containsKey(Constants.autoLogOnData)) {
      return false;
    }
    final sharedData = sharedPref.getString(Constants.autoLogOnData);
    final logOnData = json.decode(sharedData) as Map<String, Object>;
    //gdt latest token
    FirebaseMessaging messaging = FirebaseMessaging();
    final token = await messaging.getToken();
    loggedInUser = new User(
        logOnData['id'],
        logOnData['fullName'],
        logOnData['phoneNumber'],
        logOnData['email'],
        logOnData['password'],
        logOnData['userType'],
        token);
    isLoggedIn = true;
    notifyListeners();
    return true;
  }

  checkUserOnBoarding() async {
    final sharedPref = await SharedPreferences.getInstance();
    if (!sharedPref.containsKey(Constants.onBoardingData)) {
      hasOnboarded = false;
    } else {
      hasOnboarded = true;
    }
  }

  //imported form rider app
  Future<ResponseModel> updateRiderProfile(
      String fullname, String phoneNumber) async {
    try {
      riderRef
          .child(loggedInRider.id)
          .update({'fullname': fullname, 'phoneNumber': phoneNumber});
      loggedInRider = Rider(
          loggedInRider.id,
          fullname,
          phoneNumber,
          loggedInRider.email,
          loggedInRider.password,
          loggedInRider.hasActiveDispatch,
          loggedInRider.token);
      return ResponseModel(true, "Rider Profile Updated Sucessfully");
    } catch (e) {
      return ResponseModel(false, e.toString());
    }
  }

  Future<ResponseModel> loginRider(String email, String password) async {
    try {
      final authResult = await firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);
      final dataSnapShot = await riderRef.child(authResult.user.uid).once();
      FirebaseMessaging messaging = FirebaseMessaging();
      final token = await messaging.getToken();
      loggedInRider = Rider(
          dataSnapShot.value['id'],
          dataSnapShot.value['fullname'],
          dataSnapShot.value['phoneNumber'],
          dataSnapShot.value['email'],
          password,
          dataSnapShot.value['hasActiveDispatch'],
          token);
      await riderRef.child(authResult.user.uid).set({
        "id": authResult.user.uid,
        "email": loggedInRider.email,
        "fullname": loggedInRider.fullName,
        "phoneNumber": loggedInRider.phoneNumber,
        "token": token
      });
      storeAutoRiderData(loggedInRider);
      storeAppOnBoardingData(loggedInRider.id);
      isLoggedIn = true;
      notifyListeners();
      return ResponseModel(true, "Rider SignIn Sucessfull");
    } catch (e) {
      return ResponseModel(false, e.toString());
    }
  }

  Future<ResponseModel> signUpRider(Rider rider) async {
    try {
      final authResult = await firebaseAuth.createUserWithEmailAndPassword(
          email: rider.email, password: rider.password);
      FirebaseMessaging messaging = FirebaseMessaging();
      final token = await messaging.getToken();
      await riderRef.child(authResult.user.uid).set({
        "id": authResult.user.uid,
        "email": rider.email,
        "fullname": rider.fullName,
        "phoneNumber": rider.phoneNumber,
        "token": token
      });
      loggedInRider = new Rider(authResult.user.uid, rider.fullName,
          rider.phoneNumber, rider.email, rider.password, false, token);
      storeAutoRiderData(loggedInRider);
      storeAppOnBoardingData(loggedInRider.id);
      return ResponseModel(true, "Rider SignUp Sucessfull");
    } catch (e) {
      return ResponseModel(false, e.toString());
    }
  }

  Future<bool> tryRiderAutoLogin() async {
    checkUserOnBoarding();
    final sharedPref = await SharedPreferences.getInstance();
    if (!sharedPref.containsKey(Constants.autoLogOnData)) {
      return false;
    }
    final sharedData = sharedPref.getString(Constants.autoLogOnData);
    final logOnData = json.decode(sharedData) as Map<String, Object>;
    FirebaseMessaging messaging = FirebaseMessaging();
    final token = await messaging.getToken();
    loggedInRider = new Rider(
        logOnData['id'],
        logOnData['fullName'],
        logOnData['phoneNumber'],
        logOnData['email'],
        logOnData['password'],
        logOnData['hasActiveDispatch'],
        token);
    isLoggedIn = true;
    notifyListeners();
    return true;
  }
}
