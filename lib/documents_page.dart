import 'dart:io';
import 'dart:typed_data'; // Thêm import này cho Uint8List
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:docx_to_text/docx_to_text.dart';

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

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'txt':
        return Icons.article_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _addDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'docx', 'pdf', 'jpg', 'png', 'doc'],
    );
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      setState(() {
        _documents.add(Document(name: file.name, path: file.path!));
      });
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  Future<void> _openDocument(int index) async {
    final doc = _documents[index];
    String fileContent = '';
    bool supportedFormat =
        true; // Mặc định là true, sẽ set false nếu không hỗ trợ

    try {
      final fileExtension = doc.name.split('.').last.toLowerCase();

      if (fileExtension == 'txt') {
        fileContent = await File(doc.path).readAsString();
      } else if (fileExtension == 'docx') {
        final List<int> bytes = await File(doc.path).readAsBytes();
        // SỬA Ở ĐÂY: Chuyển List<int> thành Uint8List
        fileContent = docxToText(Uint8List.fromList(bytes));
        if (fileContent.trim().isEmpty) {
          fileContent =
              'Không thể trích xuất nội dung từ file .docx này hoặc file trống.';
        }
      } else {
        fileContent =
            'Không hỗ trợ xem trước cho định dạng file .$fileExtension.';
        supportedFormat = false;
      }

      if (!mounted) return;

      if (supportedFormat && fileContent.length > 20000) {
        fileContent =
            fileContent.substring(0, 20000) +
            "\n\n... (Nội dung quá dài, đã được cắt bớt)";
      }

      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(doc.name),
              content: SingleChildScrollView(
                child: Text(
                  fileContent.isNotEmpty
                      ? fileContent
                      : (supportedFormat ? "File trống." : fileContent),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Lỗi'),
              content: Text('Không thể đọc hoặc xử lý file: ${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý tài liệu'),
        backgroundColor: Colors.indigo,
      ),
      body:
          _documents.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_off_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chưa có tài liệu nào',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nhấn nút + để thêm tài liệu mới.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
              : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 4 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: _documents.length,
                itemBuilder: (context, index) {
                  final doc = _documents[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _openDocument(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Icon(
                                  _getFileIcon(doc.name),
                                  size: 56,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  doc.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Xác nhận xóa'),
                                      content: Text(
                                        'Bạn có chắc chắn muốn xóa tài liệu "${doc.name}" không?',
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('Hủy'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: const Text(
                                            'Xóa',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                          onPressed: () {
                                            _removeDocument(index);
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDocument,
        icon: const Icon(Icons.add),
        label: const Text("Thêm tài liệu"),
        backgroundColor: Colors.indigo,
      ),
    );
  }
}
