import 'package:flutter/material.dart';
import '../models/item.dart';

class InventoryList extends StatelessWidget {
  final List<Item> items;
  final void Function(Item) onTap;

  /// Optional display toggles (do not break existing call sites)
  final bool showDescription;
  final bool showUpdatedAt;

  const InventoryList({
    required this.items,
    required this.onTap,
    this.showDescription = true,
    this.showUpdatedAt = true,
    super.key,
  });

  String _relative(DateTime dt) {
    final now = DateTime.now();
    final d = now.difference(dt);
    if (d.inSeconds.abs() < 60) return 'just now';
    if (d.inMinutes.abs() < 60) return '${d.inMinutes.abs()}m ago';
    if (d.inHours.abs() < 24) return '${d.inHours.abs()}h ago';
    if (d.inDays.abs() <= 7) return '${d.inDays.abs()}d ago';
    final local = dt.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No items available.'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];

        // Build subtitle lines based on toggles/availability
        final lines = <String>[
          'Qty: ${item.quantity} • \$${item.price2.toStringAsFixed(2)}',
          'Warehouse: ${item.warehouse}',
        ];
        if (showDescription && item.description.isNotEmpty) {
          final desc = item.description.trim();
          lines.add(desc.length > 120 ? '${desc.substring(0, 120)}…' : desc);
        }
        if (showUpdatedAt && item.updatedAt != null) {
          lines.add('Updated ${_relative(item.updatedAt!)}');
        }

        return ListTile(
          leading: const Icon(Icons.inventory_2),
          title: Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            lines.join('\n'),
            style: const TextStyle(fontSize: 13),
          ),
          isThreeLine: lines.length >= 3,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => onTap(item),
        );
      },
    );
  }
}
