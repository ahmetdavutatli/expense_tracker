import 'package:bloc/bloc.dart';
import 'package:expenses_tracker/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'simple_bloc_observer.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyD8Iolc73xQZtxK3iaRaP2a8T4otmnhj4k',
        appId: '1:525774435940:android:e2cd35afea8f5cc9b75171',
        messagingSenderId: '525774435940',
        projectId: 'expense-tracker-d669e',
        storageBucket: 'expense-tracker-d669e.appspot.com',
      )
    );
    Bloc.observer = SimpleBlocObserver();
    runApp(const MyApp());
}