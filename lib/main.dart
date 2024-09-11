import 'package:flutter/material.dart';

import 'freeai_chatscreen.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Free AI Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FreeAIChatScreen(
          title:'FreeAI Chat',
          defaultPrompt:"You are ai chatbot. Please translate all the result in <language>."
      ),
    );
  }
}


