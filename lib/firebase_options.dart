// File generated for 事故履歴管理アプリ (Accident Manager).
// This file provides platform-specific Firebase configuration.
//
// このファイルはFirebase Consoleで取得した設定値を元に、
// Web/Android向けの初期化オプションをまとめたものです。
// iOS/macOS/Windows/Linuxは今回未対応のため、該当プラットフォームでは
// 例外をスローします(必要になったらFirebase Consoleでアプリを追加してください)。

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'Firebase Consoleでiosアプリを追加してから設定を追記してください。',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web用設定 (Firebase Console > プロジェクトの設定 > </> Webアプリ)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAf7K5AgVBCnSU3eqHh2EOhgvrkfXoBkpg',
    appId: '1:88979037871:web:c617df9019369743057e5a',
    messagingSenderId: '88979037871',
    projectId: 'idex-trouble-management',
    authDomain: 'idex-trouble-management.firebaseapp.com',
    storageBucket: 'idex-trouble-management.firebasestorage.app',
    measurementId: 'G-F2RETJYH0Z',
  );

  // Android用設定 (google-services.json より抽出)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDcmyiL1V9RWsz_GCpHT5xqm4vZC4T71kI',
    appId: '1:88979037871:android:0d206ae22d3574f7057e5a',
    messagingSenderId: '88979037871',
    projectId: 'idex-trouble-management',
    storageBucket: 'idex-trouble-management.firebasestorage.app',
  );
}
