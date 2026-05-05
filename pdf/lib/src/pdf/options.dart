/// Whether to use the Bidi algorithm to detect RTL text.
const bool useBidi = bool.fromEnvironment('use_bidi', defaultValue: true);

/// Whether to use the Arabic algorithm.
const bool useArabic = bool.fromEnvironment(
  'use_arabic',
  defaultValue: !useBidi,
);

/// Whether to use Malayalam shaping with OpenType GSUB.
const bool useMalayalam = bool.fromEnvironment(
  'use_malayalam',
  defaultValue: true,
);
