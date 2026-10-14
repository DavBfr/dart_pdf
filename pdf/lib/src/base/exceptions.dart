/// A base exception for all PDF related exceptions.
class PdfException implements Exception {
  const PdfException([this.message]);

  final String? message;

  @override
  String toString() =>
      message == null ? runtimeType.toString() : '$runtimeType: $message';
}

/// Exception thrown when generator populates more pages than `maxPages` of [MultiPage].
class PdfTooBigPageException extends PdfException {
  const PdfTooBigPageException([super.message]);
}
