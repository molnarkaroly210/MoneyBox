import 'dart:convert';
import 'package:http/http.dart' as http;

class FrankfurterApi {
  // A kért api.frankfurter.dev/v2 verziót használjuk
  static const _baseUrl = 'https://api.frankfurter.dev/v2';

  /// List of supported currencies provided by API
  static Future<Map<String, String>> getCurrencies() async {
    final response = await http.get(Uri.parse('$_baseUrl/currencies'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(key, value.toString()));
    } else {
      throw Exception('Failed to load currencies');
    }
  }

  /// Get the latest exchange rates for a given base currency.
  static Future<Map<String, double>> getLatest({String base = 'USD'}) async {
    final response = await http.get(Uri.parse('$_baseUrl/latest?base=$base'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final rates = data['rates'] as Map<String, dynamic>;
      final result = rates.map((key, value) => MapEntry(key, (value as num).toDouble()));
      // Ensure base is always 1.0 (frankfurter might exclude base from rates)
      result[base] = 1.0;
      // Add missing but common missing currencies just in case (frankfurter doesn't have some)
      // but only if they are not the base
      return result;
    } else {
      throw Exception('Failed to load rates: ${response.statusCode}');
    }
  }

  /// Get historical exchange rates for a specific timeframe.
  /// Start and end dates should be in 'YYYY-MM-DD' format.
  /// If end is null, gets rates up to the present.
  static Future<Map<String, Map<String, double>>> getHistorical(
      String start, {
      String? end,
      String base = 'USD',
    }) async {
    final endPath = end != null ? '..$end' : '';
    final url = Uri.parse('$_baseUrl/$start$endPath?base=$base');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final ratesData = data['rates'] as Map<String, dynamic>;
      
      final result = <String, Map<String, double>>{};
      for (final date in ratesData.keys) {
        final dateRates = ratesData[date] as Map<String, dynamic>;
        result[date] = dateRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
        // Ensure base is in historical data
        result[date]![base] = 1.0;
      }
      return result;
    } else {
      throw Exception('Failed to load historical rates: ${response.statusCode}');
    }
  }
}
