class Protisthan {
  final int? id;
  final String uuid;
  final String name;
  final String createdAt;

  /// Position in its list when the user drags items into their own order
  /// (0 first). Null for rows that were never placed — they follow the
  /// ordered ones, alphabetically.
  /// This device's own order for the home list; not synced, since each
  /// member sees a different set of থানা.
  final int? sortOrder;

  const Protisthan({
    this.id,
    required this.uuid,
    required this.name,
    required this.createdAt,
    this.sortOrder,
  });

  Protisthan copyWith({int? id, String? uuid, String? name, String? createdAt, int? sortOrder}) {
    return Protisthan(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'created_at': createdAt,
      'sort_order': sortOrder,
    };
  }

  factory Protisthan.fromMap(Map<String, dynamic> map) {
    return Protisthan(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      name: map['name'] as String,
      createdAt: map['created_at'] as String,
      sortOrder: map['sort_order'] as int?,
    );
  }
}
