import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../core/crypto_service.dart';
import '../models/secure_document.dart';
import 'auth_screen.dart';
import 'camera_screen.dart';

// IMPORTANT: Import main.dart to access the global isIntentionalPause variable
import '../main.dart'; 

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final CryptoService _cryptoService = CryptoService();
  
  List<SecureDocument> _allDocuments = [];
  List<SecureDocument> _displayedDocuments = [];
  
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initVault();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initVault() async {
    await _cryptoService.initializeKey();
    await _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final files = await _cryptoService.getEncryptedFiles();
    setState(() {
      _allDocuments = files.map((f) => SecureDocument.fromFile(f)).toList();
      _displayedDocuments = List.from(_allDocuments);
      _isLoading = false;
      
      _onSearchChanged(); // Re-apply filter if list changes while searching
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _displayedDocuments = List.from(_allDocuments);
      } else {
        _displayedDocuments = _allDocuments.where((doc) {
          return doc.docType.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                title: const Text('Secure In-App Camera'),
                subtitle: const Text('Zero-trace. Leaves no copy on device.'),
                onTap: () {
                  Navigator.pop(context);
                  _captureFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.tealAccent),
                title: const Text('Import from Device Storage'),
                subtitle: const Text('Pick from Gallery, Downloads, or Drive.'),
                onTap: () {
                  Navigator.pop(context);
                  _importFromStorage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _captureFromCamera() async {
    // 1. Give the app a Hall Pass so the camera screen doesn't lock it
    isIntentionalPause = true;

    final String? imagePath = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );

    // 2. Revoke the Hall Pass immediately when returning from camera
    isIntentionalPause = false;

    if (imagePath == null) return;

    final String? docType = await _askForDocumentType();
    if (docType != null) {
      setState(() => _isLoading = true);
      await _cryptoService.encryptAndSaveFile(File(imagePath), docType, deleteTempFile: true);
      await _loadDocuments();
    }
  }

  Future<void> _importFromStorage() async {
    try {
      // 1. Give the app a Hall Pass before opening the native Android gallery
      isIntentionalPause = true;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, 
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'], 
        allowMultiple: false,
      );

      // 2. Revoke the Hall Pass immediately when they pick a file or cancel
      isIntentionalPause = false;

      if (result != null && result.files.single.path != null) {
        File pickedFile = File(result.files.single.path!);

        final String? docType = await _askForDocumentType();
        if (docType != null) {
          setState(() => _isLoading = true);
          await _cryptoService.encryptAndSaveFile(pickedFile, docType, deleteTempFile: true);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved to Vault. Manually delete original if highly sensitive.'),
                duration: Duration(seconds: 4),
              ),
            );
          }
          await _loadDocuments();
        }
      }
    } catch (e) {
      // Ensure the pass is revoked even if the file picker crashes
      isIntentionalPause = false;
      debugPrint("Error picking file: $e");
    }
  }

  Future<String?> _askForDocumentType() async {
    if (!mounted) return null;
    return await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Document Type'),
        children: ['Aadhaar', 'PAN Card', 'License', 'Other'].map((type) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, type),
            child: Text(type, style: const TextStyle(fontSize: 16)),
          );
        }).toList(),
      ),
    );
  }

  void _showDocumentMenu(SecureDocument doc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Manage "${doc.docType}"', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.greenAccent),
                title: const Text('Share Securely'),
                onTap: () {
                  Navigator.pop(context);
                  _shareDocument(doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blueAccent),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  _renameDocument(doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text('Delete Permanently'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(doc);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareDocument(SecureDocument doc) async {
    setState(() => _isLoading = true);
    File? tempFile;

    try {
      tempFile = await _cryptoService.exportTempDecryptedFile(doc.file, doc.docType);
      setState(() => _isLoading = false);

      // Give Hall Pass before opening Android Share Menu
      isIntentionalPause = true;

      await Share.shareXFiles(
        [XFile(tempFile.path)], 
        text: 'Secure Document: ${doc.docType}'
      );

      // Revoke Hall Pass
      isIntentionalPause = false;

      if (await tempFile.exists()) {
        await tempFile.delete();
        debugPrint("Temporary unencrypted file securely destroyed.");
      }
    } catch (e) {
      isIntentionalPause = false; // Always revoke on error
      setState(() => _isLoading = false);
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> _renameDocument(SecureDocument doc) async {
    TextEditingController controller = TextEditingController(text: doc.docType);
    
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != doc.docType) {
      setState(() => _isLoading = true);
      await _cryptoService.renameDocument(doc.file, newName);
      await _loadDocuments(); 
    }
  }

  Future<void> _confirmDelete(SecureDocument doc) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to permanently delete "${doc.docType}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _cryptoService.deleteDocument(doc.file);
      await _loadDocuments(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search documents...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: Colors.white,
              )
            : const Text('Secure Vault', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen())),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _displayedDocuments.isEmpty 
          ? const Center(child: Text('No documents found.', style: TextStyle(color: Colors.grey)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: _displayedDocuments.length,
              itemBuilder: (context, index) {
                final doc = _displayedDocuments[index];
                return _buildDocCard(doc);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadOptions,
        icon: const Icon(Icons.add),
        label: const Text('Add Document'),
      ),
    );
  }

  Widget _buildDocCard(SecureDocument doc) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: () => _showDecryptedImage(doc),
        onLongPress: () => _showDocumentMenu(doc),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 48, color: Colors.blueAccent),
            const SizedBox(height: 12),
            Text(doc.docType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('${doc.dateAdded.day}/${doc.dateAdded.month}/${doc.dateAdded.year}', 
                 style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showDecryptedImage(SecureDocument doc) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: FutureBuilder<Uint8List>(
          future: _cryptoService.decryptFile(doc.file),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData) {
              return InteractiveViewer( 
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(snapshot.data!),
                ),
              );
            }
            return const Center(child: Text('Error decrypting.', style: TextStyle(color: Colors.white)));
          },
        ),
      ),
    );
  }
}