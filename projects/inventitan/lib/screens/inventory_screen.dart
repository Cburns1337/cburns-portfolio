import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';
import '../services/database_helper.dart';
import '../widgets/inventory_list.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Item> _items = [];
  List<Item> _filteredItems = [];

  String _searchQuery = '';
  String _sortOption = 'Name';
  String _selectedWarehouse = 'All';

  final List<String> _warehouses = const ['All', 'Main', 'Backup', 'Overflow'];

  final _searchController = TextEditingController();
  bool _isPushing = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseHelper.instance.getAllItems();
    setState(() {
      _items = items;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Item> filtered = _items.where((item) {
      final matchesSearch =
      item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesWarehouse =
          _selectedWarehouse == 'All' || item.warehouse == _selectedWarehouse;
      return matchesSearch && matchesWarehouse;
    }).toList();

    switch (_sortOption) {
      case 'Quantity':
        filtered.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case 'Price':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      default:
        filtered.sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    setState(() {
      _filteredItems = filtered;
    });
  }

  void _navigateToAddItem() async {
    final result = await Navigator.pushNamed(context, '/add');
    if (result == true) _loadItems();
  }

  Future<void> _pushAllToCloud() async {
    if (_isPushing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to enable cloud sync.')),
      );
      return;
    }

    setState(() => _isPushing = true);
    final uid = user.uid;
    int pushed = 0;
    int skipped = 0;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('items');

      for (final item in _items) {
        if (item.id == null) {
          skipped++;
          continue;
        }
        final doc = col.doc('${item.id}');
        batch.set(doc, item.toFirestoreWrite(), SetOptions(merge: true));
        pushed++;
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pushed $pushed item(s) to cloud. Skipped: $skipped')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cloud sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPushing = false);
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search items...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _applyFilters();
              });
            },
          ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (value) {
          _searchQuery = value;
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          DropdownButton<String>(
            value: _sortOption,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _sortOption = value;
                  _applyFilters();
                });
              }
            },
            items: const ['Name', 'Quantity', 'Price'].map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text('Sort: $option'),
              );
            }).toList(),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _selectedWarehouse,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedWarehouse = value;
                  _applyFilters();
                });
              }
            },
            items: _warehouses
                .map((wh) =>
                DropdownMenuItem(value: wh, child: Text('Warehouse: $wh')))
                .toList(),
          ),
          const Spacer(),
          Text(
            '${_filteredItems.length} item(s)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showItemDetail(Item item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected: ${item.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Tracker'),
        actions: [
          if (signedIn)
            Tooltip(
              message: _isPushing ? 'Syncing…' : 'Push all to Cloud',
              child: IconButton(
                icon: _isPushing
                    ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                onPressed: _isPushing ? null : _pushAllToCloud,
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!signedIn)
            Container(
              width: double.infinity,
              // FIX: use withValues instead of withOpacity
              color: Colors.amber.withValues(alpha: 0.15),
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Not signed in — local-only mode. Sign in to enable cloud sync.',
                textAlign: TextAlign.center,
              ),
            ),
          _buildSearchBar(),
          _buildFilterRow(),
          Expanded(
            child: InventoryList(items: _filteredItems, onTap: _showItemDetail),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddItem,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }
}
