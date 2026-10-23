import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:printing/src/method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('net.nfet.printing');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late PrintingPlatform previous;
  late List<MethodCall> calls;
  setUp(() {
    previous = PrintingPlatform.instance;
    PrintingPlatform.instance = MethodChannelPrinting();
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'printPdf') {
        final args = call.arguments as Map;
        await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            MethodCall('onCompleted', {
              'job': args['job'],
              'completed': false,
              'error': null,
            }),
          ),
          (_) {},
        );
      }
      return 1;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    PrintingPlatform.instance = previous;
  });
  test('explicit owner is delivered per job, including view zero', () async {
    await Printing.layoutPdf(
      onLayout: (_) => Uint8List(0),
      windowHandle: 101,
      viewId: 0,
    );
    await Printing.directPrintPdf(
      printer: const Printer(url: 'printer'),
      onLayout: (_) => Uint8List(0),
      windowHandle: 202,
      viewId: 2,
    );
    expect((calls[0].arguments as Map)['windowHandle'], 101);
    expect((calls[0].arguments as Map)['viewId'], 0);
    expect((calls[1].arguments as Map)['windowHandle'], 202);
    expect((calls[1].arguments as Map)['viewId'], 2);
  });
  test('share retains an explicit view zero', () async {
    await Printing.sharePdf(bytes: Uint8List(0), viewId: 0);
    expect((calls.single.arguments as Map)['viewId'], 0);
  });
  test('legacy calls omit owner arguments', () async {
    await Printing.layoutPdf(onLayout: (_) => Uint8List(0));
    expect(calls.single.arguments as Map, isNot(contains('windowHandle')));
    expect(calls.single.arguments as Map, isNot(contains('viewId')));
  });
}
