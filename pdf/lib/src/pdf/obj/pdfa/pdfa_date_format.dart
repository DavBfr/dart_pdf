class PdfaDateFormat {
  String format({
    required DateTime dt,
    bool asIso = false,
  }) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');

    if (asIso) {
      // "yyyy-MM-dd'T'HH:mm:ss"
      return '$year-$month-${day}T$hour:$minute:$second';
    }
    // "yyyyMMddHHmmss"
    return '$year$month$day$hour$minute$second';
  }
}
