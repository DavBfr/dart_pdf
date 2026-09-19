/// Whether to use the Bidi algorithm to detect RTL text.
const bool useBidi = bool.fromEnvironment('use_bidi', defaultValue: true);

/// Whether to use the Arabic algorithm.
const bool useArabic = bool.fromEnvironment(
  'use_arabic',
  defaultValue: !useBidi,
);

/// Whether to use complex script shaping with OpenType GSUB.
/// Supports Indic scripts (Devanagari, Bengali, Tamil, Telugu, Kannada,
/// Malayalam, Gujarati, Gurmukhi, Oriya) and other complex scripts
/// (Thai, Khmer, Myanmar, Tibetan, Sinhala, Lao).
const bool useComplexScripts = bool.fromEnvironment(
  'use_complex_scripts',
  defaultValue: true,
);
