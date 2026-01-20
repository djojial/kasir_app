import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAC6I_rG4iQjOCsovmw14y6B2qeuSZOdIY',
    appId: '1:516717229263:web:8706d038c466b5ec24f3ba',
    messagingSenderId: '516717229263',
    projectId: 'kasir-skripsi-dj',
    authDomain: 'kasir-skripsi-dj.firebaseapp.com',
    storageBucket: 'kasir-skripsi-dj.firebasestorage.app',
    measurementId: 'G-RVYGESMGJ8',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBJuSPYaiIdB38ArSTma-tvcdWrp3d5w8I',
    appId: '1:516717229263:android:57686208d0fb838024f3ba',
    messagingSenderId: '516717229263',
    projectId: 'kasir-skripsi-dj',
    storageBucket: 'kasir-skripsi-dj.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB9sAI2yk7VWMLq0Js5EmQ0PCeR9n-mbZc',
    appId: '1:516717229263:ios:5f4a37376cf5bd9b24f3ba',
    messagingSenderId: '516717229263',
    projectId: 'kasir-skripsi-dj',
    storageBucket: 'kasir-skripsi-dj.firebasestorage.app',
    iosBundleId: 'com.example.kasirApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB9sAI2yk7VWMLq0Js5EmQ0PCeR9n-mbZc',
    appId: '1:516717229263:ios:5f4a37376cf5bd9b24f3ba',
    messagingSenderId: '516717229263',
    projectId: 'kasir-skripsi-dj',
    storageBucket: 'kasir-skripsi-dj.firebasestorage.app',
    iosBundleId: 'com.example.kasirApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAC6I_rG4iQjOCsovmw14y6B2qeuSZOdIY',
    appId: '1:516717229263:web:d849a7903ff63c4424f3ba',
    messagingSenderId: '516717229263',
    projectId: 'kasir-skripsi-dj',
    authDomain: 'kasir-skripsi-dj.firebaseapp.com',
    storageBucket: 'kasir-skripsi-dj.firebasestorage.app',
    measurementId: 'G-LZK3LT4BRT',
  );

}