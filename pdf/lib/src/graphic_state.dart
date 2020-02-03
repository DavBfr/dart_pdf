/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

// ignore_for_file: omit_local_variable_types

part of pdf;

@immutable
class PdfGraphicState {
  const PdfGraphicState({this.opacity});

  final double opacity;

  @protected
  PdfStream _output() {
    final Map<String, PdfStream> params = <String, PdfStream>{};

    if (opacity != null) {
      params['/CA'] = PdfStream.num(opacity);
      params['/ca'] = PdfStream.num(opacity);
    }

    return PdfStream.dictionary(params);
  }

  @override
  bool operator ==(dynamic other) {
    if (!other is PdfGraphicState) {
      return false;
    }
    return other.opacity == opacity;
  }

  @override
  int get hashCode => opacity.hashCode;
}

class PdfGraphicStates extends PdfObject {
  PdfGraphicStates(PdfDocument pdfDocument) : super(pdfDocument);

  final List<PdfGraphicState> _states = <PdfGraphicState>[];

  static const String _prefix = '/a';

  String stateName(PdfGraphicState state) {
    int index = _states.indexOf(state);
    if (index < 0) {
      index = _states.length;
      _states.add(state);
    }
    return '$_prefix$index';
  }

  @override
  void _prepare() {
    super._prepare();

    for (int index = 0; index < _states.length; index++) {
      params['$_prefix$index'] = _states[index]._output();
    }
  }
}
