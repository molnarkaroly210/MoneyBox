class NewsArticle {
  final String title;
  final String? description;
  final String? urlToImage;
  final String url;
  final String sourceName;
  final DateTime publishedAt;

  NewsArticle({
    required this.title,
    this.description,
    this.urlToImage,
    required this.url,
    required this.sourceName,
    required this.publishedAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? 'Nincs cím',
      description: json['description'],
      urlToImage: json['urlToImage'],
      url: json['url'] ?? '',
      sourceName: json['source']?['name'] ?? 'Ismeretlen',
      publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
