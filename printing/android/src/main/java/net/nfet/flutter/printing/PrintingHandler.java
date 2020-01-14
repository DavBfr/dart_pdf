package net.nfet.flutter.printing;

import android.app.Activity;
import android.print.PrintAttributes;

import androidx.annotation.NonNull;

import java.util.HashMap;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class PrintingHandler implements MethodChannel.MethodCallHandler {
    private final Activity activity;
    private final MethodChannel channel;

    public PrintingHandler(@NonNull Activity activity, @NonNull MethodChannel channel) {
        this.activity = activity;
        this.channel = channel;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
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
            case "rasterPdf": {
                final byte[] document = call.argument("doc");
                final int[] pages = call.argument("pages");
                Double scale = call.argument("scale");
                final PrintingJob printJob =
                        new PrintingJob(activity, this, (int) call.argument("job"));
                printJob.rasterPdf(document, pages, scale);
                result.success(1);
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

        channel.invokeMethod("onLayout", args, new MethodChannel.Result() {
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

    /// send pdf to raster data result to flutter
    void onPageRasterized(PrintingJob printJob, byte[] imageData, int width, int height) {
        HashMap<String, Object> args = new HashMap<>();
        args.put("image", imageData);
        args.put("width", width);
        args.put("height", height);
        args.put("job", printJob.index);

        channel.invokeMethod("onPageRasterized", args);
    }

    void onPageRasterEnd(PrintingJob printJob) {
        HashMap<String, Object> args = new HashMap<>();
        args.put("job", printJob.index);

        channel.invokeMethod("onPageRasterEnd", args);
    }
}
