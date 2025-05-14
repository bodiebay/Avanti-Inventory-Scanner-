// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_scanner_new/utils/config.dart';
import 'package:inventory_scanner_new/models/inventory_item.dart';
import 'package:inventory_scanner_new/utils/simulator_mode.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const MyApp());
  }, (error, stackTrace) {
    print('Uncaught error: $error');
    print('Stack trace: $stackTrace');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.green.shade200,
        scaffoldBackgroundColor: Colors.green.shade50,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromRGBO(144, 238, 144, 1),
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color.fromRGBO(0, 100, 0, 1)),
          bodyMedium: TextStyle(color: Color.fromRGBO(0, 100, 0, 1)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(152, 251, 152, 1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: const Color.fromRGBO(240, 255, 240, 1),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _lastScannedBarcode;
  String _itemDescription = '';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Scanner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Simulator mode indicator
            if (AppConfig.isSimulator)
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.amber.shade100,
                child: const Row(
                  children: [
                    Icon(Icons.computer, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Running in Simulator Mode', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
            const SizedBox(height: 20),
            
            // Scan result display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last Scan:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_lastScannedBarcode ?? 'No barcode scanned yet'),
                    if (_itemDescription.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Item Description:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_itemDescription),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Scan button
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Barcode'),
              onPressed: _scanBarcode,
            ),
            
            const SizedBox(height: 12),
            
            // Manual entry button
            OutlinedButton.icon(
              icon: const Icon(Icons.keyboard),
              label: const Text('Manual Entry'),
              onPressed: _showManualEntryDialog,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    // Simulate barcode scanning in simulator mode
    if (AppConfig.isSimulator) {
      String barcode = await MobileScannerStub.scanBarcode();
      _processBarcode(barcode);
    } else {
      // In a real device, we would use mobile_scanner
      // This will be implemented in a separate scanner_service.dart
      // For now, just simulate with a fixed value
      _processBarcode("MMFK3LL");
    }
  }
  
  void _processBarcode(String barcode) {
    setState(() {
      _lastScannedBarcode = barcode;
      
      // Simulate looking up item description
      switch (barcode) {
        case 'MMFK3LL':
          _itemDescription = 'Apple Mac Mini M2, 8GB RAM, 256GB SSD';
          break;
        case 'SPP6TVD91W5':
          _itemDescription = 'MacBook Pro 14", M3 Pro, 18GB RAM, 512GB SSD';
          break;
        case 'MD223LL/A':
          _itemDescription = 'iPad mini, 64GB, Wi-Fi';
          break;
        default:
          _itemDescription = 'Unknown item (ID: $barcode)';
      }
    });
  }
  
  void _showManualEntryDialog() {
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'e.g., MMFK3LL',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                _processBarcode(textController.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
