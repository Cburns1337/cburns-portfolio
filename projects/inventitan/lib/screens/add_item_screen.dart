import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/item.dart';
import '../services/database_helper.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  int _quantity = 0;
  double _price = 0.0;
  String _warehouse = 'Main';

  bool _syncToCloud = true; // only matters if signed in
  bool _isSubmitting = false;

  static const List<String> _warehouses = ['Main', 'Backup', 'Overflow'];

  // ---- validators ----
  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (s.length > 80) return 'Max 80 characters';
    return null;
  }

  String? _validateQuantity(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a whole number';
    if (n < 0) return 'Cannot be negative';
    if (n > 1000000) return 'Too large';
    return null;
  }

  String? _validatePrice(String? v) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a valid price';
    if (n < 0) return 'Cannot be negative';
    if (n > 1000000) return 'Too large';
    return null;
  }

  String? _validateWarehouse(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (s.length > 80) return 'Max 80 characters';
    return null;
  }

  double _round2(double n) => (n * 100).round() / 100.0;

  Future<void> _submitItem() async {
    if (_isSubmitting) return;

    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    form.save();
    FocusScope.of(context).unfocus();

    setState(() => _isSubmitting = true);

    try {
      // 1) Save to SQLite (source of truth)
      final newItem = Item(
        name: _name.trim(),
        quantity: _quantity,
        price: _round2(_price),
        warehouse: _warehouse.trim(),
      );

      final localId = await DatabaseHelper.instance.insertItem(newItem);

      // 2) Mirror to Firestore if signed in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _syncToCloud) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('items')
            .doc('$localId'); // align docId with local row id

        await docRef.set({
          'name': _name.trim(),
          'quantity': _quantity,
          'price': _round2(_price),
          'warehouse': _warehouse.trim(),
          'description': '', // keeping schema compatible with rules
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save item: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Add New Item')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: _validateName,
                onSaved: (v) => _name = (v ?? '').trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.onetwothree),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: _validateQuantity,
                onSaved: (v) => _quantity = int.parse((v ?? '0').trim()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: _validatePrice,
                onSaved: (v) => _price = double.parse((v ?? '0').trim()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _warehouse,
                decoration: const InputDecoration(
                  labelText: 'Warehouse',
                  prefixIcon: Icon(Icons.warehouse_outlined),
                ),
                items: _warehouses
                    .map((wh) =>
                    DropdownMenuItem<String>(value: wh, child: Text(wh)))
                    .toList(),
                validator: _validateWarehouse,
                onChanged: (v) => _warehouse = v ?? 'Main',
                onSaved: (v) => _warehouse = (v ?? 'Main').trim(),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _syncToCloud && signedIn,
                onChanged: signedIn
                    ? (val) => setState(() => _syncToCloud = val ?? true)
                    : null,
                title: const Text('Sync to Cloud (Firestore)'),
                subtitle: Text(
                  signedIn
                      ? 'Creates/updates /users/{uid}/items/{localId}'
                      : 'Sign in to enable cloud sync',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitItem,
                    icon: _isSubmitting
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.save),
                    label: Text(_isSubmitting ? 'Saving…' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
