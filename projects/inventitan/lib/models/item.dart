import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp, FieldValue;

/// Domain model for an inventory item.
/// SQLite is the primary store; Firestore is an optional mirror at:
///   /users/{uid}/items/{localId}
class Item {
  /// Local SQLite row id (and Firestore doc id when mirrored).
  final int? id;

  final String name;       // 1..80 chars
  final int quantity;      // 0..1_000_000
  final double price;      // 0..1_000_000, rounded to 2 decimals
  final String warehouse;  // 1..80 chars
  final String description; // 0..2000 chars, optional

  /// Last update time. For Firestore writes, use server time.
  final DateTime? updatedAt;

  static const int nameMax = 80;
  static const int warehouseMax = 80;
  static const int descriptionMax = 2000;
  static const int quantityMax = 1000000;
  static const double priceMax = 1000000.0;

  const Item({
    this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.warehouse,
    this.description = '',
    this.updatedAt,
  });

  /// Convenience: normalize to 2 decimals.
  double get price2 => (price * 100).round() / 100.0;

  /// Copy with changes.
  Item copyWith({
    int? id,
    String? name,
    int? quantity,
    double? price,
    String? warehouse,
    String? description,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      warehouse: warehouse ?? this.warehouse,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // -----------------------------
  // SQLite (local) serialization
  // -----------------------------

  /// Map for SQLite. Store timestamps as ISO-8601 text for portability.
  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price2,
      'warehouse': warehouse,
      'description': description,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Item.fromDbMap(Map<String, Object?> map) {
    final rawUpdated = map['updatedAt'];
    DateTime? ts;
    if (rawUpdated is String && rawUpdated.isNotEmpty) {
      ts = DateTime.tryParse(rawUpdated);
    } else if (rawUpdated is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawUpdated);
    }
    return Item(
      id: map['id'] as int?,
      name: (map['name'] as String).trim(),
      quantity: (map['quantity'] as num).toInt(),
      price: (map['price'] as num).toDouble(),
      warehouse: (map['warehouse'] as String).trim(),
      description: (map['description'] as String?)?.trim() ?? '',
      updatedAt: ts,
    );
  }

  // -----------------------------
  // Firestore (cloud) serialization
  // -----------------------------

  /// Map for creating/updating in Firestore.
  /// Uses server timestamp to satisfy security rules.
  Map<String, Object?> toFirestoreWrite({bool includeServerTimestamp = true}) {
    return {
      'name': name.trim(),
      'quantity': quantity,
      'price': price2,
      'warehouse': warehouse.trim(),
      'description': description.trim(),
      'updatedAt': includeServerTimestamp
          ? FieldValue.serverTimestamp()
          : updatedAt, // only set when you really want to pass a client time
    };
  }

  /// Build from Firestore data
  /// Pass it to set [id].
  factory Item.fromFirestore(Map<String, dynamic> data, {String? docId}) {
    DateTime? ts;
    final raw = data['updatedAt'];
    if (raw is Timestamp) ts = raw.toDate();
    // Accept ISO string for safety if you ever write client timestamps:
    if (ts == null && raw is String) ts = DateTime.tryParse(raw);

    int? parsedId;
    if (docId != null) {
      final n = int.tryParse(docId);
      if (n != null) parsedId = n;
    }

    return Item(
      id: parsedId,
      name: (data['name'] as String).trim(),
      quantity: (data['quantity'] as num).toInt(),
      price: (data['price'] as num).toDouble(),
      warehouse: (data['warehouse'] as String).trim(),
      description: (data['description'] as String?)?.trim() ?? '',
      updatedAt: ts,
    );
  }

  // -----------------------------
  // Basic validation (optional)
  // -----------------------------

  /// Returns null if valid, otherwise a human-readable reason.
  String? validate() {
    if (name.isEmpty || name.length > nameMax) {
      return 'Name must be 1..$nameMax characters';
    }
    if (warehouse.isEmpty || warehouse.length > warehouseMax) {
      return 'Warehouse must be 1..$warehouseMax characters';
    }
    if (description.length > descriptionMax) {
      return 'Description must be ≤ $descriptionMax characters';
    }
    if (quantity < 0 || quantity > quantityMax) {
      return 'Quantity must be 0..$quantityMax';
    }
    if (price < 0 || price > priceMax) {
      return 'Price must be 0..$priceMax';
    }
    return null;
    // (You can call this before saving; UI already validates too.)
  }

  // -----------------------------
  // Equality / debug
  // -----------------------------

  @override
  String toString() =>
      'Item(id: $id, name: $name, qty: $quantity, price: $price2, wh: $warehouse)';

  @override
  bool operator ==(Object other) {
    return other is Item &&
        other.id == id &&
        other.name == name &&
        other.quantity == quantity &&
        other.price2 == price2 &&
        other.warehouse == warehouse &&
        other.description == description &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, quantity, price2, warehouse, description, updatedAt);
}
