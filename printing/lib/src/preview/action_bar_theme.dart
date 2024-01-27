import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PdfActionBarTheme with Diagnosticable {
  /// Creates a theme for action bar of [PdfPreviewController].
  const PdfActionBarTheme({
    this.backgroundColor,
    this.iconColor,
    this.height,
    this.textStyle,
    this.elevation = 4.0,
    this.actionSpacing = 0.0,
    this.alignment = WrapAlignment.spaceAround,
    this.runAlignment = WrapAlignment.center,
    this.crossAxisAlignment = WrapCrossAlignment.center,
  });

  final Color? backgroundColor;
  final Color? iconColor;
  final double? height;
  final TextStyle? textStyle;
  final double elevation;
  final double actionSpacing;
  final WrapAlignment alignment;
  final WrapAlignment runAlignment;
  final WrapCrossAlignment crossAxisAlignment;

  /// Creates a copy of this object but with the given fields replaced with the
  /// new values.
  PdfActionBarTheme copyWith({
    Color? backgroundColor,
    Color? iconColor,
    double? height,
    TextStyle? textStyle,
    double? elevation,
    double? actionSpacing,
    WrapAlignment? alignment,
    WrapAlignment? runAlignment,
    WrapCrossAlignment? crossAxisAlignment,
  }) {
    return PdfActionBarTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      iconColor: iconColor ?? this.iconColor,
      height: height ?? this.height,
      textStyle: textStyle ?? this.textStyle,
      elevation: elevation ?? this.elevation,
      actionSpacing: actionSpacing ?? this.actionSpacing,
      alignment: alignment ?? this.alignment,
      runAlignment: runAlignment ?? this.runAlignment,
      crossAxisAlignment: crossAxisAlignment ?? this.crossAxisAlignment,
    );
  }

  @override
  int get hashCode => Object.hashAll([
        backgroundColor,
        iconColor,
        height,
        textStyle,
        elevation,
        actionSpacing,
        alignment,
        runAlignment,
        crossAxisAlignment,
      ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is PdfActionBarTheme &&
        other.backgroundColor == backgroundColor &&
        other.iconColor == iconColor &&
        other.height == height &&
        other.textStyle == textStyle &&
        other.elevation == elevation &&
        other.actionSpacing == actionSpacing &&
        other.alignment == alignment &&
        other.runAlignment == runAlignment &&
        other.crossAxisAlignment == crossAxisAlignment;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor));
    properties.add(ColorProperty('iconColor', iconColor));
    properties.add(DoubleProperty('height', height));
    properties.add(DiagnosticsProperty<TextStyle>('textStyle', textStyle));
    properties.add(DoubleProperty('elevation', elevation));
    properties.add(DoubleProperty('actionSpacing', actionSpacing));
    properties.add(DiagnosticsProperty<WrapAlignment>('alignment', alignment,
        defaultValue: WrapAlignment.spaceAround));
    properties.add(DiagnosticsProperty<WrapAlignment>(
        'runAlignment', runAlignment,
        defaultValue: WrapAlignment.center));
    properties.add(DiagnosticsProperty<WrapCrossAlignment>(
        'crossAxisAlignment', crossAxisAlignment,
        defaultValue: WrapCrossAlignment.center));
  }
}
