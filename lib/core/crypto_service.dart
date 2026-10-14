import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

class CryptoService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  enc.Key? _encryptionKey;

  Future<void> initializeKey() async {
    String? storedKey = await _secureStorage.read(key: 'aes_master_key_v2'); 

    if (storedKey == null) {
      _encryptionKey = enc.Key.fromSecureRandom(32);
      await _secureStorage.write(
        key: 'aes_master_key_v2', 
        value: base64Encode(_encryptionKey!.bytes)
      );
    } else {
      _encryptionKey = enc.Key(Uint8List.fromList(base64Decode(storedKey)));
    }
  }

  enc.Key _deriveKeyFromPassword(String password, List<int> salt) {
    var hmac = Hmac(sha256, utf8.encode(password));
    List<int> derived = hmac.convert(salt).bytes;
    for (int i = 1; i < 1000; i++) {
      derived = hmac.convert(derived).bytes;
    }
    return enc.Key(Uint8List.fromList(derived.sublist(0, 32)));
  }

  // --- PASSWORD MANAGER METHODS ---

  Future<void> savePasswordsList(String jsonString) async {
    if (_encryptionKey == null) throw Exception("Key not initialized");
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_encryptionKey!));
    final encryptedData = encrypter.encryptBytes(utf8.encode(jsonString), iv: iv);
    
    final fileBytes = BytesBuilder();
    fileBytes.add(iv.bytes);
    fileBytes.add(encryptedData.bytes);
    
    final directory = await getApplicationDocumentsDirectory();
    final pathStr = path.join(directory.path, 'passwords_db.enc');
    await File(pathStr).writeAsBytes(fileBytes.toBytes());
  }

  Future<String> loadPasswordsList() async {
    if (_encryptionKey == null) throw Exception("Key not initialized");
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, 'passwords_db.enc'));
    
    if (!await file.exists()) return "[]";

    final fileBytes = await file.readAsBytes();
    if (fileBytes.length < 17) return "[]";
    
    final iv = enc.IV(Uint8List.fromList(fileBytes.sublist(0, 16)));
    final encryptedData = enc.Encrypted(Uint8List.fromList(fileBytes.sublist(16)));
    final encrypter = enc.Encrypter(enc.AES(_encryptionKey!));
    
    final decryptedBytes = encrypter.decryptBytes(encryptedData, iv: iv);
    return utf8.decode(decryptedBytes);
  }

  // --- BACKUP & RESTORE ---

  Future<File> createEncryptedBackup(String password) async {
    if (_encryptionKey == null) await initializeKey();

    final docs = await getEncryptedFiles();
    final archive = Archive();

    // 1. Add Documents
    for (var file in docs) {
      final bytes = await file.readAsBytes();
      final name = path.basename(file.path);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    // 2. Add Passwords Database if it exists
    final passDb = File(path.join((await getApplicationDocumentsDirectory()).path, 'passwords_db.enc'));
    if (await passDb.exists()) {
       final bytes = await passDb.readAsBytes();
       archive.addFile(ArchiveFile('passwords_db.enc', bytes.length, bytes));
    }

    if (archive.isEmpty) throw Exception("No documents or passwords found to back up.");

    final salt = enc.IV.fromSecureRandom(16).bytes;
    final derivedKey = _deriveKeyFromPassword(password, salt);
    final backupIv = enc.IV.fromSecureRandom(16);
    final backupEncrypter = enc.Encrypter(enc.AES(derivedKey));
    final encryptedKeyBytes = backupEncrypter.encryptBytes(_encryptionKey!.bytes, iv: backupIv);

    final keyBundle = {
      'salt': base64Encode(salt),
      'iv': base64Encode(backupIv.bytes),
      'key': base64Encode(encryptedKeyBytes.bytes),
    };

    final metaBytes = utf8.encode(jsonEncode(keyBundle));
    archive.addFile(ArchiveFile('vault_key.meta', metaBytes.length, metaBytes));

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw Exception("Failed to compress backup.");

    final tempDir = await getTemporaryDirectory();
    final backupPath = path.join(tempDir.path, 'VaultBackup_${DateTime.now().millisecondsSinceEpoch}.vaultbackup');

    final backupFile = File(backupPath);
    await backupFile.writeAsBytes(zipData);
    return backupFile;
  }

  Future<int> restoreEncryptedBackup(File backupFile, String password) async {
    if (_encryptionKey == null) await initializeKey();

    final bytes = await backupFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final metaArchiveFile = archive.firstWhere(
      (f) => f.name == 'vault_key.meta',
      orElse: () => throw Exception("Invalid backup file: Key metadata missing."),
    );

    final metaJson = jsonDecode(utf8.decode(metaArchiveFile.content as List<int>));
    final salt = base64Decode(metaJson['salt'] as String);
    final backupIv = enc.IV(Uint8List.fromList(base64Decode(metaJson['iv'] as String)));
    final encryptedKeyData = enc.Encrypted(Uint8List.fromList(base64Decode(metaJson['key'] as String)));

    enc.Key sourceKey;
    try {
      final derivedKey = _deriveKeyFromPassword(password, salt);
      final backupEncrypter = enc.Encrypter(enc.AES(derivedKey));
      final rawMasterKeyBytes = backupEncrypter.decryptBytes(encryptedKeyData, iv: backupIv);
      sourceKey = enc.Key(Uint8List.fromList(rawMasterKeyBytes));
    } catch (_) {
      throw Exception("Incorrect backup password or corrupted file.");
    }

    final targetDir = await getApplicationDocumentsDirectory();
    final sourceEncrypter = enc.Encrypter(enc.AES(sourceKey));
    final targetEncrypter = enc.Encrypter(enc.AES(_encryptionKey!));

    int importedCount = 0;

    for (var file in archive) {
      if (file.name == 'vault_key.meta' || !file.name.endsWith('.enc')) continue;

      final fileBytes = file.content as Uint8List;
      if (fileBytes.length < 17) continue;

      final fileIv = enc.IV(Uint8List.fromList(fileBytes.sublist(0, 16)));
      final payload = enc.Encrypted(Uint8List.fromList(fileBytes.sublist(16)));

      final decryptedData = sourceEncrypter.decryptBytes(payload, iv: fileIv);
      final newIv = enc.IV.fromSecureRandom(16);
      final reEncryptedData = targetEncrypter.encryptBytes(decryptedData, iv: newIv);

      final builder = BytesBuilder();
      builder.add(newIv.bytes);
      builder.add(reEncryptedData.bytes);

      if (file.name == 'passwords_db.enc') {
         final targetPath = path.join(targetDir.path, 'passwords_db.enc');
         await File(targetPath).writeAsBytes(builder.toBytes());
      } else {
         final parts = file.name.replaceAll('.enc', '').split('_');
         final docType = parts.isNotEmpty ? parts[0] : 'Restored';
         final fileName = '${docType}_${DateTime.now().microsecondsSinceEpoch}_$importedCount.enc';
         final targetPath = path.join(targetDir.path, fileName);
         await File(targetPath).writeAsBytes(builder.toBytes());
         importedCount++;
      }
    }

    return importedCount;
  }

  // --- DOCUMENT METHODS ---

  Future<void> encryptAndSaveFile(
    File sourceFile, 
    String docType, 
    {bool deleteTempFile = false, int fileSuffix = 0}
  ) async {
    if (_encryptionKey == null) throw Exception("Key not initialized");

    final Uint8List imageBytes = await sourceFile.readAsBytes();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_encryptionKey!));
    final encryptedData = encrypter.encryptBytes(imageBytes, iv: iv);

    final fileBytes = BytesBuilder();
    fileBytes.add(iv.bytes);
    fileBytes.add(encryptedData.bytes);

    final directory = await getApplicationDocumentsDirectory();
    final String timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    final String fileName = fileSuffix > 0 
        ? '${docType}_${timestamp}_$fileSuffix.enc'
        : '${docType}_$timestamp.enc';
    final String securePath = path.join(directory.path, fileName);
    
    await File(securePath).writeAsBytes(fileBytes.toBytes());
    
    if (deleteTempFile) {
      try {
        if (await sourceFile.exists()) {
          await sourceFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<Uint8List> decryptFile(File encryptedFile) async {
    if (_encryptionKey == null) throw Exception("Key not initialized");

    final Uint8List fileBytes = await encryptedFile.readAsBytes();
    final iv = enc.IV(Uint8List.fromList(fileBytes.sublist(0, 16)));
    final encryptedData = enc.Encrypted(Uint8List.fromList(fileBytes.sublist(16)));

    final encrypter = enc.Encrypter(enc.AES(_encryptionKey!));
    final decryptedBytes = encrypter.decryptBytes(encryptedData, iv: iv);
    
    return Uint8List.fromList(decryptedBytes);
  }

  Future<List<File>> getEncryptedFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.listSync()
        // Ensure passwords_db.enc is ignored from the images list
        .where((item) => item.path.endsWith('.enc') && !path.basename(item.path).contains('passwords_db.enc'))
        .map((item) => File(item.path))
        .toList();
  }

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

  Future<File> exportTempDecryptedFile(File encryptedFile, String docType) async {
    if (_encryptionKey == null) throw Exception("Key not initialized");

    final Uint8List fileBytes = await encryptedFile.readAsBytes();
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