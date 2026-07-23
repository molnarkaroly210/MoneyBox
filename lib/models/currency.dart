class CurrencyInfo {
  final String code;
  final String name;
  final String countryCode;
  final double rateToUsd;
  final double changePercent;
  final List<double> sparklineData;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.countryCode,
    required this.rateToUsd,
    required this.changePercent,
    required this.sparklineData,
  });
}

class FavoritePair {
  final String from;
  final String to;

  const FavoritePair(this.from, this.to);

  String get label => '$from→$to';
}
