class Criteria {
  final int? id;
  final String uuid;
  final int protisthanId;
  final String name;
  final String createdAt;

  const Criteria({
    this.id,
    required this.uuid,
    required this.protisthanId,
    required this.name,
    required this.createdAt,
  });

  Criteria copyWith({int? id, String? uuid, int? protisthanId, String? name, String? createdAt}) {
    return Criteria(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      protisthanId: protisthanId ?? this.protisthanId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'protisthan_id': protisthanId,
      'name': name,
      'created_at': createdAt,
    };
  }

  factory Criteria.fromMap(Map<String, dynamic> map) {
    return Criteria(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      protisthanId: map['protisthan_id'] as int,
      name: map['name'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
