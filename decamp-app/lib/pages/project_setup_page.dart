import 'package:flutter/material.dart';
import 'package:decamp/components/project_setup_view.dart';

class ProjectSetupPage extends StatelessWidget {
  const ProjectSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Project'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const ProjectSetupView(),
    );
  }
}
