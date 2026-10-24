/// A user defined category (CV, Tenders, ...).
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  final int id;
  final String name;

  /// ARGB colour value.
  final int color;

  /// Key into [kCategoryIcons].
  final String icon;
  final DateTime createdAt;

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int,
        name: m['name'] as String,
        color: m['color'] as int,
        icon: (m['icon'] as String?) ?? 'folder',
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}

class CategoryWithCount {
  const CategoryWithCount(this.category, this.count);
  final Category category;
  final int count;
}
