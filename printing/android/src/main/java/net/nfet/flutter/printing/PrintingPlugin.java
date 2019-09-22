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

package net.nfet.flutter.printing;

import android.app.Activity;
import android.print.PrintAttributes;

import androidx.annotation.NonNull;

import java.util.HashMap;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * PrintingPlugin
 */
public class PrintingPlugin implements MethodCallHandler {
    private final Activity activity;
    private final MethodChannel channel;

    private PrintingPlugin(@NonNull Activity activity, @NonNull MethodChannel channel) {
        this.activity = activity;
        this.channel = channel;
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        Activity activity = registrar.activity();
        if (activity == null) {
            return; // We can't print without an activity
        }

        final MethodChannel channel = new MethodChannel(registrar.messenger(), "net.nfet.printing");
        channel.setMethodCallHandler(new PrintingPlugin(activity, channel));
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "printPdf": {
                final String name = call.argument("name");
                final Double width = call.argument("width");
                final Double height = call.argument("height");
                final Double marginLeft = call.argument("marginLeft");
                final Double marginTop = call.argument("marginTop");
                final Double marginRight = call.argument("marginRight");
                final Double marginBottom = call.argument("marginBottom");

                final PrintingJob printJob =
                        new PrintingJob(activity, this, (int) call.argument("job"));
                assert name != null;
                printJob.printPdf(
                        name, width, height, marginLeft, marginTop, marginRight, marginBottom);

                result.success(1);
                break;
            }
            case "cancelJob": {
                final PrintingJob printJob =
                        new PrintingJob(activity, this, (int) call.argument("job"));
                printJob.cancelJob();
                result.success(1);
                break;
            }
            case "sharePdf": {
                final byte[] document = call.argument("doc");
                final String name = call.argument("name");
                PrintingJob.sharePdf(activity, document, name);
                result.success(1);
                break;
            }
            case "convertHtml": {
                Double width = call.argument("width");
                Double height = call.argument("height");
                Double marginLeft = call.argument("marginLeft");
                Double marginTop = call.argument("marginTop");
                Double marginRight = call.argument("marginRight");
                Double marginBottom = call.argument("marginBottom");
                final PrintingJob printJob =
                        new PrintingJob(activity, this, (int) call.argument("job"));

                assert width != null;
                assert height != null;
                assert marginLeft != null;
                assert marginTop != null;
                assert marginRight != null;
                assert marginBottom != null;

                PrintAttributes.Margins margins =
                        new PrintAttributes.Margins(Double.valueOf(marginLeft * 1000.0).intValue(),
                                Double.valueOf(marginTop * 1000.0 / 72.0).intValue(),
                                Double.valueOf(marginRight * 1000.0 / 72.0).intValue(),
                                Double.valueOf(marginBottom * 1000.0 / 72.0).intValue());

                PrintAttributes.MediaSize size = new PrintAttributes.MediaSize("flutter_printing",
                        "Provided size", Double.valueOf(width * 1000.0 / 72.0).intValue(),
                        Double.valueOf(height * 1000.0 / 72.0).intValue());

                printJob.convertHtml((String) call.argument("html"), size, margins,
                        (String) call.argument("baseUrl"));
                result.success(1);
                break;
            }
            case "printingInfo": {
                result.success(PrintingJob.printingInfo());
                break;
            }
            default:
                result.notImplemented();
                break;
        }
    }

    /// Request the Pdf document from flutter
    void onLayout(final PrintingJob printJob, Double width, double height, double marginLeft,
            double marginTop, double marginRight, double marginBottom) {
        HashMap<String, Object> args = new HashMap<>();
        args.put("width", width);
        args.put("height", height);

        args.put("marginLeft", marginLeft);
        args.put("marginTop", marginTop);
        args.put("marginRight", marginRight);
        args.put("marginBottom", marginBottom);
        args.put("job", printJob.index);

        channel.invokeMethod("onLayout", args, new Result() {
            @Override
            public void success(Object result) {
                if (result instanceof byte[]) {
                    printJob.setDocument((byte[]) result);
                } else {
                    printJob.cancelJob();
                }
            }

            @Override
            public void error(String errorCode, String errorMessage, Object errorDetails) {
                printJob.cancelJob();
            }

            @Override
            public void notImplemented() {
                printJob.cancelJob();
            }
        });
    }

    /// send completion status to flutter
    void onCompleted(PrintingJob printJob, boolean completed, String error) {
        HashMap<String, Object> args = new HashMap<>();
        args.put("completed", completed);

        args.put("error", error);
        args.put("job", printJob.index);

        channel.invokeMethod("onCompleted", args);
    }

    /// send html to pdf data result to flutter
    void onHtmlRendered(PrintingJob printJob, byte[] pdfData) {
        HashMap<String, Object> args = new HashMap<>();
        args.put("doc", pdfData);
        args.put("job", printJob.index);

        channel.invokeMethod("onHtmlRendered", args);
    }

    /// send html to pdf conversion error to flutter
    void onHtmlError(PrintingJob printJob, String error) {
        HashMap<String, Object> args = new HashMap<>();
        args.put("error", error);
        args.put("job", printJob.index);

        channel.invokeMethod("onHtmlError", args);
    }
}
