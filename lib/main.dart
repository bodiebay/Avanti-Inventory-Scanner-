// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_scanner_new/utils/config.dart';
import 'package:inventory_scanner_new/models/inventory_item.dart';
import 'package:inventory_scanner_new/services/scanner_service.dart';
import 'package:inventory_scanner_new/services/inventory_repository.dart';
import 'package:uuid/uuid.dart';

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
  final ScannerService _scannerService = ScannerService.instance;
  final InventoryRepository _inventoryRepository = InventoryRepository.instance;
  
  List<InventoryItem> _inventoryItems = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadInventoryItems();
  }
  
  Future<void> _loadInventoryItems() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final items = await _inventoryRepository.getAllItems();
      setState(() {
        _inventoryItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading inventory items');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventoryItems,
          ),
        ],
      ),
      body: Column(
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
          
          // Inventory list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _inventoryItems.isEmpty
                    ? const Center(
                        child: Text('No items in inventory. Scan an item to add.'),
                      )
                    : ListView.builder(
                        itemCount: _inventoryItems.length,
                        itemBuilder: (context, index) {
                          final item = _inventoryItems[index];
                          return Card(
                            margin: const EdgeInsets.all(8.0),
                            child: ListTile(
                              title: Text(item.name),
                              subtitle: Text('Barcode: ${item.barcode}'),
                              trailing: Text('Qty: ${item.quantity}'),
                              onTap: () => _showItemDetails(item),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanBarcode,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    try {
      final barcode = await _scannerService.scanBarcode();
      _processBarcode(barcode);
    } catch (e) {
      _showErrorSnackBar('Error scanning barcode');
    }
  }
  
  Future<void> _processBarcode(String barcode) async {
    // First check if the item already exists
    InventoryItem? existingItem = await _inventoryRepository.getItemByBarcode(barcode);
    
    if (existingItem != null) {
      _showItemDetails(existingItem);
    } else {
      // Item doesn't exist, create a new one
      _showAddItemDialog(barcode);
    }
  }
  
  void _showAddItemDialog(String barcode) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Barcode: $barcode'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final newItem = InventoryItem(
                  id: const Uuid().v4(), // Generates a unique ID
                  barcode: barcode,
                  name: nameController.text,
                  quantity: int.tryParse(quantityController.text) ?? 1,
                  scanTime: DateTime.now(),
                );
                
                await _inventoryRepository.addItem(newItem);
                await _loadInventoryItems();
                
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  void _showItemDetails(InventoryItem item) {
    final quantityController = TextEditingController(text: '${item.quantity}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: ${item.barcode}'),
            const SizedBox(height: 8),
            Text('Last Scan: ${_formatDate(item.scanTime)}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await _inventoryRepository.deleteItem(item.id);
              await _loadInventoryItems();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedItem = InventoryItem(
                id: item.id,
                barcode: item.barcode,
                name: item.name,
                quantity: int.tryParse(quantityController.text) ?? item.quantity,
                scanTime: item.scanTime,
              );
              
              await _inventoryRepository.updateItem(updatedItem);
              await _loadInventoryItems();
              
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
