// ignore_for_file: public_member_api_docs, avoid_redundant_argument_values

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data.dart';

// ---------------------------------------------------------------------------
// Data models for the VPSDime API
// ---------------------------------------------------------------------------

class _VpsPlan {
  _VpsPlan({
    required this.name,
    required this.orderLink,
    required this.vcpu,
    required this.memoryGb,
    required this.storageGb,
    required this.uplinkGbps,
    required this.trafficTb,
    required this.monthlyPrice,
    required this.addons,
  });

  factory _VpsPlan.fromJson(Map<String, dynamic> json) {
    final specs = json['specs'] as Map<String, dynamic>;
    final pricing = json['pricing_usd'] as Map<String, dynamic>;
    final options = json['options'] as List<dynamic>;

    return _VpsPlan(
      name: json['product_name'] as String,
      orderLink: json['order_link'] as String,
      vcpu: specs['vcpu'] as int,
      memoryGb: specs['memory_gb'] as int,
      storageGb: specs['storage_gb'] as int,
      uplinkGbps: specs['uplink_gbps'] as int,
      trafficTb: specs['traffic_tb'] as int,
      monthlyPrice: (pricing['monthly'] as num).toDouble(),
      addons: options
          .where((o) => o['type'] == 'checkbox' || o['type'] == 'quantity')
          .map((o) => _Addon.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  final String name;
  final String orderLink;
  final int vcpu;
  final int memoryGb;
  final int storageGb;
  final int uplinkGbps;
  final int trafficTb;
  final double monthlyPrice;
  final List<_Addon> addons;
}

class _Addon {
  _Addon({
    required this.name,
    this.unit = '',
    this.qtyMax,
    required this.monthlyPrice,
  });

  factory _Addon.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing_usd'] as Map<String, dynamic>?;
    return _Addon(
      name: json['name'] as String,
      unit: json['unit'] as String? ?? '',
      qtyMax: json['qty_max'] as int?,
      monthlyPrice: (pricing?['monthly'] as num?)?.toDouble() ?? 0,
    );
  }

  final String name;
  final String unit;
  final int? qtyMax;
  final double monthlyPrice;
}

// ---------------------------------------------------------------------------
// Color palette
// ---------------------------------------------------------------------------

const _primaryMid = PdfColors.blueGrey800;
const _accent = PdfColors.amber700;
const _accentLight = PdfColors.amber100;
const _success = PdfColors.green700;
const _bgLight = PdfColors.grey50;

// -------------------------------------------------------------------------
// PDF generation
// -------------------------------------------------------------------------

final _cache = <String, String>{};

Future<String> _fetch(String url, [String? key, String? cacheValue]) async {
  if (cacheValue != null) {
    _cache[key ?? url] = cacheValue;
    return cacheValue;
  }

  if (_cache.containsKey(key ?? url)) {
    return _cache[key ?? url]!;
  }
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    _cache[key ?? url] = response.body;
    return _cache[key ?? url]!;
  } else {
    throw Exception('Failed to load data from $url');
  }
}

String _cached(String key) {
  if (_cache.containsKey(key)) {
    return _cache[key]!;
  } else {
    throw Exception('Data for $key not found in cache');
  }
}

Future<List<_VpsPlan>> _fetchPlans() async {
  final response = await _fetch(
    'https://vpsdime.com/pricing.json',
    'pricing',
    _jsonPricing,
  );
  final groups = json.decode(response) as List<dynamic>;

  // Find the "Linux VPS" group and parse all plans
  final linuxGroup =
      groups.firstWhere((g) => g['group_name'] == 'Linux VPS')
          as Map<String, dynamic>;
  final allPlans = (linuxGroup['products'] as List<dynamic>)
      .map((p) => _VpsPlan.fromJson(p as Map<String, dynamic>))
      .toList();
  return allPlans;
}

Future<Uint8List> generateServer(
  PdfPageFormat pageFormat,
  CustomData data,
) async {
  // ---- Fetch pricing data ------------------------------------------------
  final allPlans = await _fetchPlans();
  await _fetch(
    'https://vpsdime.com/assets/images/navbar-logo.svg',
    'logo',
    _svgLogo,
  );
  await _fetch(
    'https://vpsdime.com/assets/images/highram.svg',
    'highram',
    _svgRam,
  );
  await _fetch(
    'https://vpsdime.com/assets/images/enterprise-ssd.svg',
    'ssd',
    _svgSsd,
  );
  await _fetch(
    'https://vpsdime.com/assets/images/no-overselling.svg',
    'over',
    _svgOver,
  );
  await _fetch(
    'https://vpsdime.com/assets/images/bangforbuck.svg',
    'bang',
    _svgBang,
  );
  await _fetch(
    'https://vpsdime.com/assets/images/connection-icon.svg',
    'net',
    _svgNet,
  );
  await _fetch(
    'https://vpsdime.com/assets/images/cpu-icon.svg',
    'cpu',
    _svgCpu1,
  );

  // Select the featured plan (Linux12GB)
  final plan = allPlans.firstWhere((p) => p.name == 'Linux12GB');

  // Plans to show in the comparison chart (Linux4GB … Linux30GB)
  final chartPlans =
      allPlans.where((p) {
        final n = int.tryParse(p.name.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        return n >= 4 && n <= 30;
      }).toList()..sort((a, b) {
        final na = int.tryParse(a.name.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final nb = int.tryParse(b.name.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        return na.compareTo(nb);
      });

  // ---- Load fonts --------------------------------------------------------
  final baseFont = await PdfGoogleFonts.metrophobicRegular();
  // final boldFont = await PdfGoogleFonts.openSansBold();

  // ---- Build the document -----------------------------------------------
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: pageFormat,
        buildBackground: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Column(
            children: [
              pw.SvgImage(
                svg: _svgBanner,
                height: 190,
                fit: pw.BoxFit.fitWidth,
                alignment: pw.Alignment.bottomLeft,
              ),
            ],
          ),
        ),
        theme: pw.ThemeData.withFont(base: baseFont, bold: baseFont),
        margin: const pw.EdgeInsets.all(40),
      ),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // 1. Header banner
            _buildHeader(plan),

            pw.SizedBox(height: 16),

            // 2. Specs grid
            _buildSpecsRow(plan),

            pw.SizedBox(height: 20),

            // 3. Price comparison chart
            pw.Text(
              'Price Comparison',
              style: const pw.TextStyle(
                color: _primaryMid,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Expanded(flex: 4, child: _buildPriceChart(chartPlans)),

            pw.SizedBox(height: 14),

            // 4. Key features row
            pw.Text(
              'Key Features',
              style: const pw.TextStyle(
                color: _primaryMid,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            _buildFeaturesRow(),

            pw.SizedBox(height: 14),

            // 5. Addon options table
            pw.Text(
              'Available Addons',
              style: const pw.TextStyle(
                color: _primaryMid,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            _buildAddonTable(plan.addons),

            pw.SizedBox(height: 14),

            // 6. Footer with clickable link
            _buildFooter(plan),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

// -------------------------------------------------------------------------
// Section builders
// -------------------------------------------------------------------------

/// Dark header banner with server name, tagline and price.
pw.Widget _buildHeader(_VpsPlan plan) {
  return pw.Column(
    children: [
      pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.SvgImage(svg: _cached('logo'), height: 20),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: 40,
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  plan.name,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'High Memory Linux VPS',
                  style: pw.TextStyle(
                    color: PdfColors.blueGrey100,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '\$${plan.monthlyPrice.toInt()}',
                    style: pw.TextStyle(
                      color: _accent,
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'per month',
                    style: pw.TextStyle(color: _primaryMid, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Specs displayed as a horizontal row of cards with SVG icons.
pw.Widget _buildSpecsRow(_VpsPlan plan) {
  final specs = [
    _SpecCard(_svgCpu, 'vCPU', '${plan.vcpu} Cores'),
    _SpecCard(_cached('highram'), 'RAM', '${plan.memoryGb} GB ECC'),
    _SpecCard(_cached('ssd'), 'Storage', '${plan.storageGb} GB NVMe SSD'),
    _SpecCard(_svgTraffic, 'Traffic', '${plan.trafficTb} TB/mo'),
    _SpecCard(_cached('ssd'), 'Uplink', '${plan.uplinkGbps} Gbps'),
  ];

  return pw.Row(
    children: specs
        .map(
          (s) => pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 3),
              padding: const pw.EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 4,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.SvgImage(
                    svg: s.iconSvg,
                    width: 22,
                    height: 22,
                    colorFilter: PdfColor.fromHex('#7cac60'),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    s.label,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    s.value,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryMid,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(),
  );
}

/// Bar chart comparing monthly prices of several plans.
pw.Widget _buildPriceChart(List<_VpsPlan> plans) {
  // Build short labels: "4GB", "6GB", "12GB"…
  final labels = plans.map((p) {
    final mem = p.memoryGb;
    return '${mem}GB';
  }).toList();

  return pw.Chart(
    grid: pw.CartesianGrid(
      xAxis: pw.FixedAxis.fromStrings(
        labels,
        marginStart: 20,
        marginEnd: 20,
        ticks: true,
      ),
      yAxis: pw.FixedAxis(
        [0, 10, 20, 30, 40],
        format: (v) => '\$${v.toInt()}',
        divisions: true,
      ),
    ),
    datasets: [
      pw.BarDataSet(
        color: _accentLight,
        borderColor: _accent,
        legend: 'Monthly price',
        width: 20,
        data: plans
            .map(
              (p) => pw.PointChartValue(
                plans.indexOf(p).toDouble(),
                p.monthlyPrice,
              ),
            )
            .toList(),
      ),
    ],
  );
}

/// Three feature callout cards with SVG icons.
pw.Widget _buildFeaturesRow() {
  final features = [
    _FeatureCard(
      _cached('bang'),
      'Best Bang for Buck',
      'High performance at the lowest price point in the market.',
    ),
    _FeatureCard(
      _cached('ssd'),
      'Enterprise NVMe SSD',
      'Lightning-fast enterprise NVMe solid state drives on every plan.',
    ),
    _FeatureCard(
      _cached('over'),
      'No Overselling',
      'Dedicated resources with consistent performance 24/7.',
    ),
  ];

  return pw.Row(
    children: features
        .map(
          (f) => pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 3),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _bgLight,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.SvgImage(svg: f.iconSvg, width: 20, height: 20),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Text(
                          f.title,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _primaryMid,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    f.description,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(),
  );
}

/// Table showing available addon options and their pricing.
pw.Widget _buildAddonTable(List<_Addon> addons) {
  final rows = addons.map((a) {
    final detail = a.unit.isNotEmpty ? '${a.unit} × up to ${a.qtyMax}' : '';
    final price = a.monthlyPrice > 0
        ? '\$${a.monthlyPrice.toStringAsFixed(a.monthlyPrice == a.monthlyPrice.roundToDouble() ? 0 : 2)}/mo'
        : 'Free';
    return [a.name, detail, price];
  }).toList();

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.TableHelper.fromTextArray(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      ),
      headerCount: 0,
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _primaryMid),
      data: rows,
      headers: ['Addon', 'Details', 'Price'],
    ),
  );
}

/// Footer section with a clickable "Order Now" link.
pw.Widget _buildFooter(_VpsPlan plan) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.RichText(
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            children: [
              pw.TextSpan(text: 'Data sourced from '),
              pw.TextSpan(
                text: 'vpsdime.com',
                style: pw.TextStyle(
                  decoration: pw.TextDecoration.underline,
                  color: PdfColor.fromHex('#7cac60'),
                ),
                annotation: pw.AnnotationUrl('https://vpsdime.com'),
              ),
              pw.TextSpan(text: ' · Prices subject to change'),
            ],
          ),
        ),
        pw.RichText(
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 7),
            children: [
              pw.TextSpan(
                text: 'Order Now',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _success,
                  decoration: pw.TextDecoration.underline,
                ),
                annotation: pw.AnnotationUrl(plan.orderLink),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Helper data classes for UI sections
// ---------------------------------------------------------------------------

class _SpecCard {
  const _SpecCard(this.iconSvg, this.label, this.value);

  final String iconSvg;
  final String label;
  final String value;
}

class _FeatureCard {
  const _FeatureCard(this.iconSvg, this.title, this.description);

  final String iconSvg;
  final String title;
  final String description;
}

// ---------------------------------------------------------------------------
// SVG icons used throughout the datasheet (inline, no external files needed)
// ---------------------------------------------------------------------------

const _svgCpu = '''
<svg id="Ñëîé_1" style="enable-background:new 0 0 36 36;" version="1.1" viewbox="0 0 36 36" x="0px" width="36" height="36" xml:space="preserve"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink" y="0px">
  <path style="fill:#6FB158;" d="M35.14,13.89c0.48,0,0.86-0.39,0.86-0.86c0-0.48-0.39-0.86-0.86-0.86h-3.11V8.92h3.11
                                c0.48,0,0.86-0.39,0.86-0.86c0-0.48-0.39-0.86-0.86-0.86h-3.11V4.83c0-0.48-0.39-0.86-0.86-0.86h-2.36V0.86
                                c0-0.48-0.39-0.86-0.86-0.86c-0.48,0-0.86,0.39-0.86,0.86v3.11h-3.25V0.86c0-0.48-0.39-0.86-0.86-0.86c-0.48,0-0.86,0.39-0.86,0.86
                                v3.11h-3.25V0.86C18.86,0.39,18.48,0,18,0c-0.48,0-0.86,0.39-0.86,0.86v3.11h-3.25V0.86C13.89,0.39,13.5,0,13.03,0
                                c-0.48,0-0.86,0.39-0.86,0.86v3.11H8.92V0.86C8.92,0.39,8.53,0,8.05,0C7.58,0,7.19,0.39,7.19,0.86v3.11H4.83
                                c-0.48,0-0.86,0.39-0.86,0.86v2.36H0.86C0.39,7.19,0,7.58,0,8.05c0,0.48,0.39,0.86,0.86,0.86h3.11v3.25H0.86
                                C0.39,12.17,0,12.55,0,13.03c0,0.48,0.39,0.86,0.86,0.86h3.11v3.25H0.86C0.39,17.14,0,17.52,0,18s0.39,0.86,0.86,0.86h3.11v3.25
                                H0.86C0.39,22.11,0,22.5,0,22.97s0.39,0.86,0.86,0.86h3.11v3.25H0.86C0.39,27.08,0,27.47,0,27.95c0,0.48,0.39,0.86,0.86,0.86h3.11
                                v2.36c0,0.48,0.39,0.86,0.86,0.86h2.36v3.11c0,0.48,0.39,0.86,0.86,0.86c0.48,0,0.86-0.39,0.86-0.86v-3.11h3.25v3.11
                                c0,0.48,0.39,0.86,0.86,0.86c0.48,0,0.86-0.39,0.86-0.86v-3.11h3.25v3.11c0,0.48,0.39,0.86,0.86,0.86c0.48,0,0.86-0.39,0.86-0.86
                                v-3.11h3.25v3.11c0,0.48,0.39,0.86,0.86,0.86c0.48,0,0.86-0.39,0.86-0.86v-3.11h3.25v3.11c0,0.48,0.39,0.86,0.86,0.86
                                c0.48,0,0.86-0.39,0.86-0.86v-3.11h2.36c0.48,0,0.86-0.39,0.86-0.86v-2.36h3.11c0.48,0,0.86-0.39,0.86-0.86
                                c0-0.48-0.39-0.86-0.86-0.86h-3.11v-3.25h3.11c0.48,0,0.86-0.39,0.86-0.86s-0.39-0.86-0.86-0.86h-3.11v-3.25h3.11
                                c0.48,0,0.86-0.39,0.86-0.86s-0.39-0.86-0.86-0.86h-3.11v-3.25H35.14z M30.31,30.31H5.69V5.69h24.61V30.31z"></path></svg>
''';

const _svgTraffic = '''
<svg id="Ñëîé_1" style="enable-background:new 0 0 36 39.73;" version="1.1" viewbox="0 0 36 39.73" x="0px" xml:space="preserve"
  xmlns="http://www.w3.org/2000/svg" width="36" height="39.73"
  xmlns:xlink="http://www.w3.org/1999/xlink" y="0px">
  <path class="st0" d="M31.63,25.57c2.41,0,4.37-1.96,4.37-4.37c0-1.11-0.42-2.12-1.1-2.89c0.48-1.07,0.73-2.24,0.73-3.42
                                    c0-4.62-3.76-8.38-8.38-8.38c-0.58,0-1.16,0.06-1.72,0.18C23.72,2.67,19.64,0,15.18,0C8.92,0,3.82,5.1,3.82,11.36
                                    c0,0.35,0.02,0.69,0.05,1.03C1.5,13.55,0,15.94,0,18.62c0,3.83,3.12,6.95,6.95,6.95c0,0,0.01,0,0.01,0h6.81v1.32
                                    c0,0.6-0.23,1.15-0.65,1.57l-0.59,0.59c-0.53-0.34-1.16-0.54-1.84-0.54c-1.91,0-3.46,1.55-3.46,3.46c0,1.91,1.55,3.46,3.46,3.46
                                    c1.91,0,3.46-1.55,3.46-3.46c0-0.68-0.2-1.31-0.54-1.84l0.59-0.59c0.71-0.71,1.1-1.65,1.1-2.65v-1.32h2.17v2.5
                                    c0,0.4,0.15,0.81,0.42,1.18c0.24,0.33,0.59,0.58,1.06,0.79c0.04,0.02,0.11,0.15,0.11,0.45v2.42c-1.54,0.35-2.69,1.73-2.69,3.37
                                    c0,1.91,1.55,3.46,3.46,3.46c1.91,0,3.46-1.55,3.46-3.46c0-1.64-1.15-3.02-2.69-3.37v-2.42c0-1.28-0.73-1.72-1.04-1.86
                                    c-0.21-0.09-0.35-0.18-0.43-0.28c-0.1-0.13-0.12-0.24-0.12-0.28v-2.5h2.76v2.52c0,1.29,1.04,2.33,2.36,2.33
                                    c0.21,0,0.42,0.08,0.57,0.24l1.09,1.09c-0.34,0.53-0.54,1.16-0.54,1.84c0,1.91,1.55,3.46,3.46,3.46c1.91,0,3.46-1.55,3.46-3.46
                                    c0-1.91-1.55-3.46-3.46-3.46c-0.68,0-1.31,0.2-1.84,0.54l-1.09-1.09c-0.44-0.44-1.03-0.68-1.68-0.68c-0.44,0-0.8-0.36-0.8-0.81
                                    v-2.52H31.63z M10.68,33.91c-1.06,0-1.93-0.87-1.93-1.93s0.87-1.93,1.93-1.93c1.06,0,1.93,0.87,1.93,1.93S11.75,33.91,10.68,33.91z
                                     M21.75,36.28c0,1.06-0.87,1.93-1.93,1.93c-1.06,0-1.93-0.87-1.93-1.93c0-1.06,0.87-1.93,1.93-1.93
                                    C20.88,34.35,21.75,35.21,21.75,36.28z M30.61,33.58c0,1.06-0.87,1.93-1.93,1.93c-1.06,0-1.93-0.87-1.93-1.93s0.87-1.93,1.93-1.93
                                    C29.75,31.65,30.61,32.52,30.61,33.58z M1.53,18.62c0-2.21,1.38-4.24,3.44-5.05c0.63-0.25,1.3-0.37,1.98-0.37
                                    c2.99,0,5.43,2.43,5.43,5.43c0,0.92-0.22,1.79-0.66,2.6c-0.2,0.37-0.07,0.83,0.3,1.04c0.37,0.2,0.83,0.07,1.04-0.3
                                    c0.55-1.02,0.85-2.17,0.85-3.33c0-3.83-3.12-6.95-6.95-6.95c-0.54,0-1.07,0.07-1.58,0.19c-0.01-0.16-0.02-0.33-0.02-0.5
                                    c0-5.42,4.41-9.83,9.83-9.83c4.06,0,7.76,2.55,9.19,6.35c0.43,1.11,0.64,2.29,0.64,3.49c0,3.15-1.45,6.03-3.98,7.9
                                    c-0.34,0.25-0.41,0.73-0.16,1.07c0.15,0.2,0.38,0.31,0.61,0.31c0.16,0,0.32-0.05,0.45-0.15c2.88-2.14,4.6-5.55,4.6-9.13
                                    c0-1.1-0.16-2.17-0.47-3.21c0.39-0.07,0.78-0.11,1.18-0.11c3.78,0,6.85,3.07,6.85,6.85c0,0.85-0.15,1.66-0.45,2.44
                                    c-0.61-0.32-1.29-0.5-2.03-0.5c-0.42,0-0.76,0.34-0.76,0.76s0.34,0.76,0.76,0.76c1.57,0,2.84,1.27,2.84,2.84
                                    c0,1.57-1.27,2.84-2.84,2.84H6.95c0,0,0,0-0.01,0C3.96,24.04,1.53,21.61,1.53,18.62z"></path>
</svg>
''';

const _svgBanner = '''
<svg xmlns="http://www.w3.org/2000/svg" xml:space="preserve" id="Layer_1" x="0" y="0" viewBox="0 0 1920 4881.7"><path d="M1920 4742c-67.3-6.1-125.2-8.5-176.7-7.1-46.1 1.2-86.3 5.4-122.8 12.8-68 13.8-111.6 36.1-157.8 59.8-2.1 1.1-4.3 2.2-6.4 3.3l.1.3c10.6-4.5 21.1-9.3 31.4-14.4 69.8-34.6 181.2-66.8 315.9-23.3 35.3-2.5 74.4-4.7 116.2-6.7z" style="fill:#97d67f"/><path d="M1803.9 4773.1c-57.9-18.7-116.5-25-174-18.8-48.7 5.3-96.5 19.4-142.1 42.1-10.3 5.1-20.9 10-31.4 14.4-8.4 4.3-18.3 9.3-28.5 14.3l-.9.4 1-.2c27-4.5 51.7-9 75.5-13.4 78.7-14.5 153-28.2 300.4-38.6l.8-.1z" style="fill:#9dd78b"/><path d="M1410.8 4827.9c-49.9-16.1-104.9-33.7-127-39.1-93.6-23.1-176.1-36.4-298-31.1l-1.2.1 1.2.2c106.9 22.1 346.3 69.2 375.4 74.4 2.8.5 5.7 1 8.6 1.5 13.8-1.6 27.5-3.5 40.9-5.6l.6-.1z" style="fill:#90ce78"/><path d="M985.9 4757.7c-23.9-4.9-39-8.2-44.9-9.6-65-16-132.6-22.2-177.9-24.6-51.9-2.7-104.4-1.9-140.6 2.1-45.4 5.1-84.5 10.2-122.3 15.2-92.4 12.2-168.6 22.2-275.5 22.2-61.6 0-133.5-3.3-224.6-11.5v.5c37.2 14.4 73.5 26.8 107.9 36.8 105.7-5.6 267.6-18.3 494.8-38.8 48.3-4.4 127.8 4 218 23 32.5-3.7 60.9-6.9 67.5-7.6 35.3-3.6 67.2-6.1 97.6-7.4h1.2z" style="fill:#96cd83"/><path d="M58.6 4790.7c-24.7.9-41.8 1.2-55.6 1.4H0v5.4c8.3-.1 17.3 0 28.8.1 10.1.1 21.9.3 36.3.3 17.1 0 37.7-.2 63.3-.9v-.3c-20.3-1.5-43.1-3.5-69.8-6" style="fill:#c6dfc0"/><path d="M0 4785.1v7.4h3c13.8-.2 30.9-.5 55.6-1.4v-.3c-17.8-1.7-37.5-3.6-58.6-5.7M137.3 4796.5c-2.6.1-5.2.1-7.7.2h-1.3v.3c5.4.4 9.9.8 14 1.1l.1-.3c-1.9-.4-3.5-.8-5.1-1.3" style="fill:#a0cc94"/><path d="M137.3 4796.5c-9.5-2.5-19.4-5.2-29.3-8.1-17.7 1-33.8 1.7-49.3 2.3v.3c26.7 2.5 49.5 4.5 69.7 6.1h1.3c2.5-.1 5.1-.1 7.6-.2h1z" style="fill:#a0cc94"/><path d="M1410.9 4828s-.1 0 0 0h-.2c-13.4 2.1-27.1 4-40.9 5.6l-1.1.1 1 .2c4.8.8 9.9 1.6 15.2 2.4 8.8-2.5 17.5-5.2 25.8-7.9l.5-.2z" style="fill:#9ad386"/><path d="m1417.5 4830.1-6.6-2.1h-.2c-8.3 2.8-16.9 5.4-25.8 7.9l-.7.2.7.1c5.3.8 10.2 1.4 15 2 3.8-1.6 7.6-3.3 11.2-5 2.3-1 4.3-2 6.1-2.8l.3-.2z" style="fill:#abd99a"/><path d="M1427.8 4825.2c-5.6.9-11.2 1.8-16.5 2.7h-.1c-.1 0-.2.1-.3.1l-.5.1.5.2 6.6 2.1h.2c3.8-1.8 7.4-3.5 10.4-5l.9-.5z" style="fill:#abd89b"/><path d="M1855.1 4792.9c-17-7.7-34.3-14.3-51.2-19.8-147.4 10.4-221.8 24.1-300.5 38.6-23.8 4.4-48.5 8.9-75.5 13.4-3 1.5-6.6 3.2-10.4 5l-.3.2.4.1c4.4 1.4 8.8 2.8 13 4.2 9.9 3.2 19.2 6.2 27.3 8.8 21 1.3 42.5 1.9 64.2 1.9 43.5 0 87.8-2.5 130.9-7.4 73.5-8.4 141.6-23.4 202.3-44.6l.3-.1z" style="fill:#addb9b"/><path d="M820.8 4772.6c-90.3-19-169.8-27.4-218.1-23-227.2 20.5-389.1 33.2-494.8 38.8h-.9l.8.3c9.9 2.9 19.7 5.6 29.3 8.1 1.6.4 3.3.9 5.1 1.3 42.6 3.2 73.5 4.5 99.4 4.5 37.4 0 64.4-2.7 101.1-6.4 50-5 118.4-11.8 255.1-16.5 47.3-3.2 92-2.2 136.8 3.2 23.8-2.8 49.2-5.7 73.3-8.5 4.4-.5 8.6-1 12.8-1.5l.9-.1z" style="fill:#a5d297"/><path d="M734.7 4782.6c-44.8-5.3-89.6-6.4-136.9-3.2-136.7 4.7-205.1 11.5-255.1 16.5-62.2 6.2-96.4 9.6-200.4 1.9l-.1.3c72.6 18.6 139.1 27.4 208.1 27.4 4.7 0 9.4 0 14.2-.1 66.2-1.1 127.5-10.1 192.3-19.5 21.2-3.1 43.1-6.3 65.6-9.3 21.9-2.9 59.6-7.5 112.3-13.7l1.3-.2z" style="fill:#c0dcb9"/><path d="M991.2 4821.2c-39.6-14.2-77-27.5-113.9-35.6-3.5-.9-7.6-1.9-11.8-2.9-18.2-3.2-37.5-6.1-57.5-8.6-24.2 2.8-49.5 5.7-73.3 8.5l-1.3.2 1.3.1c62.1 7.4 116.8 22.3 169.6 36.7 64.2 17.5 130.6 35.6 212.6 41.4v-.3c-44.1-10.4-85.6-25.2-125.7-39.5" style="fill:#c3dfba"/><path d="M1369.9 4833.6c-2.9-.5-5.8-1-8.6-1.5-29.1-5.2-268.5-52.3-375.4-74.4-30.4 1.3-62.3 3.7-97.6 7.4-6.5.7-34.9 3.9-67.5 7.6l-.9.1.9.2c14.5 3.1 29.5 6.4 44.7 10.1 20.5 3.6 39.8 7.7 57.6 12 2.6.6 6.1 1.6 10.5 2.7 26.9 7.1 83 22 159.5 32.3 52.6 7.1 104.7 10.7 155.8 10.7 41.1 0 81.5-2.3 121.1-6.9l1.1-.1z" style="fill:#9ad386"/><path d="M1456.3 4810.9c-14.7 6.2-29.8 11.9-45.1 17l.1.3h.1q8.1-1.35 16.5-2.7c10.2-4.9 20.1-10 28.5-14.3z" style="fill:#abd99a"/><path d="M1400.1 4837.9c-4.9-.6-9.8-1.2-15-2-63.4 18-131.3 26.8-207.2 26.8-3.7 0-7.3 0-11-.1-16.7-.1-33.4-.8-49.8-1.9v.3c39.2 9.2 75.8 13.8 111.4 13.8 7.1 0 14.1-.2 21.1-.5 50.9-2.6 100.2-14.4 150.8-36l.5-.2z" style="fill:#c6e3bc"/><path d="M1385.1 4835.9c-5.3-.8-10.4-1.6-15.2-2.4-138.5 16.1-285.3 4-436.3-36.1q-6.6-1.8-10.5-2.7c-17.7-4.4-37.1-8.4-57.6-12l-.1.3c4.2 1 8.3 2 11.8 2.9 36.9 8.1 74.3 21.4 113.9 35.6 40.1 14.3 81.6 29.2 125.8 39.6 16.4 1.2 33.2 1.8 49.9 1.9 3.7 0 7.4.1 11 .1 76 0 143.9-8.8 207.3-26.8l.7-.2z" style="fill:#a9d798"/><path d="M865.5 4782.8c-19-3.3-38.3-6.2-57.5-8.6 4.4-.5 8.6-1 12.8-1.5 14.6 3.1 29.5 6.5 44.7 10.1" style="fill:#c3dfba"/><path d="M1457.8 4843.1c-8.1-2.6-17.4-5.6-27.3-8.8-4.2-1.4-8.6-2.8-13-4.2h-.2c-1.8.9-3.8 1.8-6.1 2.8-3.7 1.7-7.4 3.4-11.2 5l-.5.2.6.1c18.3 2.3 37.7 4 57.7 5.2l1.2.1z" style="fill:#c5e2bd"/><linearGradient id="SVGID_1_" x1="-682.787" x2="2599.592" y1="6047.203" y2="7340.167" gradientTransform="matrix(1 0 0 -1 0 9065.412)" gradientUnits="userSpaceOnUse"><stop offset="0" style="stop-color:#6fb158"/><stop offset=".337" style="stop-color:#72b65a"/><stop offset=".74" style="stop-color:#7cc562"/><stop offset="1" style="stop-color:#84d268"/></linearGradient><path d="M0 0v4751.6c312.5 28 398.3-.9 622.4-25.9 65-7.3 203.6-5.9 318.5 22.5 6.3 1.6 22.5 5 45 9.6 123.3-5.4 205.5 8.3 297.9 31.1 22.2 5.5 78.8 23.6 127 39.1h.3c14.9-4.9 30.2-10.7 45.3-17.1 93.3-47.8 177.3-95 463.7-68.8V0z" style="fill:url(#SVGID_1_)"/><path d="M1920 4827.3c-21.5-13.2-43.3-24.8-64.8-34.5h-.2c-96 33.6-214.2 52-332.8 52-21.8 0-43.4-.6-64.4-1.9l-2.4-.1 2.3.7c7.7 2.4 15.6 5 21.3 6.7 30.2 9.3 61.5 16.7 92.9 21.9 38 6.3 76.4 9.5 114.1 9.5 81.2 0 160-14.8 234-44z" style="fill:#c7e5be"/><path d="M1920 4766.4c-41.8 2-80.9 4.2-116.2 6.7l-.8.1.7.2c16.9 5.5 34.2 12.1 51.2 19.8h.2c22.8-8 44.6-16.9 64.9-26.5z" style="fill:#a1d98c"/><path d="M1920 4766.4c-20.4 9.6-42.2 18.5-65 26.5l-.3.1.3.1c21.6 9.7 43.4 21.4 64.9 34.6l.1.1z" style="fill:#afde9d"/><path d="M108 4788.4c-34.3-10-70.7-22.4-107.9-36.8H0v33.8c21.1 2.1 40.8 4 58.6 5.7 15.5-.6 31.7-1.3 49.3-2.3l.9-.1z" style="fill:#8dc57c"/></svg>
''';

const _svgRam = '''
<svg version="1.1" id="ICONS_48x48"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 72 72" style="enable-background:new 0 0 72 72;" xml:space="preserve">
  <g>
    <path style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" d="M71,42.1V29.9l-7.6-1.5
                           c-0.6-2.4-1.8-4-3-6.1l4.6-6.1l-9.1-9.1l-6.1,4.6c-2.1-1.2-3.7-2.4-6.1-3L42.1,1H29.9l-1.5,7.6c-2.4,0.6-4,1.8-6.1,3L16.2,7
                           l-9.1,9.1l4.6,6.1c-1.1,2.1-2.4,3.8-3,6.1L1,29.9v12.2l7.6,1.5c0.8,2.4,1.8,4,3,6.1L7,55.8l9.1,9.1l6.1-4.6c2.1,1.4,3.7,2.4,6.1,3
                           l1.5,7.6H42l1.5-7.6c2.4-0.6,4-1.8,6.1-3l6.1,4.6l9.1-9.1l-4.6-6.1c1.2-2.1,2.4-3.7,3-6.1L71,42.1z"/>
    <circle style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" cx="36" cy="36" r="13.3"/>
  </g>
</svg>
''';

const _svgLogo = '''
<svg version="1.1" id="Layer_1"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 166.73 48" style="enable-background:new 0 0 166.73 48;" xml:space="preserve">
  <g>
    <path style="fill:#FFFFFF;" d="M23.48,12.79c-1.3,4.86-2.82,9.52-4.57,13.99c-1.75,4.46-3.44,8.46-5.07,11.99h-4.2
                 c-1.63-3.53-3.32-7.53-5.07-11.99C2.82,22.31,1.3,17.65,0,12.79h4.99c0.4,1.63,0.87,3.37,1.42,5.22c0.55,1.85,1.13,3.68,1.75,5.49
                 c0.62,1.82,1.24,3.57,1.87,5.27c0.63,1.7,1.23,3.21,1.8,4.55c0.57-1.33,1.16-2.85,1.8-4.55c0.63-1.7,1.26-3.45,1.87-5.27
                 c0.62-1.81,1.2-3.65,1.75-5.49c0.55-1.85,1.02-3.59,1.42-5.22H23.48z"/>
    <path style="fill:#FFFFFF;" d="M48.15,25.82c0,1.96-0.26,3.78-0.77,5.44c-0.52,1.66-1.27,3.1-2.27,4.3c-1,1.2-2.22,2.13-3.67,2.8
                 c-1.45,0.67-3.11,1-4.97,1c-1.5,0-2.82-0.2-3.97-0.6c-1.15-0.4-2.01-0.78-2.57-1.15V48h-4.65V13.59c1.1-0.27,2.47-0.56,4.12-0.87
                 c1.65-0.32,3.55-0.47,5.72-0.47c2,0,3.8,0.32,5.39,0.95c1.6,0.63,2.96,1.53,4.1,2.7c1.13,1.17,2.01,2.59,2.62,4.27
                 C47.84,21.84,48.15,23.73,48.15,25.82z M43.3,25.82c0-3.03-0.75-5.36-2.25-6.99c-1.5-1.63-3.5-2.45-5.99-2.45
                 c-1.4,0-2.49,0.05-3.27,0.15c-0.78,0.1-1.41,0.22-1.87,0.35v16.38c0.57,0.47,1.38,0.92,2.45,1.35c1.07,0.43,2.23,0.65,3.5,0.65
                 c1.33,0,2.47-0.24,3.42-0.72c0.95-0.48,1.72-1.15,2.32-2c0.6-0.85,1.03-1.85,1.3-3C43.17,28.4,43.3,27.16,43.3,25.82z"/>
    <path style="fill:#FFFFFF;" d="M57.74,35.41c1.9,0,3.3-0.25,4.22-0.75c0.92-0.5,1.37-1.3,1.37-2.4c0-1.13-0.45-2.03-1.35-2.7
                 c-0.9-0.67-2.38-1.42-4.45-2.25c-1-0.4-1.96-0.81-2.87-1.22c-0.92-0.42-1.71-0.91-2.37-1.47c-0.67-0.57-1.2-1.25-1.6-2.05
                 s-0.6-1.78-0.6-2.95c0-2.3,0.85-4.12,2.55-5.47c1.7-1.35,4.01-2.02,6.94-2.02c0.73,0,1.46,0.04,2.2,0.13
                 c0.73,0.08,1.41,0.18,2.05,0.3c0.63,0.12,1.19,0.24,1.67,0.37c0.48,0.13,0.86,0.25,1.12,0.35l-0.85,4
                 c-0.5-0.27-1.28-0.54-2.35-0.82c-1.07-0.28-2.35-0.42-3.85-0.42c-1.3,0-2.43,0.26-3.4,0.77c-0.97,0.52-1.45,1.32-1.45,2.42
                 c0,0.57,0.11,1.07,0.32,1.5c0.22,0.43,0.55,0.82,1,1.17c0.45,0.35,1.01,0.67,1.67,0.97c0.67,0.3,1.46,0.62,2.4,0.95
                 c1.23,0.47,2.33,0.92,3.3,1.37c0.97,0.45,1.79,0.97,2.47,1.57c0.68,0.6,1.21,1.32,1.57,2.17c0.37,0.85,0.55,1.89,0.55,3.12
                 c0,2.4-0.89,4.21-2.67,5.44c-1.78,1.23-4.32,1.85-7.62,1.85c-2.3,0-4.1-0.19-5.39-0.57c-1.3-0.38-2.18-0.67-2.65-0.87l0.85-4
                 c0.53,0.2,1.38,0.5,2.55,0.9C54.26,35.21,55.81,35.41,57.74,35.41z"/>
    <path style="fill:#C5F5B4;" d="M87.76,0.8L92.4,0v38.01c-1.07,0.3-2.43,0.6-4.1,0.9c-1.67,0.3-3.58,0.45-5.74,0.45
                 c-2,0-3.8-0.32-5.39-0.95c-1.6-0.63-2.96-1.53-4.1-2.7c-1.13-1.16-2.01-2.59-2.62-4.27c-0.62-1.68-0.92-3.57-0.92-5.67
                 c0-2,0.26-3.83,0.77-5.49c0.52-1.66,1.27-3.1,2.27-4.3c1-1.2,2.22-2.13,3.67-2.8c1.45-0.66,3.1-1,4.97-1c1.5,0,2.82,0.2,3.97,0.6
                 c1.15,0.4,2.01,0.78,2.57,1.15V0.8z M87.76,18.28c-0.57-0.47-1.38-0.92-2.45-1.35c-1.07-0.43-2.23-0.65-3.5-0.65
                 c-1.33,0-2.47,0.24-3.42,0.72c-0.95,0.48-1.72,1.15-2.32,2c-0.6,0.85-1.03,1.86-1.3,3.02c-0.27,1.17-0.4,2.42-0.4,3.75
                 c0,3.03,0.75,5.37,2.25,7.02c1.5,1.65,3.5,2.47,5.99,2.47c1.27,0,2.32-0.06,3.17-0.17c0.85-0.12,1.51-0.24,1.97-0.37V18.28z"/>
    <path style="fill:#C5F5B4;" d="M98.94,8.09c-0.83,0-1.54-0.27-2.12-0.82c-0.58-0.55-0.87-1.29-0.87-2.22
                 c0-0.93,0.29-1.67,0.87-2.22C97.39,2.27,98.1,2,98.94,2c0.83,0,1.54,0.27,2.12,0.82c0.58,0.55,0.87,1.29,0.87,2.22
                 c0,0.93-0.29,1.67-0.87,2.22C100.48,7.82,99.77,8.09,98.94,8.09z M101.28,38.76h-4.65V12.79h4.65V38.76z"/>
    <path style="fill:#C5F5B4;" d="M105.49,13.54c1.07-0.27,2.47-0.55,4.22-0.85c1.75-0.3,3.77-0.45,6.07-0.45
                 c1.66,0,3.06,0.23,4.2,0.67c1.13,0.45,2.08,1.11,2.85,1.97c0.23-0.17,0.6-0.4,1.1-0.7c0.5-0.3,1.11-0.59,1.85-0.87
                 c0.73-0.28,1.55-0.53,2.45-0.75c0.9-0.22,1.86-0.32,2.9-0.32c2,0,3.63,0.29,4.89,0.87c1.26,0.58,2.26,1.41,2.97,2.47
                 c0.72,1.07,1.2,2.33,1.45,3.8c0.25,1.47,0.37,3.06,0.37,4.79v14.59h-4.65V25.17c0-1.53-0.07-2.85-0.22-3.95
                 c-0.15-1.1-0.43-2.01-0.85-2.75c-0.42-0.73-0.98-1.27-1.7-1.62c-0.72-0.35-1.64-0.52-2.77-0.52c-1.57,0-2.86,0.21-3.87,0.62
                 c-1.02,0.42-1.71,0.79-2.07,1.12c0.27,0.87,0.47,1.82,0.6,2.85c0.13,1.03,0.2,2.11,0.2,3.25v14.59h-4.64V25.17
                 c0-1.53-0.08-2.85-0.25-3.95c-0.17-1.1-0.46-2.01-0.87-2.75c-0.42-0.73-0.98-1.27-1.7-1.62c-0.72-0.35-1.62-0.52-2.72-0.52
                 c-0.47,0-0.97,0.02-1.5,0.05c-0.53,0.03-1.04,0.07-1.52,0.12c-0.48,0.05-0.92,0.11-1.32,0.17c-0.4,0.07-0.67,0.12-0.8,0.15v21.93
                 h-4.65V13.54z"/>
    <path style="fill:#C5F5B4;" d="M144.05,25.82c0-2.3,0.33-4.3,1-6.02c0.67-1.71,1.55-3.14,2.65-4.27c1.1-1.13,2.36-1.98,3.8-2.55
                 c1.43-0.57,2.9-0.85,4.4-0.85c3.5,0,6.18,1.09,8.04,3.27c1.86,2.18,2.8,5.5,2.8,9.96c0,0.2,0,0.46,0,0.77
                 c0,0.32-0.02,0.61-0.05,0.87H148.9c0.2,2.7,0.98,4.75,2.35,6.14c1.36,1.4,3.5,2.1,6.39,2.1c1.63,0,3-0.14,4.12-0.42
                 c1.12-0.28,1.96-0.56,2.52-0.82l0.65,3.9c-0.57,0.3-1.56,0.62-2.97,0.95c-1.42,0.33-3.02,0.5-4.82,0.5c-2.26,0-4.22-0.34-5.87-1.02
                 c-1.65-0.68-3.01-1.62-4.07-2.82c-1.07-1.2-1.86-2.62-2.37-4.27C144.31,29.59,144.05,27.79,144.05,25.82z M161.89,23.28
                 c0.03-2.1-0.49-3.82-1.57-5.17c-1.08-1.35-2.57-2.02-4.47-2.02c-1.07,0-2.01,0.21-2.82,0.62c-0.82,0.42-1.51,0.96-2.07,1.62
                 c-0.57,0.67-1.01,1.43-1.32,2.3c-0.32,0.87-0.52,1.75-0.62,2.65H161.89z"/>
    <path style="fill:#8AC66B;" d="M17.13,12.79H6.54c0.3,1.19,0.64,2.44,1.01,3.74h8.56C16.49,15.23,16.84,13.97,17.13,12.79z"/>
    <path style="fill:#A6E08C;" d="M16.12,16.53H7.56c0.1,0.35,0.19,0.69,0.3,1.05c0.27,0.9,0.54,1.8,0.83,2.7h6.3
                 c0.29-0.9,0.56-1.8,0.83-2.7C15.93,17.22,16.02,16.88,16.12,16.53z"/>
    <path style="fill:#C5F5B4;" d="M11.84,29.29c0.13-0.34,0.26-0.69,0.39-1.04c0.63-1.69,1.25-3.45,1.86-5.23
                 c0.31-0.91,0.61-1.82,0.9-2.74h-6.3c0.29,0.92,0.59,1.84,0.9,2.74c0.61,1.8,1.23,3.55,1.86,5.23
                 C11.58,28.6,11.71,28.95,11.84,29.29z"/>
  </g>
</svg>
''';

const _svgSsd = '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generator: Adobe Illustrator 23.1.0, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->
<svg version="1.1" id="ICONS_48x48"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 72 72" style="enable-background:new 0 0 72 72;" xml:space="preserve">
  <g>
    <path style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" d="M69,1H3C1.9,1,1,1.9,1,3
		v11.2c0,1.1,0.9,2,2,2h66c1.1,0,2-0.9,2-2V3C71,1.9,70.1,1,69,1z"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="8.6" y1="8.6" x2="14.7" y2="8.6"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="63.4" y1="8.6" x2="64.9" y2="8.6"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="55.8" y1="8.6" x2="57.3" y2="8.6"/>
    <path style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" d="M4,16.2c-1.7,0-3,1.4-3,3
		v9.1c0,1.7,1.4,3,3,3h64c1.7,0,3-1.4,3-3v-9.1c0-1.7-1.4-3-3-3"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="8.6" y1="23.8" x2="14.7" y2="23.8"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="63.4" y1="23.8" x2="64.9" y2="23.8"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="55.8" y1="23.8" x2="57.3" y2="23.8"/>
    <path style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" d="M4,31.4c-1.7,0-3,1.4-3,3
		v9.1c0,1.7,1.4,3,3,3h64c1.7,0,3-1.4,3-3v-9.1c0-1.7-1.4-3-3-3"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="8.6" y1="39" x2="14.7" y2="39"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="63.4" y1="39" x2="64.9" y2="39"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="55.8" y1="39" x2="57.3" y2="39"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="36" y1="46.7" x2="36" y2="58.8"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="1" y1="64.9" x2="29.9" y2="64.9"/>
    <circle style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" cx="36" cy="64.9" r="6.1"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="42.1" y1="64.9" x2="71" y2="64.9"/>
  </g>
</svg>
''';

const _svgOver = '''
<svg version="1.1" id="ICONS_48x48"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 68.8 72" style="enable-background:new 0 0 68.8 72;" xml:space="preserve">
  <g>
    <path style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" d="M16.9,5.8V4.2
                           c0-1.8,1.4-3.2,3.2-3.2h33.4l14.3,14.3v52.5c0,1.8-1.4,3.2-3.2,3.2H20.1c-1.8,0-3.2-1.4-3.2-3.2V50.3"/>
    <path id="Rectangle-Copy-12_1_" style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" d="
                           M53.5,1v11.1c0,1.8,1.4,3.2,3.2,3.2h11.1"/>
    <polygon style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" points="56.7,45.5 
                           51.9,40.7 45.5,47.1 39.2,40.7 34.4,45.5 40.7,51.9 34.4,58.2 39.2,63 45.5,56.7 51.9,63 56.7,58.2 50.3,51.9 	"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="44" y1="24.9" x2="61.5" y2="24.9"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="44" y1="31.2" x2="61.5" y2="31.2"/>

    <circle style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" cx="16.9" cy="28" r="15.9"/>
    <path style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" d="M12.1,34.4h6.4
                           c1.9,0,3.2-1.1,3.2-3.2c0-1.9-1.5-3.2-3.2-3.2c-0.4,0-3.2,0-3.2,0c-1.8,0-3.2-1.1-3.2-3.2c0-1.9,1.2-3.2,3.2-3.2c0.1,0,6.4,0,6.4,0
                           "/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="16.9" y1="21.7" x2="16.9" y2="18.5"/>

    <line style="fill:none;stroke:#6FB158;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;" x1="16.9" y1="37.6" x2="16.9" y2="34.4"/>
  </g>
</svg>
''';

const _svgBang = '''
<svg version="1.1" id="layer_1"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 71.99 72" style="enable-background:new 0 0 71.99 72;" xml:space="preserve">
  <g>
    <circle style="fill:#FFFFFF;" cx="36" cy="22.81" r="21.98"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M36,45.62c-12.58,0-22.81-10.23-22.81-22.81S23.42,0,36,0c12.58,0,22.81,10.23,22.81,22.81
                                S48.58,45.62,36,45.62z M36,1.65c-11.67,0-21.16,9.49-21.16,21.16c0,11.67,9.49,21.16,21.16,21.16c11.67,0,21.16-9.49,21.16-21.16
                                C57.16,11.14,47.67,1.65,36,1.65z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M36,39.62c-9.27,0-16.81-7.54-16.81-16.81C19.19,13.54,26.73,6,36,6c9.27,0,16.81,7.54,16.81,16.81
                                C52.81,32.08,45.27,39.62,36,39.62z M36,7.65c-8.36,0-15.16,6.8-15.16,15.16c0,8.36,6.8,15.17,15.16,15.17
                                c8.36,0,15.16-6.8,15.16-15.17C51.16,14.45,44.36,7.65,36,7.65z"/>
  </g>
  <g>
    <path style="fill:#F76D3C;" d="M46.78,28.89c-0.12,0-0.24-0.03-0.36-0.08c-0.41-0.2-0.58-0.69-0.38-1.1
                                c0.75-1.53,1.12-3.18,1.12-4.89c0-1.71-0.38-3.36-1.12-4.89c-0.2-0.41-0.03-0.9,0.38-1.1c0.41-0.2,0.9-0.03,1.1,0.38
                                c0.86,1.76,1.29,3.64,1.29,5.61c0,1.97-0.43,3.86-1.29,5.61C47.38,28.72,47.09,28.89,46.78,28.89z"/>
  </g>
  <g>
    <path style="fill:#F76D3C;" d="M25.21,28.89c-0.31,0-0.6-0.17-0.74-0.46c-0.86-1.75-1.29-3.64-1.29-5.61s0.43-3.86,1.29-5.61
                                c0.2-0.41,0.69-0.58,1.1-0.38c0.41,0.2,0.58,0.69,0.38,1.1c-0.75,1.53-1.12,3.18-1.12,4.89s0.38,3.36,1.12,4.89
                                c0.2,0.41,0.03,0.9-0.38,1.1C25.46,28.86,25.34,28.89,25.21,28.89z"/>
  </g>
  <g>
    <circle style="fill:#6FB158;" cx="36" cy="41.8" r="0.82"/>
  </g>
  <g>
    <circle style="fill:#6FB158;" cx="36" cy="3.82" r="0.82"/>
  </g>
  <g>
    <circle style="fill:#6FB158;" cx="54.99" cy="22.81" r="0.82"/>
  </g>
  <g>
    <circle style="fill:#6FB158;" cx="17.01" cy="22.81" r="0.82"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M48.84,35.65c0.32-0.32,0.84-0.32,1.17,0c0.32,0.32,0.32,0.84,0,1.17c-0.32,0.32-0.84,0.32-1.17,0
                                C48.52,36.5,48.52,35.98,48.84,35.65z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M21.99,8.8c0.32-0.32,0.84-0.32,1.17,0c0.32,0.32,0.32,0.84,0,1.17c-0.32,0.32-0.84,0.32-1.17,0
                                C21.67,9.64,21.67,9.12,21.99,8.8z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M48.84,9.97c-0.32-0.32-0.32-0.84,0-1.17c0.32-0.32,0.84-0.32,1.17,0c0.32,0.32,0.32,0.84,0,1.17
                                C49.69,10.29,49.17,10.29,48.84,9.97z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M21.99,36.82c-0.32-0.32-0.32-0.84,0-1.17c0.32-0.32,0.84-0.32,1.17,0c0.32,0.32,0.32,0.84,0,1.17
                                C22.83,37.14,22.31,37.14,21.99,36.82z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M52.78,29.76c0.17-0.42,0.66-0.62,1.08-0.45c0.42,0.17,0.62,0.66,0.45,1.08
                                c-0.17,0.42-0.66,0.62-1.08,0.45C52.81,30.66,52.61,30.18,52.78,29.76z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M17.69,15.23c0.17-0.42,0.66-0.62,1.08-0.45c0.42,0.17,0.62,0.66,0.45,1.08
                                c-0.17,0.42-0.66,0.62-1.08,0.45C17.72,16.13,17.52,15.65,17.69,15.23z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M42.95,6.03c-0.42-0.17-0.62-0.66-0.45-1.08c0.17-0.42,0.66-0.62,1.08-0.45
                                C44,4.68,44.2,5.16,44.03,5.58C43.85,6,43.37,6.2,42.95,6.03z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M28.42,41.11c-0.42-0.17-0.62-0.65-0.45-1.08c0.17-0.42,0.66-0.62,1.08-0.45
                                c0.42,0.17,0.62,0.66,0.45,1.08C29.32,41.09,28.84,41.29,28.42,41.11z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M52.78,15.86c-0.17-0.42,0.03-0.9,0.45-1.08c0.42-0.17,0.9,0.03,1.08,0.45
                                c0.17,0.42-0.03,0.9-0.45,1.08C53.44,16.48,52.96,16.28,52.78,15.86z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M17.69,30.39c-0.17-0.42,0.03-0.9,0.45-1.08c0.42-0.17,0.9,0.03,1.08,0.45
                                c0.17,0.42-0.03,0.9-0.45,1.08C18.35,31.01,17.87,30.81,17.69,30.39z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M29.05,6.03C28.63,6.2,28.15,6,27.97,5.58C27.8,5.16,28,4.68,28.42,4.5
                                c0.42-0.17,0.9,0.03,1.08,0.45C29.67,5.37,29.47,5.85,29.05,6.03z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M43.58,41.11c-0.42,0.18-0.9-0.02-1.08-0.44c-0.17-0.42,0.03-0.9,0.45-1.08
                                c0.42-0.17,0.9,0.03,1.08,0.45C44.2,40.46,44,40.94,43.58,41.11z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M36.01,33.13c-2.82,0-5.31-1.38-6.34-3.52c-0.2-0.41-0.03-0.9,0.38-1.1c0.41-0.2,0.9-0.03,1.1,0.39
                                c0.75,1.55,2.69,2.58,4.85,2.58c2.85,0,5.16-1.76,5.16-3.92c0-2.53-1.84-3.92-5.18-3.92c-4.26,0-6.81-2.08-6.81-5.57
                                c0-3.07,3.05-5.57,6.81-5.57c2.82,0,5.31,1.38,6.34,3.52c0.2,0.41,0.03,0.9-0.38,1.1c-0.41,0.2-0.9,0.03-1.1-0.38
                                c-0.75-1.55-2.69-2.59-4.85-2.59c-2.85,0-5.16,1.76-5.16,3.92c0,2.53,1.83,3.92,5.16,3.92c5.04,0,6.83,2.88,6.83,5.57
                                C42.82,30.63,39.77,33.13,36.01,33.13z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M35.99,36.12c-0.46,0-0.82-0.37-0.82-0.82V10.32c0-0.46,0.37-0.82,0.82-0.82
                                c0.46,0,0.82,0.37,0.82,0.82V35.3C36.82,35.76,36.45,36.12,35.99,36.12z"/>
  </g>
  <g>
    <path style="fill:#FFFFFF;" d="M65.99,22.25L65.99,22.25c1.19,0.77,1.88,2.11,1.81,3.53L66.95,41.5l-7.23-1.06l0.58-5.21
                                c1.27-5.95,0.67-10.08,1.55-12.12C62.65,21.23,64.61,21.19,65.99,22.25z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M66.95,42.32c-0.04,0-0.08,0-0.12-0.01l-7.23-1.06c-0.44-0.06-0.75-0.47-0.7-0.91l0.58-5.21
                                c0.66-3.14,0.81-5.71,0.93-7.78c0.11-1.94,0.2-3.48,0.68-4.58c0.43-1.01,1.2-1.7,2.16-1.95c1.04-0.27,2.24,0.01,3.22,0.74
                                c1.42,0.93,2.25,2.55,2.16,4.25l-0.85,15.73c-0.01,0.23-0.12,0.45-0.3,0.59C67.32,42.26,67.14,42.32,66.95,42.32z M60.62,39.74
                                l5.55,0.82l0.8-14.82c0.06-1.12-0.49-2.19-1.43-2.79c-0.02-0.01-0.04-0.03-0.06-0.04c-0.58-0.45-1.27-0.62-1.83-0.48
                                c-0.47,0.12-0.82,0.46-1.06,1.01c-0.36,0.84-0.44,2.24-0.55,4.03c-0.12,2.12-0.28,4.76-0.95,7.94L60.62,39.74z"/>
  </g>
  <g>
    <path style="fill:#FFFFFF;" d="M66.89,20.09c-1.92,0.95,0.06,6.82-2.73,18.58c0.1-1.67-0.47-2.53-1.25-2.94
                                c-3.48-1.84-4.71,1.34-4.71,1.34c-6.94,16.06-5.31,2.22-15.1,23.9l14.01,6.25c0,0,18.8-20.3,12.93-44.64
                                C70.04,22.57,69.4,18.85,66.89,20.09z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M57.11,68.04c-0.11,0-0.23-0.02-0.34-0.07l-14.01-6.25c-0.2-0.09-0.36-0.25-0.43-0.46
                                c-0.08-0.2-0.07-0.43,0.02-0.63c5.33-11.79,7.4-13.3,9.23-14.64c1.46-1.06,2.73-1.98,5.86-9.25c0.01-0.03,0.63-1.6,2.21-2.19
                                c1.09-0.41,2.31-0.26,3.64,0.45c0.23,0.12,0.47,0.28,0.69,0.5c0.87-4.68,0.98-8.25,1.05-10.76c0.09-3.05,0.14-4.72,1.48-5.39l0,0
                                c1.07-0.53,1.89-0.34,2.39-0.08c1.49,0.76,1.9,2.92,1.94,3.16c5.89,24.43-12.95,45.13-13.14,45.34
                                C57.55,67.94,57.33,68.04,57.11,68.04z M44.2,60.55l12.69,5.66c2.63-3.07,17.57-21.77,12.35-43.45c-0.1-0.57-0.48-1.73-1.08-2.03
                                c-0.09-0.05-0.36-0.18-0.91,0.09l0,0c-0.45,0.23-0.51,2.04-0.56,3.96c-0.09,3.08-0.23,7.74-1.73,14.07
                                c-0.1,0.42-0.5,0.68-0.92,0.63c-0.42-0.06-0.73-0.44-0.7-0.86c0.1-1.69-0.59-2.05-0.81-2.17c-0.89-0.47-1.66-0.6-2.28-0.37
                                c-0.88,0.32-1.27,1.27-1.27,1.28c-3.33,7.71-4.76,8.75-6.42,9.96C50.93,48.51,49.08,49.85,44.2,60.55z M66.89,20.09h0.01H66.89z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M58.95,51.51c-0.15,0-0.29-0.04-0.43-0.12c-0.39-0.24-0.51-0.74-0.27-1.13
                                c4.05-6.63,4.99-10.06,5.08-11.78c0.02-0.46,0.42-0.82,0.86-0.78c0.46,0.02,0.81,0.41,0.78,0.86c-0.13,2.77-1.92,6.99-5.32,12.56
                                C59.5,51.37,59.23,51.51,58.95,51.51z"/>
  </g>
  <g>
    <path style="fill:#FFFFFF;" d="M6.01,22.14L6.01,22.14c-1.19,0.77-1.88,2.11-1.81,3.53l0.85,15.73l7.23-1.06l-0.58-5.21
                                c-1.27-5.95-0.67-10.08-1.55-12.12C9.34,21.12,7.38,21.09,6.01,22.14z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M5.05,42.32c-0.19,0-0.37-0.06-0.52-0.18c-0.18-0.15-0.29-0.36-0.3-0.59L3.38,25.82
                                c-0.09-1.7,0.73-3.32,2.16-4.25c0.98-0.73,2.18-1.01,3.22-0.74c0.96,0.25,1.72,0.94,2.16,1.95c0.48,1.1,0.57,2.64,0.68,4.58
                                c0.12,2.07,0.27,4.64,0.92,7.69l0.59,5.29c0.05,0.44-0.26,0.84-0.7,0.91l-7.23,1.06C5.13,42.32,5.09,42.32,5.05,42.32z M7.93,22.38
                                c-0.47,0-0.97,0.18-1.42,0.53c-0.02,0.01-0.04,0.03-0.06,0.04c-0.94,0.6-1.49,1.67-1.43,2.79l0.8,14.82l5.55-0.82l-0.49-4.42
                                c-0.66-3.1-0.82-5.74-0.94-7.86c-0.1-1.78-0.19-3.19-0.55-4.03c-0.24-0.55-0.59-0.88-1.06-1.01C8.21,22.39,8.07,22.38,7.93,22.38z
                                M6.01,22.25h0.01H6.01z"/>
  </g>
  <g>
    <path style="fill:#FFFFFF;" d="M5.11,20.09c1.92,0.95-0.06,6.82,2.73,18.58c-0.1-1.67,0.47-2.53,1.25-2.94
                                c3.48-1.84,4.71,1.34,4.71,1.34c6.94,16.06,5.31,2.22,15.1,23.9l-14.01,6.25c0,0-18.8-20.3-12.93-44.64
                                C1.96,22.57,2.6,18.85,5.11,20.09z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M14.89,68.04c-0.22,0-0.45-0.09-0.6-0.26C14.09,67.57-4.74,46.86,1.16,22.38
                                c0.03-0.19,0.44-2.35,1.93-3.11c0.5-0.25,1.32-0.45,2.39,0.08c1.35,0.66,1.39,2.34,1.48,5.39c0.07,2.51,0.18,6.08,1.05,10.76
                                c0.22-0.22,0.46-0.38,0.69-0.5c1.33-0.7,2.56-0.86,3.64-0.45c1.58,0.59,2.19,2.16,2.22,2.22c3.13,7.24,4.39,8.15,5.85,9.22
                                c1.83,1.33,3.91,2.84,9.23,14.64c0.09,0.2,0.1,0.43,0.02,0.63c-0.08,0.21-0.23,0.37-0.43,0.46l-14.01,6.25
                                C15.12,68.01,15,68.04,14.89,68.04z M4.15,20.66c-0.14,0-0.24,0.04-0.32,0.08c-0.6,0.3-0.97,1.46-1.06,1.98
                                c-5.24,21.74,9.71,40.42,12.34,43.5l12.69-5.66c-4.89-10.7-6.73-12.04-8.36-13.23c-1.66-1.21-3.09-2.25-6.41-9.93
                                c-0.01-0.04-0.4-0.99-1.28-1.31c-0.62-0.23-1.39-0.1-2.28,0.37c-0.22,0.12-0.91,0.48-0.81,2.17c0.02,0.43-0.28,0.8-0.7,0.86
                                c-0.43,0.05-0.82-0.21-0.92-0.63c-1.5-6.33-1.64-10.99-1.73-14.07c-0.06-1.92-0.11-3.73-0.56-3.96l0,0
                                C4.49,20.71,4.3,20.66,4.15,20.66z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M13.05,51.51c-0.28,0-0.55-0.14-0.7-0.4c-3.39-5.56-5.18-9.79-5.32-12.56
                                c-0.02-0.46,0.33-0.84,0.78-0.86c0.45-0.04,0.84,0.33,0.86,0.78c0.08,1.71,1.03,5.15,5.08,11.78c0.24,0.39,0.11,0.9-0.27,1.13
                                C13.34,51.48,13.19,51.51,13.05,51.51z"/>
  </g>
  <g>
    <path style="fill:#F76D3C;" d="M61.7,10.44h-1.52c-0.46,0-0.82-0.37-0.82-0.82c0-0.46,0.37-0.82,0.82-0.82h1.52
                                c0.46,0,0.82,0.37,0.82,0.82C62.53,10.08,62.16,10.44,61.7,10.44z"/>
  </g>
  <g>
    <path style="fill:#F76D3C;" d="M66.78,10.44h-1.52c-0.46,0-0.82-0.37-0.82-0.82c0-0.46,0.37-0.82,0.82-0.82h1.52
                                c0.46,0,0.82,0.37,0.82,0.82C67.6,10.08,67.23,10.44,66.78,10.44z"/>
  </g>
  <g>
    <path style="fill:#F76D3C;" d="M63.48,13.74c-0.46,0-0.82-0.37-0.82-0.82V11.4c0-0.46,0.37-0.82,0.82-0.82
                                c0.46,0,0.82,0.37,0.82,0.82v1.52C64.3,13.37,63.94,13.74,63.48,13.74z"/>
  </g>
  <g>
    <path style="fill:#F76D3C;" d="M63.48,8.67c-0.46,0-0.82-0.37-0.82-0.82V6.32c0-0.46,0.37-0.82,0.82-0.82
                                c0.46,0,0.82,0.37,0.82,0.82v1.52C64.3,8.3,63.94,8.67,63.48,8.67z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M12.24,4.95h-1.52c-0.46,0-0.82-0.37-0.82-0.82c0-0.46,0.37-0.82,0.82-0.82h1.52
                                c0.46,0,0.82,0.37,0.82,0.82C13.06,4.58,12.7,4.95,12.24,4.95z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M17.31,4.95h-1.52c-0.46,0-0.82-0.37-0.82-0.82c0-0.46,0.37-0.82,0.82-0.82h1.52
                                c0.46,0,0.82,0.37,0.82,0.82C18.14,4.58,17.77,4.95,17.31,4.95z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M14.02,8.24c-0.46,0-0.82-0.37-0.82-0.82V5.9c0-0.46,0.37-0.82,0.82-0.82
                                c0.46,0,0.82,0.37,0.82,0.82v1.52C14.84,7.88,14.47,8.24,14.02,8.24z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M14.02,3.17c-0.46,0-0.82-0.37-0.82-0.82V0.82c0-0.46,0.37-0.82,0.82-0.82
                                c0.46,0,0.82,0.37,0.82,0.82v1.52C14.84,2.8,14.47,3.17,14.02,3.17z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M2.35,12.64H0.82C0.37,12.64,0,12.27,0,11.82c0-0.46,0.37-0.82,0.82-0.82h1.52
                                c0.46,0,0.82,0.37,0.82,0.82C3.17,12.27,2.8,12.64,2.35,12.64z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M7.42,12.64H5.9c-0.46,0-0.82-0.37-0.82-0.82c0-0.46,0.37-0.82,0.82-0.82h1.52
                                c0.46,0,0.82,0.37,0.82,0.82C8.24,12.27,7.87,12.64,7.42,12.64z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M4.12,15.94c-0.46,0-0.82-0.37-0.82-0.82v-1.52c0-0.46,0.37-0.82,0.82-0.82
                                c0.46,0,0.82,0.37,0.82,0.82v1.52C4.95,15.57,4.58,15.94,4.12,15.94z"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M4.12,10.87c-0.46,0-0.82-0.37-0.82-0.82V8.52c0-0.46,0.37-0.82,0.82-0.82
                                c0.46,0,0.82,0.37,0.82,0.82v1.52C4.95,10.5,4.58,10.87,4.12,10.87z"/>
  </g>
  <g>
    <polygon style="fill:#FFFFFF;" points="42.75,57.61 40.92,71.18 60.4,71.18 62.21,63.28 	"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M60.4,72H40.92c-0.24,0-0.46-0.1-0.62-0.28c-0.16-0.18-0.23-0.42-0.2-0.65l1.84-13.57
                                c0.03-0.24,0.17-0.45,0.37-0.58c0.2-0.13,0.45-0.17,0.68-0.1l19.46,5.67c0.42,0.12,0.67,0.55,0.57,0.97l-1.81,7.9
                                C61.12,71.73,60.79,72,60.4,72z M41.86,70.35h17.89l1.49-6.5l-17.79-5.18L41.86,70.35z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M56.21,66.04c0.58,0.18,0.9,0.81,0.71,1.38c-0.19,0.58-0.81,0.9-1.38,0.71
                                c-0.58-0.18-0.9-0.81-0.71-1.38C55.01,66.18,55.63,65.86,56.21,66.04z"/>
  </g>
  <g>
    <polygon style="fill:#FFFFFF;" points="29.25,57.61 31.08,71.18 11.6,71.18 9.79,63.28 	"/>
  </g>
  <g>
    <path style="fill:#343733;" d="M31.08,72H11.6c-0.38,0-0.72-0.27-0.8-0.64l-1.81-7.9c-0.1-0.43,0.15-0.85,0.57-0.97l19.46-5.67
                                c0.23-0.07,0.48-0.03,0.68,0.1c0.2,0.13,0.34,0.34,0.37,0.58l1.84,13.57c0.03,0.24-0.04,0.47-0.2,0.65
                                C31.55,71.9,31.32,72,31.08,72z M12.25,70.35h17.89l-1.58-11.68l-17.79,5.18L12.25,70.35z"/>
  </g>
  <g>
    <path style="fill:#6FB158;" d="M25.69,66.04c-0.58,0.18-0.9,0.81-0.71,1.38c0.19,0.58,0.81,0.9,1.38,0.71
                                c0.58-0.18,0.9-0.81,0.71-1.38C26.89,66.18,26.27,65.86,25.69,66.04z"/>
  </g>
</svg>
''';

const _svgNet = '''
<svg id="Ñëîé_1" style="enable-background:new 0 0 36 39.73;" version="1.1" viewbox="0 0 36 39.73" x="0px" xml:space="preserve"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink" y="0px">
  <style type="text/css">
                                    .st0{fill:#6FB158;}
  </style>
  <path class="st0" d="M31.63,25.57c2.41,0,4.37-1.96,4.37-4.37c0-1.11-0.42-2.12-1.1-2.89c0.48-1.07,0.73-2.24,0.73-3.42
                                    c0-4.62-3.76-8.38-8.38-8.38c-0.58,0-1.16,0.06-1.72,0.18C23.72,2.67,19.64,0,15.18,0C8.92,0,3.82,5.1,3.82,11.36
                                    c0,0.35,0.02,0.69,0.05,1.03C1.5,13.55,0,15.94,0,18.62c0,3.83,3.12,6.95,6.95,6.95c0,0,0.01,0,0.01,0h6.81v1.32
                                    c0,0.6-0.23,1.15-0.65,1.57l-0.59,0.59c-0.53-0.34-1.16-0.54-1.84-0.54c-1.91,0-3.46,1.55-3.46,3.46c0,1.91,1.55,3.46,3.46,3.46
                                    c1.91,0,3.46-1.55,3.46-3.46c0-0.68-0.2-1.31-0.54-1.84l0.59-0.59c0.71-0.71,1.1-1.65,1.1-2.65v-1.32h2.17v2.5
                                    c0,0.4,0.15,0.81,0.42,1.18c0.24,0.33,0.59,0.58,1.06,0.79c0.04,0.02,0.11,0.15,0.11,0.45v2.42c-1.54,0.35-2.69,1.73-2.69,3.37
                                    c0,1.91,1.55,3.46,3.46,3.46c1.91,0,3.46-1.55,3.46-3.46c0-1.64-1.15-3.02-2.69-3.37v-2.42c0-1.28-0.73-1.72-1.04-1.86
                                    c-0.21-0.09-0.35-0.18-0.43-0.28c-0.1-0.13-0.12-0.24-0.12-0.28v-2.5h2.76v2.52c0,1.29,1.04,2.33,2.36,2.33
                                    c0.21,0,0.42,0.08,0.57,0.24l1.09,1.09c-0.34,0.53-0.54,1.16-0.54,1.84c0,1.91,1.55,3.46,3.46,3.46c1.91,0,3.46-1.55,3.46-3.46
                                    c0-1.91-1.55-3.46-3.46-3.46c-0.68,0-1.31,0.2-1.84,0.54l-1.09-1.09c-0.44-0.44-1.03-0.68-1.68-0.68c-0.44,0-0.8-0.36-0.8-0.81
                                    v-2.52H31.63z M10.68,33.91c-1.06,0-1.93-0.87-1.93-1.93s0.87-1.93,1.93-1.93c1.06,0,1.93,0.87,1.93,1.93S11.75,33.91,10.68,33.91z
                                     M21.75,36.28c0,1.06-0.87,1.93-1.93,1.93c-1.06,0-1.93-0.87-1.93-1.93c0-1.06,0.87-1.93,1.93-1.93
                                    C20.88,34.35,21.75,35.21,21.75,36.28z M30.61,33.58c0,1.06-0.87,1.93-1.93,1.93c-1.06,0-1.93-0.87-1.93-1.93s0.87-1.93,1.93-1.93
                                    C29.75,31.65,30.61,32.52,30.61,33.58z M1.53,18.62c0-2.21,1.38-4.24,3.44-5.05c0.63-0.25,1.3-0.37,1.98-0.37
                                    c2.99,0,5.43,2.43,5.43,5.43c0,0.92-0.22,1.79-0.66,2.6c-0.2,0.37-0.07,0.83,0.3,1.04c0.37,0.2,0.83,0.07,1.04-0.3
                                    c0.55-1.02,0.85-2.17,0.85-3.33c0-3.83-3.12-6.95-6.95-6.95c-0.54,0-1.07,0.07-1.58,0.19c-0.01-0.16-0.02-0.33-0.02-0.5
                                    c0-5.42,4.41-9.83,9.83-9.83c4.06,0,7.76,2.55,9.19,6.35c0.43,1.11,0.64,2.29,0.64,3.49c0,3.15-1.45,6.03-3.98,7.9
                                    c-0.34,0.25-0.41,0.73-0.16,1.07c0.15,0.2,0.38,0.31,0.61,0.31c0.16,0,0.32-0.05,0.45-0.15c2.88-2.14,4.6-5.55,4.6-9.13
                                    c0-1.1-0.16-2.17-0.47-3.21c0.39-0.07,0.78-0.11,1.18-0.11c3.78,0,6.85,3.07,6.85,6.85c0,0.85-0.15,1.66-0.45,2.44
                                    c-0.61-0.32-1.29-0.5-2.03-0.5c-0.42,0-0.76,0.34-0.76,0.76s0.34,0.76,0.76,0.76c1.57,0,2.84,1.27,2.84,2.84
                                    c0,1.57-1.27,2.84-2.84,2.84H6.95c0,0,0,0-0.01,0C3.96,24.04,1.53,21.61,1.53,18.62z"></path>
</svg>
''';

const _svgCpu1 = '''
<svg id="Ñëîé_1" style="enable-background:new 0 0 36 36;" version="1.1" viewbox="0 0 36 36" x="0px" xml:space="preserve"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink" y="0px">
  <style type="text/css">
                                .st0{fill:#6FB158;}
  </style>
  <path class="st0" d="M35.14,13.89c0.48,0,0.86-0.39,0.86-0.86c0-0.48-0.39-0.86-0.86-0.86h-3.11V8.92h3.11
                                c0.48,0,0.86-0.39,0.86-0.86c0-0.48-0.39-0.86-0.86-0.86h-3.11V4.83c0-0.48-0.39-0.86-0.86-0.86h-2.36V0.86
                                c0-0.48-0.39-0.86-0.86-0.86c-0.48,0-0.86,0.39-0.86,0.86v3.11h-3.25V0.86c0-0.48-0.39-0.86-0.86-0.86c-0.48,0-0.86,0.39-0.86,0.86
                                v3.11h-3.25V0.86C18.86,0.39,18.48,0,18,0c-0.48,0-0.86,0.39-0.86,0.86v3.11h-3.25V0.86C13.89,0.39,13.5,0,13.03,0
                                c-0.48,0-0.86,0.39-0.86,0.86v3.11H8.92V0.86C8.92,0.39,8.53,0,8.05,0C7.58,0,7.19,0.39,7.19,0.86v3.11H4.83
                                c-0.48,0-0.86,0.39-0.86,0.86v2.36H0.86C0.39,7.19,0,7.58,0,8.05c0,0.48,0.39,0.86,0.86,0.86h3.11v3.25H0.86
                                C0.39,12.17,0,12.55,0,13.03c0,0.48,0.39,0.86,0.86,0.86h3.11v3.25H0.86C0.39,17.14,0,17.52,0,18s0.39,0.86,0.86,0.86h3.11v3.25
                                H0.86C0.39,22.11,0,22.5,0,22.97s0.39,0.86,0.86,0.86h3.11v3.25H0.86C0.39,27.08,0,27.47,0,27.95c0,0.48,0.39,0.86,0.86,0.86h3.11
                                v2.36c0,0.48,0.39,0.86,0.86,0.86h2.36v3.11c0,0.48,0.39,0.86,0.86,0.86c0.48,0,0.86-0.39,0.86-0.86v-3.11h3.25v3.11
                                c0,0.48,0.39,0.86,0.86,0.86c0.48,0,0.86-0.39,0.86-0.86v-3.11h3.25v3.11c0,0.48,0.39,0.86,0.86,0.86c0.48,0,0.86-0.39,0.86-0.86
                                v-3.11h3.25v3.11c0,0.48,0.39,0.86,0.86,0.86c0.48,0,0.86-0.39,0.86-0.86v-3.11h3.25v3.11c0,0.48,0.39,0.86,0.86,0.86
                                c0.48,0,0.86-0.39,0.86-0.86v-3.11h2.36c0.48,0,0.86-0.39,0.86-0.86v-2.36h3.11c0.48,0,0.86-0.39,0.86-0.86
                                c0-0.48-0.39-0.86-0.86-0.86h-3.11v-3.25h3.11c0.48,0,0.86-0.39,0.86-0.86s-0.39-0.86-0.86-0.86h-3.11v-3.25h3.11
                                c0.48,0,0.86-0.39,0.86-0.86s-0.39-0.86-0.86-0.86h-3.11v-3.25H35.14z M30.31,30.31H5.69V5.69h24.61V30.31z"></path>
</svg>
''';

const _jsonPricing = '''
[{"group_name":"Linux VPS","group_link":"https://vpsdime.com/linux-vps","products":[{"product_name":"Linux4GB","order_link":"https://vpsdime.com/buy/linux4gb","specs":{"vcpu":2,"memory_gb":4,"storage_gb":20,"uplink_gbps":10,"traffic_tb":1},"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Linux6GB","order_link":"https://vpsdime.com/buy/linux6gb","specs":{"vcpu":4,"memory_gb":6,"storage_gb":30,"uplink_gbps":10,"traffic_tb":2},"pricing_usd":{"monthly":7,"quarterly":21,"semiannually":42,"annually":84},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Linux12GB","order_link":"https://vpsdime.com/buy/linux12gb","specs":{"vcpu":4,"memory_gb":12,"storage_gb":60,"uplink_gbps":10,"traffic_tb":4},"pricing_usd":{"monthly":14,"quarterly":42,"semiannually":84,"annually":168},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Linux18GB","order_link":"https://vpsdime.com/buy/linux18gb","specs":{"vcpu":4,"memory_gb":18,"storage_gb":90,"uplink_gbps":10,"traffic_tb":6},"pricing_usd":{"monthly":21,"quarterly":63,"semiannually":126,"annually":252},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Linux24GB","order_link":"https://vpsdime.com/buy/linux24gb","specs":{"vcpu":4,"memory_gb":24,"storage_gb":120,"uplink_gbps":10,"traffic_tb":8},"pricing_usd":{"monthly":28,"quarterly":84,"semiannually":168,"annually":336},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Linux30GB","order_link":"https://vpsdime.com/buy/linux30gb","specs":{"vcpu":4,"memory_gb":30,"storage_gb":150,"uplink_gbps":10,"traffic_tb":10},"pricing_usd":{"monthly":35,"quarterly":105,"semiannually":210,"annually":420},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Linux36GB","order_link":"https://vpsdime.com/buy/linux36gb","specs":{"vcpu":4,"memory_gb":36,"storage_gb":180,"uplink_gbps":10,"traffic_tb":12},"pricing_usd":{"monthly":42,"quarterly":126,"semiannually":252,"annually":504},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Linux72GB","order_link":"https://vpsdime.com/buy/linux72gb","specs":{"vcpu":4,"memory_gb":72,"storage_gb":360,"uplink_gbps":10,"traffic_tb":24},"pricing_usd":{"monthly":84,"quarterly":252,"semiannually":504,"annually":1008},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Linux108GB","order_link":"https://vpsdime.com/buy/linux108gb","specs":{"vcpu":4,"memory_gb":108,"storage_gb":540,"uplink_gbps":10,"traffic_tb":36},"pricing_usd":{"monthly":126,"quarterly":378,"semiannually":756,"annually":1512},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Linux144GB","order_link":"https://vpsdime.com/buy/linux144gb","specs":{"vcpu":4,"memory_gb":144,"storage_gb":720,"uplink_gbps":10,"traffic_tb":48},"pricing_usd":{"monthly":168,"quarterly":504,"semiannually":1008,"annually":2016},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Linux288GB","order_link":"https://vpsdime.com/buy/linux288gb","specs":{"vcpu":4,"memory_gb":288,"storage_gb":1440,"uplink_gbps":10,"traffic_tb":96},"pricing_usd":{"monthly":336,"quarterly":1008,"semiannually":2016,"annually":4032},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL","London, UK"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 24.04","Ubuntu 26.04","Ubuntu 22.04","Ubuntu 25.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux","CentOS 10 Stream","CentOS 9 Stream","Fedora 43","Fedora 42","OpenSUSE 16","Devuan Excalibur","Slackware","Alpine 3.23","Alpine Edge","VoidLinux","Oracle Linux 9"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional vCPU","type":"quantity","unit":"1 vCPU","qty_max":12,"pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Additional Storage","type":"quantity","unit":"10GB","qty_max":10,"pricing_usd":{"monthly":2.5,"quarterly":7.5,"semiannually":15,"annually":30}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]}]},{"group_name":"Premium VPS","group_link":"https://vpsdime.com/premium-vps","products":[{"product_name":"Premium4GB","order_link":"https://vpsdime.com/buy/premium4gb","specs":{"vcpu":1,"memory_gb":4,"storage_gb":60,"uplink_gbps":10,"traffic_tb":2},"pricing_usd":{"monthly":20,"quarterly":60,"semiannually":120,"annually":240},"options":[{"name":"Location","type":"dropdown","choices":["Los Angeles, US","Dallas, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 25.04","Ubuntu 24.04","Ubuntu 22.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux"]},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Premium8GB","order_link":"https://vpsdime.com/buy/premium8gb","specs":{"vcpu":2,"memory_gb":8,"storage_gb":120,"uplink_gbps":10,"traffic_tb":4},"pricing_usd":{"monthly":40,"quarterly":120,"semiannually":240,"annually":480},"options":[{"name":"Location","type":"dropdown","choices":["Los Angeles, US","Dallas, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 25.04","Ubuntu 24.04","Ubuntu 22.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux"]},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Premium12GB","order_link":"https://vpsdime.com/buy/premium12gb","specs":{"vcpu":3,"memory_gb":12,"storage_gb":180,"uplink_gbps":10,"traffic_tb":6},"pricing_usd":{"monthly":60,"quarterly":180,"semiannually":360,"annually":720},"options":[{"name":"Location","type":"dropdown","choices":["Los Angeles, US","Dallas, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 25.04","Ubuntu 24.04","Ubuntu 22.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux"]},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Premium16GB","order_link":"https://vpsdime.com/buy/premium16gb","specs":{"vcpu":4,"memory_gb":16,"storage_gb":240,"uplink_gbps":10,"traffic_tb":8},"pricing_usd":{"monthly":80,"quarterly":240,"semiannually":480,"annually":960},"options":[{"name":"Location","type":"dropdown","choices":["Los Angeles, US","Dallas, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 25.04","Ubuntu 24.04","Ubuntu 22.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux"]},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Premium24GB","order_link":"https://vpsdime.com/buy/premium24gb","specs":{"vcpu":6,"memory_gb":24,"storage_gb":360,"uplink_gbps":10,"traffic_tb":12},"pricing_usd":{"monthly":120,"quarterly":360,"semiannually":720,"annually":1440},"options":[{"name":"Location","type":"dropdown","choices":["Los Angeles, US","Dallas, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 25.04","Ubuntu 24.04","Ubuntu 22.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux"]},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Premium32GB","order_link":"https://vpsdime.com/buy/premium32gb","specs":{"vcpu":8,"memory_gb":32,"storage_gb":480,"uplink_gbps":10,"traffic_tb":16},"pricing_usd":{"monthly":160,"quarterly":480,"semiannually":960,"annually":1920},"options":[{"name":"Location","type":"dropdown","choices":["Los Angeles, US","Dallas, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 25.04","Ubuntu 24.04","Ubuntu 22.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux"]},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]},{"product_name":"Premium64GB","order_link":"https://vpsdime.com/buy/premium64gb","specs":{"vcpu":16,"memory_gb":64,"storage_gb":960,"uplink_gbps":10,"traffic_tb":32},"pricing_usd":{"monthly":360,"quarterly":960,"semiannually":1920,"annually":3840},"options":[{"name":"Location","type":"dropdown","choices":["Los Angeles, US","Dallas, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Ubuntu 25.04","Ubuntu 24.04","Ubuntu 22.04","Debian 13","Debian 12","AlmaLinux 10","AlmaLinux 9","Rocky Linux 10","Rocky Linux 9","Arch Linux"]},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}},{"name":"Extra IP Address","type":"quantity","qty_max":4,"pricing_usd":{"monthly":2,"quarterly":6,"semiannually":12,"annually":24}}]}]},{"group_name":"Windows VPS","group_link":"https://vpsdime.com/windows-vps","products":[{"product_name":"WIN6GB","order_link":"https://vpsdime.com/buy/win6gb","specs":{"vcpu":2,"memory_gb":6,"storage_gb":50,"uplink_gbps":10,"traffic_tb":4},"pricing_usd":{"monthly":15,"quarterly":45,"semiannually":90,"annually":180},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Windows Server 2025","Windows Server 2022","Windows Server 2019"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}}]},{"product_name":"WIN8GB","order_link":"https://vpsdime.com/buy/win8gb","specs":{"vcpu":4,"memory_gb":8,"storage_gb":100,"uplink_gbps":10,"traffic_tb":8},"pricing_usd":{"monthly":20,"quarterly":60,"semiannually":120,"annually":240},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Windows Server 2025","Windows Server 2022","Windows Server 2019"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}}]},{"product_name":"WIN12GB","order_link":"https://vpsdime.com/buy/win12gb","specs":{"vcpu":5,"memory_gb":12,"storage_gb":150,"uplink_gbps":10,"traffic_tb":12},"pricing_usd":{"monthly":30,"quarterly":90,"semiannually":180,"annually":360},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Windows Server 2025","Windows Server 2022","Windows Server 2019"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}}]},{"product_name":"WIN16GB","order_link":"https://vpsdime.com/buy/win16gb","specs":{"vcpu":6,"memory_gb":16,"storage_gb":200,"uplink_gbps":10,"traffic_tb":16},"pricing_usd":{"monthly":40,"quarterly":120,"semiannually":240,"annually":480},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Windows Server 2025","Windows Server 2022","Windows Server 2019"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}}]},{"product_name":"WIN32GB","order_link":"https://vpsdime.com/buy/win32gb","specs":{"vcpu":8,"memory_gb":32,"storage_gb":400,"uplink_gbps":10,"traffic_tb":32},"pricing_usd":{"monthly":80,"quarterly":240,"semiannually":480,"annually":960},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Windows Server 2025","Windows Server 2022","Windows Server 2019"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}}]},{"product_name":"WIN64GB","order_link":"https://vpsdime.com/buy/win64gb","specs":{"vcpu":12,"memory_gb":64,"storage_gb":800,"uplink_gbps":10,"traffic_tb":64},"pricing_usd":{"monthly":160,"quarterly":480,"semiannually":960,"annually":1920},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Windows Server 2025","Windows Server 2022","Windows Server 2019"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}}]},{"product_name":"WIN128GB","order_link":"https://vpsdime.com/buy/win128gb","specs":{"vcpu":16,"memory_gb":128,"storage_gb":1600,"uplink_gbps":10,"traffic_tb":128},"pricing_usd":{"monthly":320,"quarterly":960,"semiannually":1920,"annually":3840},"options":[{"name":"Location","type":"dropdown","choices":["Dallas, US","Los Angeles, US","Amsterdam, NL"]},{"name":"Operating System","type":"dropdown","choices":["Windows Server 2025","Windows Server 2022","Windows Server 2019"]},{"name":"Nightly Backups","type":"checkbox","pricing_usd":{"monthly":5,"quarterly":15,"semiannually":30,"annually":60}},{"name":"Extra Bandwidth","type":"quantity","unit":"1TB","qty_max":10,"pricing_usd":{"monthly":4,"quarterly":12,"semiannually":24,"annually":48}}]}]}]
''';
