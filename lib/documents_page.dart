import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'components/GlassmorphicToggle.dart' as gm;

class Document {
  final String name;
  final String path;
  Document({required this.name, required this.path});
}

class DocumentManagerPage extends StatefulWidget {
  const DocumentManagerPage({super.key});

  @override
  _DocumentManagerPageState createState() => _DocumentManagerPageState();
}

// Thêm SingleTickerProviderStateMixin để sử dụng AnimationController
class _DocumentManagerPageState extends State<DocumentManagerPage> with SingleTickerProviderStateMixin {
  final List<Document> _documents = [];

  // Các biến cho animation nền
  late AnimationController _controller;
  late Animation<Color?> _color1;
  late Animation<Color?> _color2;

  @override
  void initState() {
    super.initState();

    // Khởi tạo animation controller
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    // Khởi tạo animation màu
    _color1 = ColorTween(
      begin: const Color(0xFF1E3A8A), // Blue Dark
      end: const Color(0xFF9333EA), // Purple
    ).animate(_controller);

    _color2 = ColorTween(
      begin: const Color(0xFF3B82F6), // Blue Light
      end: const Color(0xFFF472B6), // Pink
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose(); // Hủy controller khi widget bị xóa
    super.dispose();
  }

  // Các hàm logic bên trong không thay đổi
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'txt': return Icons.article_outlined;
      case 'doc': case 'docx': return Icons.description_outlined;
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'jpg': case 'jpeg': case 'png': return Icons.image_outlined;
      case 'xls': case 'xlsx': return Icons.table_chart_outlined;
      case 'ppt': case 'pptx': return Icons.slideshow_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _addDocument() async {
    try {
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn tệp: ${e.toString()}')),
      );
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  Future<void> _openDocument(int index) async {
    final doc = _documents[index];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đang mở ${doc.name}')),
    );
  }

  void _showDeleteConfirmation(int index) {
    final doc = _documents[index];
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            title: Text(
              'Xác nhận xóa',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Bạn có chắc chắn muốn xóa tài liệu "${doc.name}" không?',
              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8)),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Hủy', style: GoogleFonts.inter(color: Colors.white)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: Text('Xóa', style: GoogleFonts.inter(color: const Color(0xFFff7ab6))),
                onPressed: () {
                  _removeDocument(index);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Nền trong suốt để thấy gradient
      backgroundColor: Colors.transparent,
      // Nút FAB mới với hiệu ứng glassmorphism
      floatingActionButton: gm.GlassmorphicContainer(
        borderRadius: 50,
        child: SizedBox(
          width: 60,
          height: 60,
          child: IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 30),
            onPressed: _addDocument,
            tooltip: 'Thêm tài liệu',
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Container chứa nền gradient động
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_color1.value!, _color2.value!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header ẩn + nút back kính mờ
                SizedBox(
                  height: kToolbarHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 0),
                          child: gm.GlassmorphicContainer(
                            borderOpacity: 0.12,
                            borderWidth: 1,
                            isPerformanceMode: true,
                            child: SizedBox.square(
                              dimension: 44,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                                onPressed: () => Navigator.of(context).pop(),
                                tooltip: 'Quay lại',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tiêu đề trang
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tài liệu',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quản lý các tệp tin của bạn',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Expanded(
                  child: _documents.isEmpty
                      ? _buildEmptyState()
                      : _buildDocumentsGrid(),
                ),
                // Nút cũ đã được xóa khỏi đây
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có tài liệu nào',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn nút "+" để bắt đầu.',
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsGrid() {
    // ... (Không có thay đổi trong hàm này)
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return gm.GlassmorphicContainer(

          borderRadius: 16,
          child: InkWell(
            onTap: () => _openDocument(index),
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.05),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        _getFileIcon(doc.name),
                        size: 52,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        doc.name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
                      splashRadius: 20,
                      onPressed: () => _showDeleteConfirmation(index),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}