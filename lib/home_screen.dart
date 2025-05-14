import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:inventory_scanner/auth_service.dart';
import 'package:inventory_scanner/inventory_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final InventoryService _inventoryService = InventoryService();
  final TextEditingController _barcodeController = TextEditingController();
  String _result = 'Scan a barcode or enter it below';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    if (!await _authService.isAuthenticated) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _scanBarcode() async {
    try {
      String? barcode = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Scan Barcode')),
            body: MobileScanner(
              onDetect: (BarcodeCapture capture) {
                final String? code = capture.barcodes.first.rawValue;
                if (code != null) {
                  Navigator.pop(context, code);
                }
              },
              formats: [BarcodeFormat.code128, BarcodeFormat.ean13, BarcodeFormat.qr],
            ),
          ),
        ),
      );

      if (barcode != null && barcode.isNotEmpty) {
        setState(() {
          _barcodeController.text = barcode;
        });
        await _searchItem(barcode);
      } else {
        _showSnackBar('Scan cancelled');
      }
    } catch (e) {
      print('Error scanning barcode: $e');
      _showSnackBar('Scanner error. Check camera permissions or enter barcode manually.');
    }
  }

  Future<void> _searchItem(String barcode) async {
    if (barcode.trim().isEmpty) {
      _showSnackBar('Please enter or scan a barcode');
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'Searching...';
    });

    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        _handleAuthError();
        return;
      }

      final response = await _inventoryService.getInventoryItem(token, barcode);
      setState(() {
        _result = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error searching item: ${e.toString()}';
        _isLoading = false;
      });
      print('Error searching item: $e');
    }
  }

  void _handleAuthError() async {
    setState(() {
      _result = 'Authentication error. Please login again.';
      _isLoading = false;
    });
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(220, 240, 220, 1),
              Color.fromRGBO(200, 230, 200, 1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'Enter Barcode',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _scanBarcode,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Scan Barcode'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _searchItem(_barcodeController.text),
                        icon: const Icon(Icons.search),
                        label: const Text('Search Item'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Text(
                          _result,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
