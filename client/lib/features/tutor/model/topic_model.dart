class TopicModel {
  final String id;
  final String name;
  final String slug;
  final String? icon;

  const TopicModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
  });

  factory TopicModel.fromMap(Map<String, dynamic> m) => TopicModel(
        id: m['id'] as String,
        name: m['name'] as String,
        slug: m['slug'] as String,
        icon: m['icon'] as String?,
      );
}
