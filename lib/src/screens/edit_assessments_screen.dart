import 'package:flutter/material.dart';

class EditAssessmentsScreen extends StatefulWidget {
  const EditAssessmentsScreen({super.key});

  @override
  State<EditAssessmentsScreen> createState() => _EditAssessmentsScreenState();
}

class _EditAssessmentsScreenState extends State<EditAssessmentsScreen> {
  final List<Map<String, dynamic>> questions = List.generate(10, (i) => {
        'question': 'Question ${i + 1}: Lorem ipsum dolor sit amet?',
        'category': ['Sort', 'Set', 'Shine', 'Standardize', 'Sustain'][i % 5],
      });

  void _edit(int index) {
    final controller = TextEditingController(text: questions[index]['question'] as String);
    String category = questions[index]['category'] as String;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Assessment Question'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: category,
              isExpanded: true,
              items: const ['Sort', 'Set', 'Shine', 'Standardize', 'Sustain']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => category = v ?? category),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                questions[index] = {
                  'question': controller.text,
                  'category': category,
                };
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _add() {
    setState(() {
      questions.add({'question': 'New question', 'category': 'Sort'});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Assessments'),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _add, icon: const Icon(Icons.add))
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final q = questions[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(q['question'] as String),
              subtitle: Text('Category: ${q['category']}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _edit(index),
              ),
            ),
          );
        },
      ),
    );
  }
}
