import 'package:flutter/material.dart';

class CameraTrapApp extends StatelessWidget {
  const CameraTrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      title: 'Camera Traps',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Camera Traps')),
        body: const Center(child: Text('No cameras yet')),
      ),
    );
  }
}
