import 'package:flutter/material.dart';
import 'package:hello_world/pages/chat_session.dart';

void main() {
  runApp(const DecampApp());
}

class DecampApp extends StatelessWidget {
  const DecampApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Decamp AI Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ChatSession(),
    );
  }
}
