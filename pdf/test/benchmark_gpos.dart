/*
 * Benchmark: GPOS impact + Performance measurement
 * 
 * Run: dart run test/benchmark_gpos.dart
 */

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

import 'utils.dart';

Future<Font> _downloadFont(String fontName) async {
  final localPaths = ['$fontName.ttf', 'test/$fontName.ttf'];
  for (final path in localPaths) {
    final file = File(path);
    if (file.existsSync()) {
      return Font.ttf(file.readAsBytesSync().buffer.asByteData());
    }
  }
  final url =
      'https://raw.githubusercontent.com/googlefonts/noto-fonts/main/hinted/ttf/$fontName/$fontName-Regular.ttf';
  final data = await download(url, suffix: '.ttf');
  return Font.ttf(data.buffer.asByteData());
}

/// Sample Malayalam text with marks that GPOS affects
const _sampleTexts = [
  // Anusvara (ം) - GPOS positions this mark above the base
  'സംസ്കാരം',        // Samskaram (culture)
  'ജനസംഖ്യ',         // Janasankhya (population)
  
  // Visarga (ഃ) - GPOS positions this after the base  
  'ദുഃഖം',           // Duhkham (sorrow)
  'അന്തഃപുരം',       // Anthahpuram (inner chamber)
  
  // Complex conjuncts + marks together
  'മലയാളം ഒരു ദ്രാവിഡ ഭാഷയാണ്',   // Malayalam is a Dravidian language
  'കേരളത്തിന്റെ സംസ്കാരം വളരെ പ്രസിദ്ധമാണ്', // Kerala's culture is very famous
  
  // Vowel signs that benefit from precise positioning
  'കൊച്ചി തിരുവനന്തപുരം കോഴിക്കോട്',  // Kochi Trivandrum Kozhikode
  
  // Mixed Latin + Malayalam (tests script segmentation)
  'Kerala (കേരളം) - God\'s Own Country',
  'Population: 3.5 കോടി (35 million)',
];

void main() async {
  print('=== GPOS Benchmark & Comparison ===\n');
  
  final font = await _downloadFont('NotoSansMalayalam');
  print('Font loaded.\n');

  // ─── Performance Benchmark ───────────────────────────────────
  print('--- Performance Benchmark ---');
  
  // Warm up
  for (var i = 0; i < 3; i++) {
    final doc = Document();
    doc.addPage(Page(
      build: (ctx) => Text('മലയാളം', style: TextStyle(font: font, fontSize: 20)),
    ));
    await doc.save();
  }

  // Benchmark: Generate PDF with complex text (100 pages)
  const pageCount = 100;
  const textPerPage = 'മലയാളം ഒരു ദ്രാവിഡ ഭാഷയാണ്. കേരളത്തിന്റെ സംസ്കാരം വളരെ പ്രസിദ്ധമാണ്. '
      'ക്ക ന്ന ട്ട ത്ത പ്പ ക്ഷ ങ്ക ണ്ട ന്ത മ്പ. '
      'കെ കേ കൈ കൊ കോ കൌ കി കീ കു കൂ. '
      'സംസ്കൃതം ദുഃഖം അന്തഃപുരം ജനസംഖ്യ.';

  final sw = Stopwatch()..start();
  
  final doc = Document();
  for (var p = 0; p < pageCount; p++) {
    doc.addPage(Page(
      build: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Page ${p + 1}', style: TextStyle(font: font, fontSize: 14)),
          SizedBox(height: 8),
          Text(textPerPage, style: TextStyle(font: font, fontSize: 12)),
          SizedBox(height: 4),
          Text(textPerPage, style: TextStyle(font: font, fontSize: 12)),
          SizedBox(height: 4),
          Text(textPerPage, style: TextStyle(font: font, fontSize: 12)),
        ],
      ),
    ));
  }
  
  final bytes = await doc.save();
  sw.stop();
  
  print('  $pageCount pages, 3 paragraphs each');
  print('  Total time: ${sw.elapsedMilliseconds}ms');
  print('  Per page: ${(sw.elapsedMilliseconds / pageCount).toStringAsFixed(1)}ms');
  print('  PDF size: ${(bytes.length / 1024).toStringAsFixed(1)}KB');
  
  // Benchmark: Plain Latin text for comparison
  final swLatin = Stopwatch()..start();
  final docLatin = Document();
  for (var p = 0; p < pageCount; p++) {
    docLatin.addPage(Page(
      build: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Page ${p + 1}', style: const TextStyle(fontSize: 14)),
          SizedBox(height: 8),
          Text('The quick brown fox jumps over the lazy dog. ' * 5, 
               style: const TextStyle(fontSize: 12)),
        ],
      ),
    ));
  }
  final latinBytes = await docLatin.save();
  swLatin.stop();
  
  print('\n  Comparison (Latin-only, same page count):');
  print('  Total time: ${swLatin.elapsedMilliseconds}ms');
  print('  Per page: ${(swLatin.elapsedMilliseconds / pageCount).toStringAsFixed(1)}ms');
  print('  PDF size: ${(latinBytes.length / 1024).toStringAsFixed(1)}KB');
  
  final overhead = sw.elapsedMilliseconds - swLatin.elapsedMilliseconds;
  print('\n  Shaping overhead: ${overhead}ms total '
      '(${(overhead / pageCount).toStringAsFixed(1)}ms/page)');

  // ─── Visual Comparison PDF ──────────────────────────────────
  print('\n--- Generating Comparison PDF ---');
  
  final comparisonDoc = Document();
  final style = TextStyle(font: font, fontSize: 18);
  final smallStyle = TextStyle(font: font, fontSize: 14);
  
  comparisonDoc.addPage(MultiPage(
    build: (ctx) => [
      Header(level: 0, child: Text('GPOS Effect on Malayalam', style: style)),
      SizedBox(height: 10),
      
      Text(
        'GPOS (Glyph Positioning) adjusts the precise placement of marks like '
        'anusvara (\u0D02), visarga (\u0D03), and kerning between glyph pairs. '
        'The visual difference is subtle but important for typographic quality.',
        style: smallStyle,
      ),
      SizedBox(height: 20),
      
      Header(level: 1, child: Text('Sample Malayalam Texts', style: style)),
      SizedBox(height: 10),
      
      ..._sampleTexts.expand((text) => [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(text, style: TextStyle(font: font, fontSize: 16)),
        ),
      ]),
      
      SizedBox(height: 20),
      Header(level: 1, child: Text('GPOS-Sensitive Characters', style: style)),
      SizedBox(height: 10),
      
      // Anusvara positioning
      Text('Anusvara (\u0D02) - Mark above base:', style: smallStyle),
      Text('സം  കം  ണം  നം  മം  രം  ലം  ഷം', 
           style: TextStyle(font: font, fontSize: 24)),
      SizedBox(height: 10),
      
      // Visarga positioning  
      Text('Visarga (\u0D03) - Mark after base:', style: smallStyle),
      Text('കഃ  നഃ  മഃ  രഃ  ലഃ  സഃ',
           style: TextStyle(font: font, fontSize: 24)),
      SizedBox(height: 10),
      
      // Conjuncts with marks
      Text('Conjuncts + marks (tests both GSUB + GPOS):', style: smallStyle),
      Text('ക്കം  ന്നം  ത്തം  പ്പം  സ്സം  ക്ഷം',
           style: TextStyle(font: font, fontSize: 24)),
      SizedBox(height: 10),
      
      // Vowel signs
      Text('Vowel signs with marks:', style: smallStyle),
      Text('കേരളം  മലയാളം  തിരുവനന്തപുരം',
           style: TextStyle(font: font, fontSize: 24)),
      
      SizedBox(height: 20),
      Header(level: 1, child: Text('Mixed Script Test', style: style)),
      SizedBox(height: 10),
      
      Text('Hello നമസ്കാരം World', 
           style: TextStyle(font: font, fontSize: 20)),
      Text('Kerala (കേരളം) - Population: 3.5 കോടി',
           style: TextStyle(font: font, fontSize: 20)),
      Text('100% മലയാളം supported!',
           style: TextStyle(font: font, fontSize: 20)),
    ],
  ));
  
  final compBytes = await comparisonDoc.save();
  final compFile = File('gpos_comparison.pdf');
  await compFile.writeAsBytes(compBytes);
  print('  Saved: gpos_comparison.pdf (${(compBytes.length / 1024).toStringAsFixed(1)}KB)');
  
  print('\nDone!');
}
