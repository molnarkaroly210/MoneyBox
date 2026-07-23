import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_model.dart';

class NewsService {
  // Figyelem: Ide érdemes beírni egy regisztrált API kulcsot a NewsAPI.org-ról.
  // Regisztráció ingyenes: https://newsapi.org/register
  static const String _apiKey = '802648032f6d4f9db2954160f9d5e823'; 
  static const String _baseUrl = 'https://newsapi.org/v2/top-headlines';

  Future<List<NewsArticle>> fetchNews({String category = 'business'}) async {
    // Először megpróbálunk magyar híreket lekérni (country=hu)
    Uri url = Uri.parse('$_baseUrl?category=$category&country=hu&apiKey=$_apiKey');
    
    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['status'] == 'ok') {
          var articles = data['articles'] as List;
          
          // Ha a NewsAPI nem talál magyar hírt ebben a specifikus kategóriában, 
          // akkor automatikusan visszaváltunk a nemzetközi (angol) hírekre.
          if (articles.isEmpty) {
            url = Uri.parse('$_baseUrl?category=$category&language=en&apiKey=$_apiKey');
            response = await http.get(url);
            if (response.statusCode == 200) {
              data = json.decode(response.body);
              articles = data['articles'] as List;
            }
          }

          return articles
              .where((json) => json['title'] != '[Removed]' && json['url'] != null)
              .map((json) => NewsArticle.fromJson(json))
              .toList();
        }
      }
      throw Exception('Nem sikerült betölteni a híreket. Ellenőrizd az API kulcsot! (Code: ${response.statusCode})');
    } catch (e) {
      throw Exception('Hálózati hiba a hírek lekérésekor: $e');
    }
  }
}
