import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/news_service.dart';
import '../models/news_model.dart';
import '../main.dart'; // import theme colors
import 'article_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final NewsService _newsService = NewsService();
  String _selectedCategory = 'business';
  
  late Future<List<NewsArticle>> _newsFuture;

  final List<Map<String, String>> _categories = [
    {'id': 'business', 'label': 'Pénzügy'},
    {'id': 'technology', 'label': 'Tech'},
    {'id': 'science', 'label': 'Tudomány'},
    {'id': 'sports', 'label': 'Sport'},
    {'id': 'health', 'label': 'Egészség'},
    {'id': 'entertainment', 'label': 'Szórakozás'},
    {'id': 'general', 'label': 'Általános'},
  ];

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  void _loadNews() {
    setState(() {
      _newsFuture = _newsService.fetchNews(category: _selectedCategory);
    });
  }

  void _openArticle(BuildContext context, NewsArticle article) async {
    // Mobil eszközön (Android/iOS) a beépített böngésző nyílik meg
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ArticleScreen(
            url: article.url,
            title: article.sourceName,
          ),
        ),
      );
    } else {
      // Számítógépen/weben azonnal a külső böngésző nyílik meg
      final uri = Uri.parse(article.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nem sikerült megnyitni a cikket.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Hírek', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: Column(
        children: [
          // Kategóriák választó (Prémium chip design)
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category['id'];
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedCategory != category['id']) {
                        setState(() {
                          _selectedCategory = category['id']!;
                        });
                        _loadNews();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? kAccent.withOpacity(0.15) : kSurface,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected ? kAccent.withOpacity(0.5) : kBorder,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: kAccent.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          category['label']!,
                          style: TextStyle(
                            color: isSelected ? kAccent : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Hírek lista
          Expanded(
            child: FutureBuilder<List<NewsArticle>>(
              future: _newsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kAccent));
                } else if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Nincsenek hírek ebben a kategóriában.', style: TextStyle(color: Colors.white70)),
                  );
                }

                final articles = snapshot.data!;
                return RefreshIndicator(
                  color: kAccent,
                  backgroundColor: kSurface,
                  onRefresh: () async => _loadNews(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: articles.length,
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      return _buildPremiumNewsCard(context, article);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kNeg.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: kNeg, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadNews,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Újrapróbálkozás'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kSurface2,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumNewsCard(BuildContext context, NewsArticle article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: kSurface,
          child: InkWell(
            onTap: () => _openArticle(context, article),
            child: SizedBox(
              height: 260,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Háttérkép
                  if (article.urlToImage != null)
                    Image.network(
                      article.urlToImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: kSurface2,
                        child: const Icon(Icons.image_not_supported, color: kDim, size: 48),
                      ),
                    )
                  else
                    Container(
                      color: kSurface2,
                      child: const Center(
                        child: Icon(Icons.article_outlined, color: kDim, size: 64),
                      ),
                    ),
                  
                  // Színátmenet (Sötétítés alulról felfelé)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          kBg.withOpacity(0.4),
                          kBg.withOpacity(0.95),
                        ],
                        stops: const [0.3, 0.6, 1.0],
                      ),
                    ),
                  ),

                  // Tartalom
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Forrás badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kAccent.withOpacity(0.5), width: 1),
                          ),
                          child: Text(
                            article.sourceName,
                            style: const TextStyle(
                              color: kAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Cím
                        Text(
                          article.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Idő
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 14, color: Colors.white54),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(article.publishedAt),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inHours < 1) {
      return '${difference.inMinutes} perce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} órája';
    } else {
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}.';
    }
  }
}
