class CategoryItem {
  final String id;
  final String name;
  final String? parentId;
  final String? parentName;

  CategoryItem({
    required this.id,
    required this.name,
    this.parentId,
    this.parentName,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      parentId: json['parentId'],
      parentName: json['parent']?['name'] ?? json['parentName'],
    );
  }
}

class AttributeValueItem {
  final String id;
  final String value;

  AttributeValueItem({required this.id, required this.value});

  factory AttributeValueItem.fromJson(Map<String, dynamic> json) {
    return AttributeValueItem(
      id: json['id'] ?? '',
      value: json['value'] ?? '',
    );
  }
}

class AttributeItem {
  final String id;
  final String name;
  final List<AttributeValueItem> values;

  AttributeItem({
    required this.id,
    required this.name,
    required this.values,
  });

  factory AttributeItem.fromJson(Map<String, dynamic> json) {
    final rawValues = (json['values'] as List?) ?? [];
    return AttributeItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      values: rawValues.map((v) => AttributeValueItem.fromJson(v)).toList(),
    );
  }
}
