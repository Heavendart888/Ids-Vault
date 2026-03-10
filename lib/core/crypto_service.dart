import 'dart:io';
import 'dart:convert'; // Required for Base64 encoding/decoding
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as path;

class CryptoService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  enc.Key? _encryptionKey;

  // --- 1. THE FIX: SECURE BASE64 KEY STORAGE ---
  Future<void> initializeKey() async {
    // We use a new key name to ensure a clean slate and avoid reading corrupted old keys
    String? storedKey = await _secureStorage.read(key: 'aes_master_key_v2'); 

    if (storedKey == null) {
      // Generate a cryptographically secure 256-bit key
      _encryptionKey = enc.Key.fromSecureRandom(32);
      
      // Safely encode to Base64 (Strings corrupt raw bytes!)
      await _secureStorage.write(
        key: 'aes_master_key_v2', 
        value: base64Encode(_encryptionKey!.bytes)
      );
    } else {
      // Safely decode from Base64 back into raw bytes
      _encryptionKey = enc.Key(Uint8List.fromList(base64Decode(storedKey)));
    }
  }

  // --- 2. ENCRYPT & BUNDLE DYNAMIC IV ---
  Future<void> encryptAndSaveFile(File sourceFile, String docType, {bool deleteTempFile = false}) async {
    if (_encryptionKey == null) throw Exception("Key not initialized");

    final Uint8List imageBytes = await sourceFile.readAsBytes();
    
    // Generate a unique 16-byte IV for THIS specific file (Best Practice)
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_encryptionKey!));
    
    final encryptedData = encrypter.encryptBytes(imageBytes, iv: iv);

    // Bundle the IV (first 16 bytes) with the Encrypted Data
    final fileBytes = BytesBuilder();
    fileBytes.add(iv.bytes);
    fileBytes.add(encryptedData.bytes);

    final directory = await getApplicationDocumentsDirectory();
    final String fileName = '${docType}_${DateTime.now().millisecondsSinceEpoch}.enc';
    final String securePath = path.join(directory.path, fileName);
    
    await File(securePath).writeAsBytes(fileBytes.toBytes());
    
    // Safely attempt to delete the source file if requested
    if (deleteTempFile) {
      try {
        if (await sourceFile.exists()) {
          await sourceFile.delete();
        }
      } catch (e) {
        // Silently fail if OS blocks deletion of public files
      }
    }
  }

  // --- 3. EXTRACT IV & DECRYPT ---
  Future<Uint8List> decryptFile(File encryptedFile) async {
    if (_encryptionKey == null) throw Exception("Key not initialized");

    final Uint8List fileBytes = await encryptedFile.readAsBytes();
    
    // Extract the 16-byte IV from the front of the file
    final iv = enc.IV(Uint8List.fromList(fileBytes.sublist(0, 16)));
    
    // Extract the actual encrypted document data
    final encryptedData = enc.Encrypted(Uint8List.fromList(fileBytes.sublist(16)));

    final encrypter = enc.Encrypter(enc.AES(_encryptionKey!));
    final decryptedBytes = encrypter.decryptBytes(encryptedData, iv: iv);
    
    return Uint8List.fromList(decryptedBytes);
  }

  Future<List<File>> getEncryptedFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.listSync()
        .where((item) => item.path.endsWith('.enc'))
        .map((item) => File(item.path))
        .toList();
  }

  // --- FILE MANAGEMENT METHODS ---

  Future<void> deleteDocument(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> renameDocument(File file, String newDocType) async {
    if (!await file.exists()) return;

    final directory = path.dirname(file.path);
    final filename = path.basenameWithoutExtension(file.path);
    final parts = filename.split('_');
    
    String timestamp = parts.length > 1 ? parts[1] : DateTime.now().millisecondsSinceEpoch.toString();
    final newPath = path.join(directory, '${newDocType}_$timestamp.enc');
    await file.rename(newPath);
  }

  // --- SECURE SHARE EXPORT ---

  Future<File> exportTempDecryptedFile(File encryptedFile, String docType) async {
    if (_encryptionKey == null) throw Exception("Key not initialized");

    final Uint8List fileBytes = await encryptedFile.readAsBytes();
    
    // Extract IV and data just like decryptFile
    final iv = enc.IV(Uint8List.fromList(fileBytes.sublist(0, 16)));
    final encryptedData = enc.Encrypted(Uint8List.fromList(fileBytes.sublist(16)));

    final encrypter = enc.Encrypter(enc.AES(_encryptionKey!));
    final decryptedBytes = encrypter.decryptBytes(encryptedData, iv: iv);

    final tempDir = await getTemporaryDirectory();
    final tempPath = path.join(tempDir.path, 'shared_${docType}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(decryptedBytes);
    
    return tempFile;
  }
}