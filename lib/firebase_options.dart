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
    apiKey: 'AIzaSyARb8YOoM2mI0RH743J-JIT4bJMVZriLTY',
    appId: '1:1066739816321:web:1aa7f14f8fbe58b0923a80',
    messagingSenderId: '1066739816321',
    projectId: 'vetassist-d04ba',
    authDomain: 'vetassist-d04ba.firebaseapp.com',
    storageBucket: 'vetassist-d04ba.firebasestorage.app',
    measurementId: 'G-28WP7MHEK8',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD9DJsq_yOIBRtkrlNvoGZzZIap-gsX6ks',
    appId: '1:1066739816321:android:ed63887911fe4b4e923a80',
    messagingSenderId: '1066739816321',
    projectId: 'vetassist-d04ba',
    storageBucket: 'vetassist-d04ba.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAWl_lWXWMNvbeqFkbACjnSvemaQeT9etk',
    appId: '1:1066739816321:ios:e65c679f38a23a52923a80',
    messagingSenderId: '1066739816321',
    projectId: 'vetassist-d04ba',
    storageBucket: 'vetassist-d04ba.firebasestorage.app',
    iosBundleId: 'com.cafecircuit.vetassist',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAWl_lWXWMNvbeqFkbACjnSvemaQeT9etk',
    appId: '1:1066739816321:ios:e65c679f38a23a52923a80',
    messagingSenderId: '1066739816321',
    projectId: 'vetassist-d04ba',
    storageBucket: 'vetassist-d04ba.firebasestorage.app',
    iosBundleId: 'com.cafecircuit.vetassist',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyARb8YOoM2mI0RH743J-JIT4bJMVZriLTY',
    appId: '1:1066739816321:web:ab7528031e2989d5923a80',
    messagingSenderId: '1066739816321',
    projectId: 'vetassist-d04ba',
    authDomain: 'vetassist-d04ba.firebaseapp.com',
    storageBucket: 'vetassist-d04ba.firebasestorage.app',
    measurementId: 'G-V9TE4708XT',
  );
}
