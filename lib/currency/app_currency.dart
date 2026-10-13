import 'package:flutter/material.dart';

const currencySymbols = <String, String>{
  'THB': '฿',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'CNY': '¥',
  'SGD': '\$',
};

// Picker labels distinguish currencies that share the same monetary symbol.
// Amount formatting continues to use currencySymbols only.
const currencySelectionLabels = <String, String>{
  'THB': 'TH-฿',
  'USD': 'US-\$',
  'EUR': 'EU-€',
  'GBP': 'GB-£',
  'JPY': 'JP-¥',
  'CNY': 'CN-¥',
  'SGD': 'SG-\$',
};

class AppCurrency extends ThemeExtension<AppCurrency> {
  const AppCurrency(this.code);
  final String code;
  String get symbol => currencySymbols[code] ?? currencySymbols['THB']!;
  @override
  AppCurrency copyWith({String? code}) => AppCurrency(code ?? this.code);
  @override
  AppCurrency lerp(covariant AppCurrency? other, double t) => other ?? this;
}
