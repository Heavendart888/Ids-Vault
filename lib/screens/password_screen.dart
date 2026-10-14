import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import '../core/crypto_service.dart';
import '../models/password_entry.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final CryptoService _cryptoService = CryptoService();
  
  List<PasswordEntry> _allPasswords = [];
  List<PasswordEntry> _displayedPasswords = [];
  
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPasswords();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _displayedPasswords = List.from(_allPasswords);
      } else {
        _displayedPasswords = _allPasswords.where((entry) {
          return entry.title.toLowerCase().contains(query) || 
                 entry.username.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadPasswords() async {
    try {
      await _cryptoService.initializeKey(); 
      
      final jsonString = await _cryptoService.loadPasswordsList();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      setState(() {
        _allPasswords = jsonList.map((e) => PasswordEntry.fromJson(e)).toList();
        _displayedPasswords = List.from(_allPasswords);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading passwords: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePasswords() async {
    setState(() => _isLoading = true);
    
    try {
      final jsonString = jsonEncode(_allPasswords.map((e) => e.toJson()).toList());
      await _cryptoService.savePasswordsList(jsonString);
    } catch (e) {
      debugPrint("Error saving passwords: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save password: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _onSearchChanged(); // Refresh the list in case we are searching while adding
      }
    }
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title (e.g. Gmail)')),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username/Email')),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty && passCtrl.text.trim().isNotEmpty) {
                final newEntry = PasswordEntry(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleCtrl.text.trim(),
                  username: userCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                );
                
                setState(() => _allPasswords.add(newEntry));
                _savePasswords(); 
                Navigator.pop(context); 
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and Password are required.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deletePassword(String id) {
    setState(() {
      _allPasswords.removeWhere((p) => p.id == id);
    });
    _savePasswords();
  }

  void _copyToClipboard(String text, String type) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$type copied to clipboard!'), duration: const Duration(seconds: 2)),
    );
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
                  hintText: 'Search passwords...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: Colors.white,
              )
            : const Text('Password Vault'),
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
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _displayedPasswords.isEmpty
          ? const Center(child: Text('No passwords found.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _displayedPasswords.length,
              itemBuilder: (context, index) {
                final entry = _displayedPasswords[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: const Icon(Icons.security, color: Colors.amber),
                    title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(entry.username.isNotEmpty ? entry.username : 'No Username'),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person, color: Colors.grey),
                        title: Text(entry.username.isNotEmpty ? entry.username : 'N/A'),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () => _copyToClipboard(entry.username, 'Username'),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.key, color: Colors.grey),
                        title: const Text('••••••••'), // Hide actual password visually
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () => _copyToClipboard(entry.password, 'Password'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              onPressed: () => _deletePassword(entry.id),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Password'),
      ),
    );
  }
}