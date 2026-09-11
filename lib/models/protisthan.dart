class Protisthan {
  final int? id;
  final String uuid;
  final String name;
  final String createdAt;

  const Protisthan({
    this.id,
    required this.uuid,
    required this.name,
    required this.createdAt,
  });

  Protisthan copyWith({int? id, String? uuid, String? name, String? createdAt}) {
    return Protisthan(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'created_at': createdAt,
    };
  }

  factory Protisthan.fromMap(Map<String, dynamic> map) {
    return Protisthan(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      name: map['name'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
