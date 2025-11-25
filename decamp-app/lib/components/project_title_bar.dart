import 'package:flutter/material.dart';
import '../pages/projects_page.dart';

/// Reusable title bar component that displays a title with a project change icon
class ProjectTitleBar extends StatelessWidget {
  final String title;
  final Color? iconColor;

  const ProjectTitleBar({
    super.key,
    required this.title,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProjectsPage()),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.import_export,
            size: 20,
            color: iconColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ],
      ),
    );
  }
}
