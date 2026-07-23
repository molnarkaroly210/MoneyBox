import 'dart:math' as math;

// ── Mock / fallback data ───────────────────────────────────────────────────
// Used when live API is unavailable or as sparkline placeholder data.

const _mockRatesUsd = <String, double>{
  'USD': 1.0,
  'EUR': 0.92310,
  'GBP': 0.78820,
  'JPY': 157.40,
  'CHF': 0.89540,
  'CAD': 1.36180,
  'AUD': 1.52470,
  'CNY': 7.26510,
  'HUF': 358.40,
  'NOK': 10.734,
  'SEK': 10.412,
  'PLN': 4.0241,
  'DKK': 6.8821,
  'CZK': 23.142,
  'RON': 4.6410,
  'HRK': 7.0241,
  'BGN': 1.8051,
  'TRY': 32.850,
  'RUB': 91.50,
  'BRL': 4.9810,
  'MXN': 16.920,
  'INR': 83.510,
  'KRW': 1335.0,
  'SGD': 1.34890,
  'NZD': 1.6210,
  'ZAR': 18.920,
  // Crypto
  'BTC': 0.0000166, // 1 USD = ~0.0000166 BTC (60k USD)
  'ETH': 0.00062,   // 1 USD = ~0.00062 ETH (1.6k USD)
  'DOGE': 8.33,     // 1 USD = ~8.33 DOGE (0.12 USD)
  'XRP': 2.0,       // 1 USD = ~2 XRP (0.5 USD)
};

const _mockChanges = <String, double>{
  'EUR': -0.12, 'GBP': 0.34,  'JPY': -0.67, 'CHF': 0.08,
  'CAD': -0.23, 'AUD': 0.51,  'CNY': 0.14,  'HUF': -0.31,
  'NOK': 0.18,  'SEK': -0.09, 'PLN': 0.22,  'DKK': 0.11,
  'CZK': -0.14, 'RON': 0.05,  'HRK': 0.02,  'BGN': 0.01,
  'TRY': -1.20, 'RUB': -0.80, 'BRL': 0.33,  'MXN': -0.18,
  'INR': -0.07, 'KRW': -0.44, 'SGD': -0.09, 'NZD': 0.27,
  'ZAR': 0.55,
  'BTC': 2.14, 'ETH': 1.89, 'DOGE': -0.5, 'XRP': 0.2,
};

const _mockNames = <String, String>{
  'USD': 'US Dollár',     'EUR': 'Euró',            'GBP': 'Font Sterling',
  'JPY': 'Japán Jen',    'CHF': 'Svájci Frank',     'CAD': 'Kanadai Dollár',
  'AUD': 'Ausztrál Dollár','CNY': 'Kínai Jüan',    'HUF': 'Magyar Forint',
  'NOK': 'Norvég Korona','SEK': 'Svéd Korona',     'PLN': 'Lengyel Zloty',
  'DKK': 'Dán Korona',   'CZK': 'Cseh Korona',     'RON': 'Román Lej',
  'HRK': 'Horvát Kuna',  'BGN': 'Bolgár Leva',     'TRY': 'Török Líra',
  'RUB': 'Orosz Rubel',  'BRL': 'Brazil Real',     'MXN': 'Mexikói Peso',
  'INR': 'Indiai Rúpia', 'KRW': 'Dél-Koreai Won',  'SGD': 'Szingapúri Dollár',
  'NZD': 'Új-Zélandi Dollár','ZAR': 'Dél-Afrikai Rand',
  'BTC': 'Bitcoin', 'ETH': 'Ethereum', 'DOGE': 'Dogecoin', 'XRP': 'Ripple',
};

const _mockCC = <String, String>{
  'USD': 'US', 'EUR': 'EU', 'GBP': 'GB', 'JPY': 'JP', 'CHF': 'CH',
  'CAD': 'CA', 'AUD': 'AU', 'CNY': 'CN', 'HUF': 'HU', 'NOK': 'NO',
  'SEK': 'SE', 'PLN': 'PL', 'DKK': 'DK', 'CZK': 'CZ', 'RON': 'RO',
  'HRK': 'HR', 'BGN': 'BG', 'TRY': 'TR', 'RUB': 'RU', 'BRL': 'BR',
  'MXN': 'MX', 'INR': 'IN', 'KRW': 'KR', 'SGD': 'SG', 'NZD': 'NZ',
  'ZAR': 'ZA',
  'BTC': '₿', 'ETH': 'Ξ', 'DOGE': 'Ð', 'XRP': '✕',
};

List<String> get mockAllCodes => _mockRatesUsd.keys.toList();

double mockRate(String from, String to) {
  if (from == to) return 1.0;
  final f = _mockRatesUsd[from] ?? 1.0;
  final t = _mockRatesUsd[to]   ?? 1.0;
  if (from == 'USD') return t;
  if (to   == 'USD') return 1.0 / f;
  return t / f;
}

double mockChange(String code) => _mockChanges[code] ?? 0.0;

String mockCurrencyName(String code) => _mockNames[code] ?? code;

String mockCountryCode(String code) => _mockCC[code] ?? code.substring(0, 2);

List<double> mockHistory(String from, String to, int points) {
  final current = mockRate(from, to);
  return mockHistoryFromRate(from, to, points, current);
}

/// Generate [days] data points whose last value is [currentRate].
///
/// Logical guarantee:
///   mockHistoryFromRate(f, t, 90, r).last == r
///   mockHistoryFromRate(f, t, 180, r).last == r
///   AND the 90-point slice is always the TAIL of the 180-point slice,
///   so min(90d) >= min(180d) is guaranteed — longer windows always show
///   at least as low (or lower) minima than shorter ones.
///
/// How: build the full 365-day series once (seed has no `days` component),
///      then return the last [days] values.
List<double> mockHistoryFromRate(String from, String to, int days, double currentRate) {
  const maxDays = 365;
  // Seed must NOT include `days` — ensures all timeframes share the same base series
  final seed = from.hashCode ^ to.hashCode ^ currentRate.hashCode;
  final rng  = math.Random(seed);

  final full = List<double>.filled(maxDays, 0.0);

  // Build from oldest → newest; last point pinned to currentRate.
  // Use slow mean-reversion so the series looks realistic.
  var value = currentRate * (1.0 + (rng.nextDouble() - 0.5) * 0.06);
  for (int i = 0; i < maxDays - 1; i++) {
    // Progress-based reversion: gradually pull toward currentRate
    final progress = i / (maxDays - 1);
    final pull   = progress * 0.15 + 0.005; // stronger reversion as we approach end
    final rev    = (currentRate - value) * pull;
    final noise  = (rng.nextDouble() - 0.5) * 0.005 * currentRate;
    value       += rev + noise;
    full[i]      = value;
  }
  full[maxDays - 1] = currentRate; // last point = live rate

  // Return the last [days] values (tail slice)
  if (days >= maxDays) return List<double>.from(full);
  return full.sublist(maxDays - days);
}

// Legacy aliases kept for compatibility
double getRate(String from, String to) => mockRate(from, to);
String countryCodeFor(String code) => mockCountryCode(code);
String currencyName(String code) => mockCurrencyName(code);
List<String> get allCurrencyCodes => mockAllCodes;
List<double> generateHistoricalData(String from, String to, int points) =>
    mockHistory(from, to, points);
