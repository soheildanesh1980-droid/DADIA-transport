import 'package:flutter/material.dart';

import 'project_stages.dart';

class ProjectStagesPage extends StatelessWidget {
  const ProjectStagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stages = DadiaProjectStages.stages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مراحل توسعه DADIA'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: stages.length,
        itemBuilder: (context, index) {
          final stage = stages[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${stage.number}'),
              ),
              title: Text(stage.title),
              trailing: const Icon(
                Icons.check_circle_outline,
              ),
            ),
          );
        },
      ),
    );
  }
}
