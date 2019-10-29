/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

part of pdf;

class PdfArabic {
  /// Arabic shape substitutions: char code => (isolated, final, initial, medial).
  /// Arabic Substition A
  static const Map<int, dynamic> _arabicSubstitionA = <int, dynamic>{
    0x0621: <int>[0xFE80], // ARABIC LETTER HAMZA
    0x0622: <int>[0xFE81, 0xFE82], // ARABIC LETTER ALEF WITH MADDA ABOVE
    0x0623: <int>[0xFE83, 0xFE84], // ARABIC LETTER ALEF WITH HAMZA ABOVE
    0x0624: <int>[0xFE85, 0xFE86], // ARABIC LETTER WAW WITH HAMZA ABOVE
    0x0625: <int>[0xFE87, 0xFE88], // ARABIC LETTER ALEF WITH HAMZA BELOW
    0x0626: <int>[
      0xFE89,
      0xFE8A,
      0xFE8B,
      0xFE8C
    ], // ARABIC LETTER YEH WITH HAMZA ABOVE
    0x0627: <int>[0xFE8D, 0xFE8E], // ARABIC LETTER ALEF
    0x0628: <int>[0xFE8F, 0xFE90, 0xFE91, 0xFE92], // ARABIC LETTER BEH
    0x0629: <int>[0xFE93, 0xFE94], // ARABIC LETTER TEH MARBUTA
    0x062A: <int>[0xFE95, 0xFE96, 0xFE97, 0xFE98], // ARABIC LETTER TEH
    0x062B: <int>[0xFE99, 0xFE9A, 0xFE9B, 0xFE9C], // ARABIC LETTER THEH
    0x062C: <int>[0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0], // ARABIC LETTER JEEM
    0x062D: <int>[0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4], // ARABIC LETTER HAH
    0x062E: <int>[0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8], // ARABIC LETTER KHAH
    0x062F: <int>[0xFEA9, 0xFEAA], // ARABIC LETTER DAL
    0x0630: <int>[0xFEAB, 0xFEAC], // ARABIC LETTER THAL
    0x0631: <int>[0xFEAD, 0xFEAE], // ARABIC LETTER REH
    0x0632: <int>[0xFEAF, 0xFEB0], // ARABIC LETTER ZAIN
    0x0633: <int>[0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4], // ARABIC LETTER SEEN
    0x0634: <int>[0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8], // ARABIC LETTER SHEEN
    0x0635: <int>[0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC], // ARABIC LETTER SAD
    0x0636: <int>[0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0], // ARABIC LETTER DAD
    0x0637: <int>[0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4], // ARABIC LETTER TAH
    0x0638: <int>[0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8], // ARABIC LETTER ZAH
    0x0639: <int>[0xFEC9, 0xFECA, 0xFECB, 0xFECC], // ARABIC LETTER AIN
    0x063A: <int>[0xFECD, 0xFECE, 0xFECF, 0xFED0], // ARABIC LETTER GHAIN
    0x0641: <int>[0xFED1, 0xFED2, 0xFED3, 0xFED4], // ARABIC LETTER FEH
    0x0642: <int>[0xFED5, 0xFED6, 0xFED7, 0xFED8], // ARABIC LETTER QAF
    0x0643: <int>[0xFED9, 0xFEDA, 0xFEDB, 0xFEDC], // ARABIC LETTER KAF
    0x0644: <int>[0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0], // ARABIC LETTER LAM
    0x0645: <int>[0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4], // ARABIC LETTER MEEM
    0x0646: <int>[0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8], // ARABIC LETTER NOON
    0x0647: <int>[0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC], // ARABIC LETTER HEH
    0x0648: <int>[0xFEED, 0xFEEE], // ARABIC LETTER WAW
    0x0649: <int>[0xFEEF, 0xFEF0, 64488, 64489], // ARABIC LETTER ALEF MAKSURA
    0x064A: <int>[0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4], // ARABIC LETTER YEH
    0x0671: <int>[0xFB50, 0xFB51], // ARABIC LETTER ALEF WASLA
    0x0677: <int>[0xFBDD], // ARABIC LETTER U WITH HAMZA ABOVE
    0x0679: <int>[0xFB66, 0xFB67, 0xFB68, 0xFB69], // ARABIC LETTER TTEH
    0x067A: <int>[0xFB5E, 0xFB5F, 0xFB60, 0xFB61], // ARABIC LETTER TTEHEH
    0x067B: <int>[0xFB52, 0xFB53, 0xFB54, 0xFB55], // ARABIC LETTER BEEH
    0x067E: <int>[0xFB56, 0xFB57, 0xFB58, 0xFB59], // ARABIC LETTER PEH
    0x067F: <int>[0xFB62, 0xFB63, 0xFB64, 0xFB65], // ARABIC LETTER TEHEH
    0x0680: <int>[0xFB5A, 0xFB5B, 0xFB5C, 0xFB5D], // ARABIC LETTER BEHEH
    0x0683: <int>[0xFB76, 0xFB77, 0xFB78, 0xFB79], // ARABIC LETTER NYEH
    0x0684: <int>[0xFB72, 0xFB73, 0xFB74, 0xFB75], // ARABIC LETTER DYEH
    0x0686: <int>[0xFB7A, 0xFB7B, 0xFB7C, 0xFB7D], // ARABIC LETTER TCHEH
    0x0687: <int>[0xFB7E, 0xFB7F, 0xFB80, 0xFB81], // ARABIC LETTER TCHEHEH
    0x0688: <int>[0xFB88, 0xFB89], // ARABIC LETTER DDAL
    0x068C: <int>[0xFB84, 0xFB85], // ARABIC LETTER DAHAL
    0x068D: <int>[0xFB82, 0xFB83], // ARABIC LETTER DDAHAL
    0x068E: <int>[0xFB86, 0xFB87], // ARABIC LETTER DUL
    0x0691: <int>[0xFB8C, 0xFB8D], // ARABIC LETTER RREH
    0x0698: <int>[0xFB8A, 0xFB8B], // ARABIC LETTER JEH
    0x06A4: <int>[0xFB6A, 0xFB6B, 0xFB6C, 0xFB6D], // ARABIC LETTER VEH
    0x06A6: <int>[0xFB6E, 0xFB6F, 0xFB70, 0xFB71], // ARABIC LETTER PEHEH
    0x06A9: <int>[0xFB8E, 0xFB8F, 0xFB90, 0xFB91], // ARABIC LETTER KEHEH
    0x06AD: <int>[0xFBD3, 0xFBD4, 0xFBD5, 0xFBD6], // ARABIC LETTER NG
    0x06AF: <int>[0xFB92, 0xFB93, 0xFB94, 0xFB95], // ARABIC LETTER GAF
    0x06B1: <int>[0xFB9A, 0xFB9B, 0xFB9C, 0xFB9D], // ARABIC LETTER NGOEH
    0x06B3: <int>[0xFB96, 0xFB97, 0xFB98, 0xFB99], // ARABIC LETTER GUEH
    0x06BA: <int>[0xFB9E, 0xFB9F], // ARABIC LETTER NOON GHUNNA
    0x06BB: <int>[0xFBA0, 0xFBA1, 0xFBA2, 0xFBA3], // ARABIC LETTER RNOON
    0x06BE: <int>[
      0xFBAA,
      0xFBAB,
      0xFBAC,
      0xFBAD
    ], // ARABIC LETTER HEH DOACHASHMEE
    0x06C0: <int>[0xFBA4, 0xFBA5], // ARABIC LETTER HEH WITH YEH ABOVE
    0x06C1: <int>[0xFBA6, 0xFBA7, 0xFBA8, 0xFBA9], // ARABIC LETTER HEH GOAL
    0x06C5: <int>[0xFBE0, 0xFBE1], // ARABIC LETTER KIRGHIZ OE
    0x06C6: <int>[0xFBD9, 0xFBDA], // ARABIC LETTER OE
    0x06C7: <int>[0xFBD7, 0xFBD8], // ARABIC LETTER U
    0x06C8: <int>[0xFBDB, 0xFBDC], // ARABIC LETTER YU
    0x06C9: <int>[0xFBE2, 0xFBE3], // ARABIC LETTER KIRGHIZ YU
    0x06CB: <int>[0xFBDE, 0xFBDF], // ARABIC LETTER VE
    0x06CC: <int>[0xFBFC, 0xFBFD, 0xFBFE, 0xFBFF], // ARABIC LETTER FARSI YEH
    0x06D0: <int>[0xFBE4, 0xFBE5, 0xFBE6, 0xFBE7], //ARABIC LETTER E
    0x06D2: <int>[0xFBAE, 0xFBAF], // ARABIC LETTER YEH BARREE
    0x06D3: <int>[0xFBB0, 0xFBB1], // ARABIC LETTER YEH BARREE WITH HAMZA ABOVE
  };

  /*
    var ligaturesSubstitutionA = {
        0xFBEA: []// ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH ALEF ISOLATED FORM
    };
    */

  static const Map<int, dynamic> _ligatures = <int, dynamic>{
    0xFEDF: <int, int>{
      0xFE82:
          0xFEF5, // ARABIC LIGATURE LAM WITH ALEF WITH MADDA ABOVE ISOLATED FORM
      0xFE84:
          0xFEF7, // ARABIC LIGATURE LAM WITH ALEF WITH HAMZA ABOVE ISOLATED FORM
      0xFE88:
          0xFEF9, // ARABIC LIGATURE LAM WITH ALEF WITH HAMZA BELOW ISOLATED FORM
      0xFE8E: 0xFEFB // ARABIC LIGATURE LAM WITH ALEF ISOLATED FORM
    },
    0xFEE0: <int, int>{
      0xFE82:
          0xFEF6, // ARABIC LIGATURE LAM WITH ALEF WITH MADDA ABOVE FINAL FORM
      0xFE84:
          0xFEF8, // ARABIC LIGATURE LAM WITH ALEF WITH HAMZA ABOVE FINAL FORM
      0xFE88:
          0xFEFA, // ARABIC LIGATURE LAM WITH ALEF WITH HAMZA BELOW FINAL FORM
      0xFE8E: 0xFEFC // ARABIC LIGATURE LAM WITH ALEF FINAL FORM
    },
    0xFE8D: <int, dynamic>{
      0xFEDF: <int, dynamic>{
        0xFEE0: <int, int>{0xFEEA: 0xFDF2}
      }
    }, // ALLAH
    0x0651: <int, int>{
      0x064C: 0xFC5E, // Shadda + Dammatan
      0x064D: 0xFC5F, // Shadda + Kasratan
      0x064E: 0xFC60, // Shadda + Fatha
      0x064F: 0xFC61, // Shadda + Damma
      0x0650: 0xFC62, // Shadda + Kasra
    }
  };

  static const List<int> _alfletter = <int>[1570, 1571, 1573, 1575];

  static const int _noChangeInForm = -1;
  static const int _isolatedForm = 0;
  static const int _finalForm = 1;
  static const int _initialForm = 2;
  static const int _medialForm = 3;

  static bool _isInArabicSubstitutionA(int letter) {
    return _arabicSubstitionA.containsKey(letter);
  }

  static bool _isArabicLetter(int letter) {
    return (letter >= 0x0600 && letter <= 0x06FF) ||
        (letter >= 0x0750 && letter <= 0x077F) ||
        (letter >= 0x08FF && letter <= 0xFB50) ||
        (letter >= 0xFDFF && letter <= 0xFEFF);
  }

  static bool _isArabicEndLetter(int letter) {
    return _isArabicLetter(letter) &&
        _isInArabicSubstitutionA(letter) &&
        _arabicSubstitionA[letter].length <= 2;
  }

  static bool _isArabicAlfLetter(int letter) {
    return _isArabicLetter(letter) && _alfletter.contains(letter);
  }

  static bool _arabicLetterHasFinalForm(int letter) {
    return _isArabicLetter(letter) &&
        _isInArabicSubstitutionA(letter) &&
        (_arabicSubstitionA[letter].length >= 2);
  }

  static bool _arabicLetterHasMedialForm(int letter) {
    return _isArabicLetter(letter) &&
        _isInArabicSubstitutionA(letter) &&
        _arabicSubstitionA[letter].length == 4;
  }

  static List<int> _resolveLigatures(List<int> letters) {
    final List<int> result = <int>[];
    int effectedLetters = 0;

    for (int i = 0; i < letters.length; i += 1) {
      if (_ligatures.containsKey(letters[i])) {
        effectedLetters++;
        final dynamic tmpLigature = _ligatures[letters[i]];

        if (tmpLigature is int) {
          result.add(tmpLigature);

          effectedLetters = 0;
        }
        if (i == letters.length - 1) {
          result.add(letters[i - (effectedLetters - 1)]);
          i = i - (effectedLetters - 1);
          effectedLetters = 0;
        }
      } else {
        result.add(letters[i - effectedLetters]);
        i = i - effectedLetters;
        effectedLetters = 0;
      }
    }

    return result;
  }

  static int getCorrectForm(int currentChar, int beforeChar, int nextChar) {
    if (_isInArabicSubstitutionA(currentChar) == false) {
      return _noChangeInForm;
    }
    if (!_arabicLetterHasFinalForm(currentChar) ||
        (!_isArabicLetter(beforeChar) && !_isArabicLetter(nextChar)) ||
        (!_isArabicLetter(nextChar) && _isArabicEndLetter(beforeChar)) ||
        (_isArabicEndLetter(currentChar) && !_isArabicLetter(beforeChar)) ||
        (_isArabicEndLetter(currentChar) && _isArabicAlfLetter(beforeChar)) ||
        (_isArabicEndLetter(currentChar) && _isArabicEndLetter(beforeChar))) {
      return _isolatedForm;
    }

    if (_arabicLetterHasMedialForm(currentChar) &&
        _isArabicLetter(beforeChar) &&
        !_isArabicEndLetter(beforeChar) &&
        _isArabicLetter(nextChar) &&
        _arabicLetterHasFinalForm(nextChar)) {
      return _medialForm;
    }

    if (_isArabicEndLetter(currentChar) || (!_isArabicLetter(nextChar))) {
      return _finalForm;
    }
    return _initialForm;
  }

  static Iterable<int> parse(String text) sync* {
    final List<String> words = text.split(' ');

    bool first = true;
    for (String word in words) {
      final List<int> newWord = <int>[];
      bool isArabic = false;

      for (int j = 0; j < word.length; j += 1) {
        final int currentLetter = word.codeUnitAt(j);
        final int prevLetter = j > 0 ? word.codeUnitAt(j - 1) : 0;
        final int nextLetter = j < word.length - 1 ? word.codeUnitAt(j + 1) : 0;
        if (_isArabicLetter(currentLetter)) {
          isArabic = true;

          final int position =
              getCorrectForm(currentLetter, prevLetter, nextLetter);
          if (position != -1) {
            newWord.insert(0, _arabicSubstitionA[currentLetter][position]);
          } else {
            newWord.add(currentLetter);
          }
        } else {
          if (isArabic && currentLetter > 32)
            newWord.insert(0, currentLetter);
          else
            newWord.add(currentLetter);
        }
      }

      if (!first) {
        yield 32;
      }
      first = false;

      yield* _resolveLigatures(newWord);
    }
  }

  static String convert(String input) {
    return String.fromCharCodes(parse(input));
  }
}
