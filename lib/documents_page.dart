import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class Document {
  final String name;
  final String path;
  Document({required this.name, required this.path});
}

class DocumentManagerPage extends StatefulWidget {
  @override
  _DocumentManagerPageState createState() => _DocumentManagerPageState();
}

class _DocumentManagerPageState extends State<DocumentManagerPage> {
  final List<Document> _documents = [];

  Future<void> _addDocument() async {
    final result = await FilePicker.platform.pickFiles();
    if (result?.files.single.path != null) {
      setState(() {
        _documents.add(
          Document(
            name: result!.files.single.name,
            path: result.files.single.path!,
          ),
        );
      });
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý tài liệu')),
      body:
          _documents.isEmpty
              ? const Center(child: Text('Chưa có tài liệu nào'))
              : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _documents.length,
                itemBuilder: (context, index) {
                  final doc = _documents[index];
                  return Stack(
                    children: [
                      Card(
                        elevation: 2,
                        child: Center(
                          child: Text(doc.name, textAlign: TextAlign.center),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => _removeDocument(index),
                          child: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDocument,
        child: const Icon(Icons.add),
      ),
    );
  }
}
