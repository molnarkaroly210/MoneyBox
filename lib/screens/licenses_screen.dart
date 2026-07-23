import 'package:flutter/material.dart';
import '../main.dart';
import '../services/settings_service.dart';

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsProvider.of(context);

    final licenses = [
      _LicenseItem(
        name: 'Flutter SDK',
        author: 'Google LLC',
        type: 'BSD-3-Clause',
        description: 'Flutter is Google’s SDK for crafting beautiful, fast user experiences for mobile, web, and desktop from a single codebase.',
        fullText: '''Copyright 2014 The Flutter Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of Google Inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.''',
      ),
      _LicenseItem(
        name: 'countries_world_map',
        author: 'Julian Stecklina & Contributors',
        type: 'MIT License',
        description: 'A customizable Flutter package to render scalable interactive SVG maps for world countries.',
        fullText: '''MIT License

Copyright (c) 2023 Julian Stecklina

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom it is furnished to do so.''',
      ),
      _LicenseItem(
        name: 'Open ER-API (Data Source)',
        author: 'ExchangeRate-API',
        type: 'Open Data / CC BY 4.0',
        description: 'Free & Reliable Foreign Exchange Rates API for developer apps.',
        fullText: '''ExchangeRate-API provides open financial data. Usage requires compliance with terms of service including rate limiting and attribution where appropriate.''',
      ),
      _LicenseItem(
        name: 'Frankfurter API',
        author: 'Hannes Franklin',
        type: 'MIT License',
        description: 'Open-source API for current and historical foreign exchange rates published by the European Central Bank.',
        fullText: '''MIT License

Copyright (c) 2021 Hannes Franklin

Data provided by European Central Bank under open access policies.''',
      ),
      _LicenseItem(
        name: 'shared_preferences',
        author: 'Flutter Team',
        type: 'BSD-3-Clause',
        description: 'Wraps platform-specific persistent data storage for key-value pairs.',
        fullText: '''Copyright 2013 The Flutter Authors. All rights reserved. BSD-3-Clause license.''',
      ),
    ];

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Licencek & Szerzői jogok', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [s.accentColor.withAlpha(30), kSurface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: s.accentColor.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: s.accentColor.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.gavel_rounded, color: s.accentColor, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nyílt forráskódú szoftverek', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('A MoneyBox az alábbi nyílt forráskódú csomagokat és adatforrásokat használja.', style: TextStyle(color: kDim2, fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('Használt Könyvtárak', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          ...licenses.map((item) => _buildLicenseTile(context, item, s)).toList(),
          
          const SizedBox(height: 20),
          Center(
            child: Text('MoneyBox v1.0.0 · All rights reserved', style: TextStyle(color: kDim2.withAlpha(150), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseTile(BuildContext context, _LicenseItem item, AppSettings s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: s.accentColor.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: s.accentColor.withAlpha(50)),
              ),
              child: Text(item.type, style: TextStyle(color: s.accentColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.author, style: const TextStyle(color: kDim2, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                item.description, 
                style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: kDim2),
        onTap: () => _showFullLicense(context, item),
      ),
    );
  }

  void _showFullLicense(BuildContext context, _LicenseItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(item.author, style: const TextStyle(color: kDim2, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: kBorder),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                  ),
                  child: Text(
                    item.fullText,
                    style: const TextStyle(color: kDim2, fontFamily: 'monospace', fontSize: 12, height: 1.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LicenseItem {
  final String name;
  final String author;
  final String type;
  final String description;
  final String fullText;

  const _LicenseItem({
    required this.name,
    required this.author,
    required this.type,
    required this.description,
    required this.fullText,
  });
}
