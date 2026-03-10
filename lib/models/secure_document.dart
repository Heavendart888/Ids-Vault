import 'dart:io';
import 'package:path/path.dart' as path;

class SecureDocument {
  final File file;
  final String docType;
  final DateTime dateAdded;

  SecureDocument({required this.file, required this.docType, required this.dateAdded});

  factory SecureDocument.fromFile(File file) {
    final filename = path.basenameWithoutExtension(file.path);
    final parts = filename.split('_');
    
    String type = parts.isNotEmpty ? parts[0] : 'Unknown';
    DateTime date = DateTime.now();
    
    if (parts.length > 1) {
      final timestamp = int.tryParse(parts[1]);
      if (timestamp != null) {
        date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }

    return SecureDocument(file: file, docType: type, dateAdded: date);
  }
}