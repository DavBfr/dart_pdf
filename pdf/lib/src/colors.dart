/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http:  //www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// ignore_for_file: public_member_api_docs

part of pdf;

/// Material design colors
class PdfColors {
  PdfColors._();

  // Red
  static const PdfColor red = red500;
  static const PdfColor red50 = PdfColor.fromInt(0xffffebee);
  static const PdfColor red100 = PdfColor.fromInt(0xffffcdd2);
  static const PdfColor red200 = PdfColor.fromInt(0xffef9a9a);
  static const PdfColor red300 = PdfColor.fromInt(0xffe57373);
  static const PdfColor red400 = PdfColor.fromInt(0xffef5350);
  static const PdfColor red500 = PdfColor.fromInt(0xfff44336);
  static const PdfColor red600 = PdfColor.fromInt(0xffe53935);
  static const PdfColor red700 = PdfColor.fromInt(0xffd32f2f);
  static const PdfColor red800 = PdfColor.fromInt(0xffc62828);
  static const PdfColor red900 = PdfColor.fromInt(0xffb71c1c);
  static const PdfColor redAccent = redAccent200;
  static const PdfColor redAccent100 = PdfColor.fromInt(0xffff8a80);
  static const PdfColor redAccent200 = PdfColor.fromInt(0xffff5252);
  static const PdfColor redAccent400 = PdfColor.fromInt(0xffff1744);
  static const PdfColor redAccent700 = PdfColor.fromInt(0xffd50000);

  // Pink
  static const PdfColor pink = pink500;
  static const PdfColor pink50 = PdfColor.fromInt(0xfffce4ec);
  static const PdfColor pink100 = PdfColor.fromInt(0xfff8bbd0);
  static const PdfColor pink200 = PdfColor.fromInt(0xfff48fb1);
  static const PdfColor pink300 = PdfColor.fromInt(0xfff06292);
  static const PdfColor pink400 = PdfColor.fromInt(0xffec407a);
  static const PdfColor pink500 = PdfColor.fromInt(0xffe91e63);
  static const PdfColor pink600 = PdfColor.fromInt(0xffd81b60);
  static const PdfColor pink700 = PdfColor.fromInt(0xffc2185b);
  static const PdfColor pink800 = PdfColor.fromInt(0xffad1457);
  static const PdfColor pink900 = PdfColor.fromInt(0xff880e4f);
  static const PdfColor pinkAccent = pinkAccent200;
  static const PdfColor pinkAccent100 = PdfColor.fromInt(0xffff80ab);
  static const PdfColor pinkAccent200 = PdfColor.fromInt(0xffff4081);
  static const PdfColor pinkAccent400 = PdfColor.fromInt(0xfff50057);
  static const PdfColor pinkAccent700 = PdfColor.fromInt(0xffc51162);

  // Purple
  static const PdfColor purple = purple500;
  static const PdfColor purple50 = PdfColor.fromInt(0xfff3e5f5);
  static const PdfColor purple100 = PdfColor.fromInt(0xffe1bee7);
  static const PdfColor purple200 = PdfColor.fromInt(0xffce93d8);
  static const PdfColor purple300 = PdfColor.fromInt(0xffba68c8);
  static const PdfColor purple400 = PdfColor.fromInt(0xffab47bc);
  static const PdfColor purple500 = PdfColor.fromInt(0xff9c27b0);
  static const PdfColor purple600 = PdfColor.fromInt(0xff8e24aa);
  static const PdfColor purple700 = PdfColor.fromInt(0xff7b1fa2);
  static const PdfColor purple800 = PdfColor.fromInt(0xff6a1b9a);
  static const PdfColor purple900 = PdfColor.fromInt(0xff4a148c);
  static const PdfColor purpleAccent = purpleAccent200;
  static const PdfColor purpleAccent100 = PdfColor.fromInt(0xffea80fc);
  static const PdfColor purpleAccent200 = PdfColor.fromInt(0xffe040fb);
  static const PdfColor purpleAccent400 = PdfColor.fromInt(0xffd500f9);
  static const PdfColor purpleAccent700 = PdfColor.fromInt(0xffaa00ff);

  // Deep Purple
  static const PdfColor deepPurple = deepPurple500;
  static const PdfColor deepPurple50 = PdfColor.fromInt(0xffede7f6);
  static const PdfColor deepPurple100 = PdfColor.fromInt(0xffd1c4e9);
  static const PdfColor deepPurple200 = PdfColor.fromInt(0xffb39ddb);
  static const PdfColor deepPurple300 = PdfColor.fromInt(0xff9575cd);
  static const PdfColor deepPurple400 = PdfColor.fromInt(0xff7e57c2);
  static const PdfColor deepPurple500 = PdfColor.fromInt(0xff673ab7);
  static const PdfColor deepPurple600 = PdfColor.fromInt(0xff5e35b1);
  static const PdfColor deepPurple700 = PdfColor.fromInt(0xff512da8);
  static const PdfColor deepPurple800 = PdfColor.fromInt(0xff4527a0);
  static const PdfColor deepPurple900 = PdfColor.fromInt(0xff311b92);
  static const PdfColor deepPurpleAccent = deepPurpleAccent200;
  static const PdfColor deepPurpleAccent100 = PdfColor.fromInt(0xffb388ff);
  static const PdfColor deepPurpleAccent200 = PdfColor.fromInt(0xff7c4dff);
  static const PdfColor deepPurpleAccent400 = PdfColor.fromInt(0xff651fff);
  static const PdfColor deepPurpleAccent700 = PdfColor.fromInt(0xff6200ea);

  // Indigo
  static const PdfColor indigo = indigo500;
  static const PdfColor indigo50 = PdfColor.fromInt(0xffe8eaf6);
  static const PdfColor indigo100 = PdfColor.fromInt(0xffc5cae9);
  static const PdfColor indigo200 = PdfColor.fromInt(0xff9fa8da);
  static const PdfColor indigo300 = PdfColor.fromInt(0xff7986cb);
  static const PdfColor indigo400 = PdfColor.fromInt(0xff5c6bc0);
  static const PdfColor indigo500 = PdfColor.fromInt(0xff3f51b5);
  static const PdfColor indigo600 = PdfColor.fromInt(0xff3949ab);
  static const PdfColor indigo700 = PdfColor.fromInt(0xff303f9f);
  static const PdfColor indigo800 = PdfColor.fromInt(0xff283593);
  static const PdfColor indigo900 = PdfColor.fromInt(0xff1a237e);
  static const PdfColor indigoAccent = indigoAccent200;
  static const PdfColor indigoAccent100 = PdfColor.fromInt(0xff8c9eff);
  static const PdfColor indigoAccent200 = PdfColor.fromInt(0xff536dfe);
  static const PdfColor indigoAccent400 = PdfColor.fromInt(0xff3d5afe);
  static const PdfColor indigoAccent700 = PdfColor.fromInt(0xff304ffe);

  // Blue
  static const PdfColor blue = blue500;
  static const PdfColor blue50 = PdfColor.fromInt(0xffe3f2fd);
  static const PdfColor blue100 = PdfColor.fromInt(0xffbbdefb);
  static const PdfColor blue200 = PdfColor.fromInt(0xff90caf9);
  static const PdfColor blue300 = PdfColor.fromInt(0xff64b5f6);
  static const PdfColor blue400 = PdfColor.fromInt(0xff42a5f5);
  static const PdfColor blue500 = PdfColor.fromInt(0xff2196f3);
  static const PdfColor blue600 = PdfColor.fromInt(0xff1e88e5);
  static const PdfColor blue700 = PdfColor.fromInt(0xff1976d2);
  static const PdfColor blue800 = PdfColor.fromInt(0xff1565c0);
  static const PdfColor blue900 = PdfColor.fromInt(0xff0d47a1);
  static const PdfColor blueAccent = blueAccent200;
  static const PdfColor blueAccent100 = PdfColor.fromInt(0xff82b1ff);
  static const PdfColor blueAccent200 = PdfColor.fromInt(0xff448aff);
  static const PdfColor blueAccent400 = PdfColor.fromInt(0xff2979ff);
  static const PdfColor blueAccent700 = PdfColor.fromInt(0xff2962ff);

  // Light Blue
  static const PdfColor lightBlue = lightBlue500;
  static const PdfColor lightBlue50 = PdfColor.fromInt(0xffe1f5fe);
  static const PdfColor lightBlue100 = PdfColor.fromInt(0xffb3e5fc);
  static const PdfColor lightBlue200 = PdfColor.fromInt(0xff81d4fa);
  static const PdfColor lightBlue300 = PdfColor.fromInt(0xff4fc3f7);
  static const PdfColor lightBlue400 = PdfColor.fromInt(0xff29b6f6);
  static const PdfColor lightBlue500 = PdfColor.fromInt(0xff03a9f4);
  static const PdfColor lightBlue600 = PdfColor.fromInt(0xff039be5);
  static const PdfColor lightBlue700 = PdfColor.fromInt(0xff0288d1);
  static const PdfColor lightBlue800 = PdfColor.fromInt(0xff0277bd);
  static const PdfColor lightBlue900 = PdfColor.fromInt(0xff01579b);
  static const PdfColor lightBlueAccent = lightBlueAccent200;
  static const PdfColor lightBlueAccent100 = PdfColor.fromInt(0xff80d8ff);
  static const PdfColor lightBlueAccent200 = PdfColor.fromInt(0xff40c4ff);
  static const PdfColor lightBlueAccent400 = PdfColor.fromInt(0xff00b0ff);
  static const PdfColor lightBlueAccent700 = PdfColor.fromInt(0xff0091ea);

  // Cyan
  static const PdfColor cyan = cyan500;
  static const PdfColor cyan50 = PdfColor.fromInt(0xffe0f7fa);
  static const PdfColor cyan100 = PdfColor.fromInt(0xffb2ebf2);
  static const PdfColor cyan200 = PdfColor.fromInt(0xff80deea);
  static const PdfColor cyan300 = PdfColor.fromInt(0xff4dd0e1);
  static const PdfColor cyan400 = PdfColor.fromInt(0xff26c6da);
  static const PdfColor cyan500 = PdfColor.fromInt(0xff00bcd4);
  static const PdfColor cyan600 = PdfColor.fromInt(0xff00acc1);
  static const PdfColor cyan700 = PdfColor.fromInt(0xff0097a7);
  static const PdfColor cyan800 = PdfColor.fromInt(0xff00838f);
  static const PdfColor cyan900 = PdfColor.fromInt(0xff006064);
  static const PdfColor cyanAccent = cyanAccent200;
  static const PdfColor cyanAccent100 = PdfColor.fromInt(0xff84ffff);
  static const PdfColor cyanAccent200 = PdfColor.fromInt(0xff18ffff);
  static const PdfColor cyanAccent400 = PdfColor.fromInt(0xff00e5ff);
  static const PdfColor cyanAccent700 = PdfColor.fromInt(0xff00b8d4);

  // Teal
  static const PdfColor teal = teal500;
  static const PdfColor teal50 = PdfColor.fromInt(0xffe0f2f1);
  static const PdfColor teal100 = PdfColor.fromInt(0xffb2dfdb);
  static const PdfColor teal200 = PdfColor.fromInt(0xff80cbc4);
  static const PdfColor teal300 = PdfColor.fromInt(0xff4db6ac);
  static const PdfColor teal400 = PdfColor.fromInt(0xff26a69a);
  static const PdfColor teal500 = PdfColor.fromInt(0xff009688);
  static const PdfColor teal600 = PdfColor.fromInt(0xff00897b);
  static const PdfColor teal700 = PdfColor.fromInt(0xff00796b);
  static const PdfColor teal800 = PdfColor.fromInt(0xff00695c);
  static const PdfColor teal900 = PdfColor.fromInt(0xff004d40);
  static const PdfColor tealAccent = tealAccent200;
  static const PdfColor tealAccent100 = PdfColor.fromInt(0xffa7ffeb);
  static const PdfColor tealAccent200 = PdfColor.fromInt(0xff64ffda);
  static const PdfColor tealAccent400 = PdfColor.fromInt(0xff1de9b6);
  static const PdfColor tealAccent700 = PdfColor.fromInt(0xff00bfa5);

  // Green
  static const PdfColor green = green500;
  static const PdfColor green50 = PdfColor.fromInt(0xffe8f5e9);
  static const PdfColor green100 = PdfColor.fromInt(0xffc8e6c9);
  static const PdfColor green200 = PdfColor.fromInt(0xffa5d6a7);
  static const PdfColor green300 = PdfColor.fromInt(0xff81c784);
  static const PdfColor green400 = PdfColor.fromInt(0xff66bb6a);
  static const PdfColor green500 = PdfColor.fromInt(0xff4caf50);
  static const PdfColor green600 = PdfColor.fromInt(0xff43a047);
  static const PdfColor green700 = PdfColor.fromInt(0xff388e3c);
  static const PdfColor green800 = PdfColor.fromInt(0xff2e7d32);
  static const PdfColor green900 = PdfColor.fromInt(0xff1b5e20);
  static const PdfColor greenAccent = greenAccent200;
  static const PdfColor greenAccent100 = PdfColor.fromInt(0xffb9f6ca);
  static const PdfColor greenAccent200 = PdfColor.fromInt(0xff69f0ae);
  static const PdfColor greenAccent400 = PdfColor.fromInt(0xff00e676);
  static const PdfColor greenAccent700 = PdfColor.fromInt(0xff00c853);

  // Light Green
  static const PdfColor lightGreen = lightGreen500;
  static const PdfColor lightGreen50 = PdfColor.fromInt(0xfff1f8e9);
  static const PdfColor lightGreen100 = PdfColor.fromInt(0xffdcedc8);
  static const PdfColor lightGreen200 = PdfColor.fromInt(0xffc5e1a5);
  static const PdfColor lightGreen300 = PdfColor.fromInt(0xffaed581);
  static const PdfColor lightGreen400 = PdfColor.fromInt(0xff9ccc65);
  static const PdfColor lightGreen500 = PdfColor.fromInt(0xff8bc34a);
  static const PdfColor lightGreen600 = PdfColor.fromInt(0xff7cb342);
  static const PdfColor lightGreen700 = PdfColor.fromInt(0xff689f38);
  static const PdfColor lightGreen800 = PdfColor.fromInt(0xff558b2f);
  static const PdfColor lightGreen900 = PdfColor.fromInt(0xff33691e);
  static const PdfColor lightGreenAccent = lightGreenAccent200;
  static const PdfColor lightGreenAccent100 = PdfColor.fromInt(0xffccff90);
  static const PdfColor lightGreenAccent200 = PdfColor.fromInt(0xffb2ff59);
  static const PdfColor lightGreenAccent400 = PdfColor.fromInt(0xff76ff03);
  static const PdfColor lightGreenAccent700 = PdfColor.fromInt(0xff64dd17);

  // Lime
  static const PdfColor lime = lime500;
  static const PdfColor lime50 = PdfColor.fromInt(0xfff9fbe7);
  static const PdfColor lime100 = PdfColor.fromInt(0xfff0f4c3);
  static const PdfColor lime200 = PdfColor.fromInt(0xffe6ee9c);
  static const PdfColor lime300 = PdfColor.fromInt(0xffdce775);
  static const PdfColor lime400 = PdfColor.fromInt(0xffd4e157);
  static const PdfColor lime500 = PdfColor.fromInt(0xffcddc39);
  static const PdfColor lime600 = PdfColor.fromInt(0xffc0ca33);
  static const PdfColor lime700 = PdfColor.fromInt(0xffafb42b);
  static const PdfColor lime800 = PdfColor.fromInt(0xff9e9d24);
  static const PdfColor lime900 = PdfColor.fromInt(0xff827717);
  static const PdfColor limeAccent = limeAccent200;
  static const PdfColor limeAccent100 = PdfColor.fromInt(0xfff4ff81);
  static const PdfColor limeAccent200 = PdfColor.fromInt(0xffeeff41);
  static const PdfColor limeAccent400 = PdfColor.fromInt(0xffc6ff00);
  static const PdfColor limeAccent700 = PdfColor.fromInt(0xffaeea00);

  // Yellow
  static const PdfColor yellow = yellow500;
  static const PdfColor yellow50 = PdfColor.fromInt(0xfffffde7);
  static const PdfColor yellow100 = PdfColor.fromInt(0xfffff9c4);
  static const PdfColor yellow200 = PdfColor.fromInt(0xfffff59d);
  static const PdfColor yellow300 = PdfColor.fromInt(0xfffff176);
  static const PdfColor yellow400 = PdfColor.fromInt(0xffffee58);
  static const PdfColor yellow500 = PdfColor.fromInt(0xffffeb3b);
  static const PdfColor yellow600 = PdfColor.fromInt(0xfffdd835);
  static const PdfColor yellow700 = PdfColor.fromInt(0xfffbc02d);
  static const PdfColor yellow800 = PdfColor.fromInt(0xfff9a825);
  static const PdfColor yellow900 = PdfColor.fromInt(0xfff57f17);
  static const PdfColor yellowAccent = yellowAccent200;
  static const PdfColor yellowAccent100 = PdfColor.fromInt(0xffffff8d);
  static const PdfColor yellowAccent200 = PdfColor.fromInt(0xffffff00);
  static const PdfColor yellowAccent400 = PdfColor.fromInt(0xffffea00);
  static const PdfColor yellowAccent700 = PdfColor.fromInt(0xffffd600);

  // Amber
  static const PdfColor amber = amber500;
  static const PdfColor amber50 = PdfColor.fromInt(0xfffff8e1);
  static const PdfColor amber100 = PdfColor.fromInt(0xffffecb3);
  static const PdfColor amber200 = PdfColor.fromInt(0xffffe082);
  static const PdfColor amber300 = PdfColor.fromInt(0xffffd54f);
  static const PdfColor amber400 = PdfColor.fromInt(0xffffca28);
  static const PdfColor amber500 = PdfColor.fromInt(0xffffc107);
  static const PdfColor amber600 = PdfColor.fromInt(0xffffb300);
  static const PdfColor amber700 = PdfColor.fromInt(0xffffa000);
  static const PdfColor amber800 = PdfColor.fromInt(0xffff8f00);
  static const PdfColor amber900 = PdfColor.fromInt(0xffff6f00);
  static const PdfColor amberAccent = amberAccent200;
  static const PdfColor amberAccent100 = PdfColor.fromInt(0xffffe57f);
  static const PdfColor amberAccent200 = PdfColor.fromInt(0xffffd740);
  static const PdfColor amberAccent400 = PdfColor.fromInt(0xffffc400);
  static const PdfColor amberAccent700 = PdfColor.fromInt(0xffffab00);

  // Orange
  static const PdfColor orange = orange500;
  static const PdfColor orange50 = PdfColor.fromInt(0xfffff3e0);
  static const PdfColor orange100 = PdfColor.fromInt(0xffffe0b2);
  static const PdfColor orange200 = PdfColor.fromInt(0xffffcc80);
  static const PdfColor orange300 = PdfColor.fromInt(0xffffb74d);
  static const PdfColor orange400 = PdfColor.fromInt(0xffffa726);
  static const PdfColor orange500 = PdfColor.fromInt(0xffff9800);
  static const PdfColor orange600 = PdfColor.fromInt(0xfffb8c00);
  static const PdfColor orange700 = PdfColor.fromInt(0xfff57c00);
  static const PdfColor orange800 = PdfColor.fromInt(0xffef6c00);
  static const PdfColor orange900 = PdfColor.fromInt(0xffe65100);
  static const PdfColor orangeAccent = orangeAccent200;
  static const PdfColor orangeAccent100 = PdfColor.fromInt(0xffffd180);
  static const PdfColor orangeAccent200 = PdfColor.fromInt(0xffffab40);
  static const PdfColor orangeAccent400 = PdfColor.fromInt(0xffff9100);
  static const PdfColor orangeAccent700 = PdfColor.fromInt(0xffff6d00);

  // Deep Orange
  static const PdfColor deepOrange = deepOrange500;
  static const PdfColor deepOrange50 = PdfColor.fromInt(0xfffbe9e7);
  static const PdfColor deepOrange100 = PdfColor.fromInt(0xffffccbc);
  static const PdfColor deepOrange200 = PdfColor.fromInt(0xffffab91);
  static const PdfColor deepOrange300 = PdfColor.fromInt(0xffff8a65);
  static const PdfColor deepOrange400 = PdfColor.fromInt(0xffff7043);
  static const PdfColor deepOrange500 = PdfColor.fromInt(0xffff5722);
  static const PdfColor deepOrange600 = PdfColor.fromInt(0xfff4511e);
  static const PdfColor deepOrange700 = PdfColor.fromInt(0xffe64a19);
  static const PdfColor deepOrange800 = PdfColor.fromInt(0xffd84315);
  static const PdfColor deepOrange900 = PdfColor.fromInt(0xffbf360c);
  static const PdfColor deepOrangeAccent = deepOrangeAccent200;
  static const PdfColor deepOrangeAccent100 = PdfColor.fromInt(0xffff9e80);
  static const PdfColor deepOrangeAccent200 = PdfColor.fromInt(0xffff6e40);
  static const PdfColor deepOrangeAccent400 = PdfColor.fromInt(0xffff3d00);
  static const PdfColor deepOrangeAccent700 = PdfColor.fromInt(0xffdd2c00);

  // Brown
  static const PdfColor brown = brown500;
  static const PdfColor brown50 = PdfColor.fromInt(0xffefebe9);
  static const PdfColor brown100 = PdfColor.fromInt(0xffd7ccc8);
  static const PdfColor brown200 = PdfColor.fromInt(0xffbcaaa4);
  static const PdfColor brown300 = PdfColor.fromInt(0xffa1887f);
  static const PdfColor brown400 = PdfColor.fromInt(0xff8d6e63);
  static const PdfColor brown500 = PdfColor.fromInt(0xff795548);
  static const PdfColor brown600 = PdfColor.fromInt(0xff6d4c41);
  static const PdfColor brown700 = PdfColor.fromInt(0xff5d4037);
  static const PdfColor brown800 = PdfColor.fromInt(0xff4e342e);
  static const PdfColor brown900 = PdfColor.fromInt(0xff3e2723);

  // Grey
  static const PdfColor grey = grey500;
  static const PdfColor grey50 = PdfColor.fromInt(0xfffafafa);
  static const PdfColor grey100 = PdfColor.fromInt(0xfff5f5f5);
  static const PdfColor grey200 = PdfColor.fromInt(0xffeeeeee);
  static const PdfColor grey300 = PdfColor.fromInt(0xffe0e0e0);
  static const PdfColor grey400 = PdfColor.fromInt(0xffbdbdbd);
  static const PdfColor grey500 = PdfColor.fromInt(0xff9e9e9e);
  static const PdfColor grey600 = PdfColor.fromInt(0xff757575);
  static const PdfColor grey700 = PdfColor.fromInt(0xff616161);
  static const PdfColor grey800 = PdfColor.fromInt(0xff424242);
  static const PdfColor grey900 = PdfColor.fromInt(0xff212121);

  // Blue Grey
  static const PdfColor blueGrey = blueGrey500;
  static const PdfColor blueGrey50 = PdfColor.fromInt(0xffeceff1);
  static const PdfColor blueGrey100 = PdfColor.fromInt(0xffcfd8dc);
  static const PdfColor blueGrey200 = PdfColor.fromInt(0xffb0bec5);
  static const PdfColor blueGrey300 = PdfColor.fromInt(0xff90a4ae);
  static const PdfColor blueGrey400 = PdfColor.fromInt(0xff78909c);
  static const PdfColor blueGrey500 = PdfColor.fromInt(0xff607d8b);
  static const PdfColor blueGrey600 = PdfColor.fromInt(0xff546e7a);
  static const PdfColor blueGrey700 = PdfColor.fromInt(0xff455a64);
  static const PdfColor blueGrey800 = PdfColor.fromInt(0xff37474f);
  static const PdfColor blueGrey900 = PdfColor.fromInt(0xff263238);

  // White / Black
  static const PdfColor white = PdfColor.fromInt(0xffffffff);
  static const PdfColor black = PdfColor.fromInt(0xff000000);

  /// The material design primary color swatches, excluding grey.
  static const List<PdfColor> primaries = <PdfColor>[
    red,
    pink,
    purple,
    deepPurple,
    indigo,
    blue,
    lightBlue,
    cyan,
    teal,
    green,
    lightGreen,
    lime,
    yellow,
    amber,
    orange,
    deepOrange,
    brown,
    grey,
    blueGrey,
  ];

  /// The material design accent color swatches.
  static const List<PdfColor> accents = <PdfColor>[
    redAccent,
    pinkAccent,
    purpleAccent,
    deepPurpleAccent,
    indigoAccent,
    blueAccent,
    lightBlueAccent,
    cyanAccent,
    tealAccent,
    greenAccent,
    lightGreenAccent,
    limeAccent,
    yellowAccent,
    amberAccent,
    orangeAccent,
    deepOrangeAccent,
  ];

  /// Get a pseudo-random color
  static PdfColor getColor(int index) {
    final hue = index * 137.508;
    final PdfColor color = PdfColorHsv(hue % 360, 1, 1);
    if ((index / 3) % 2 == 0) {
      return PdfColor.fromRYB(color.red, color.green, color.blue);
    }
    return color;
  }
}
