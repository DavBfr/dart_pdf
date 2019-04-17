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
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.Environment;
import android.os.ParcelFileDescriptor;
import android.print.PageRange;
import android.print.PdfConvert;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintDocumentInfo;
import android.print.PrintManager;
import android.print.pdf.PrintedPdfDocument;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.HashMap;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * PrintingPlugin
 */
public class PrintingPlugin extends PrintDocumentAdapter implements MethodCallHandler {
    private static PrintManager printManager;
    private final Activity activity;
    private final MethodChannel channel;
    private PrintedPdfDocument mPdfDocument;
    private byte[] documentData;
    private String jobName;
    private LayoutResultCallback callback;

    private PrintingPlugin(Activity activity, MethodChannel channel) {
        this.activity = activity;
        this.channel = channel;
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "printing");
        channel.setMethodCallHandler(new PrintingPlugin(registrar.activity(), channel));
        printManager = (PrintManager) registrar.activity().getSystemService(Context.PRINT_SERVICE);
    }

    @Override
    public void onWrite(PageRange[] pageRanges, ParcelFileDescriptor parcelFileDescriptor,
            CancellationSignal cancellationSignal, WriteResultCallback writeResultCallback) {
        OutputStream output = null;
        try {
            output = new FileOutputStream(parcelFileDescriptor.getFileDescriptor());
            output.write(documentData, 0, documentData.length);
            writeResultCallback.onWriteFinished(new PageRange[] {PageRange.ALL_PAGES});
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                if (output != null) {
                    output.close();
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    @Override
    public void onLayout(PrintAttributes oldAttributes, PrintAttributes newAttributes,
            CancellationSignal cancellationSignal, LayoutResultCallback callback, Bundle extras) {
        // Create a new PdfDocument with the requested page attributes
        mPdfDocument = new PrintedPdfDocument(activity, newAttributes);

        // Respond to cancellation request
        if (cancellationSignal.isCanceled()) {
            callback.onLayoutCancelled();
            return;
        }

        this.callback = callback;

        HashMap<String, Double> args = new HashMap<>();

        PrintAttributes.MediaSize size = newAttributes.getMediaSize();
        args.put("width", size.getWidthMils() * 72.0 / 1000.0);
        args.put("height", size.getHeightMils() * 72.0 / 1000.0);

        PrintAttributes.Margins margins = newAttributes.getMinMargins();
        args.put("marginLeft", margins.getLeftMils() * 72.0 / 1000.0);
        args.put("marginTop", margins.getTopMils() * 72.0 / 1000.0);
        args.put("marginRight", margins.getRightMils() * 72.0 / 1000.0);
        args.put("marginBottom", margins.getBottomMils() * 72.0 / 1000.0);

        channel.invokeMethod("onLayout", args);
    }

    @Override
    public void onFinish() {
        // noinspection ResultOfMethodCallIgnored
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "printPdf":
                jobName =
                        call.argument("name") == null ? "Document" : (String) call.argument("name");
                assert jobName != null;
                printManager.print(jobName, this, null);
                result.success(0);
                break;
            case "writePdf":
                documentData = (byte[]) call.argument("doc");

                // Return print information to print framework
                PrintDocumentInfo info =
                        new PrintDocumentInfo.Builder(jobName + ".pdf")
                                .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                                .build();

                // Content layout reflow is complete
                callback.onLayoutFinished(info, true);

                result.success(0);
                break;
            case "sharePdf":
                sharePdf((byte[]) call.argument("doc"), (String) call.argument("name"));
                result.success(0);
                break;
            case "convertHtml":
                double width = (double) call.argument("width");
                double height = (double) call.argument("height");
                double marginLeft = (double) call.argument("marginLeft");
                double marginTop = (double) call.argument("marginTop");
                double marginRight = (double) call.argument("marginRight");
                double marginBottom = (double) call.argument("marginBottom");

                PrintAttributes.Margins margins =
                        new PrintAttributes.Margins(Double.valueOf(marginLeft * 1000.0).intValue(),
                                Double.valueOf(marginTop * 1000.0 / 72.0).intValue(),
                                Double.valueOf(marginRight * 1000.0 / 72.0).intValue(),
                                Double.valueOf(marginBottom * 1000.0 / 72.0).intValue());

                PrintAttributes.MediaSize size = new PrintAttributes.MediaSize("flutter_printing",
                        "Provided size", Double.valueOf(width * 1000.0 / 72.0).intValue(),
                        Double.valueOf(height * 1000.0 / 72.0).intValue());

                convertHtml((String) call.argument("html"), size, margins,
                        (String) call.argument("baseUrl"));
                result.success(0);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void sharePdf(byte[] data, String name) {
        try {
            final File externalFilesDirectory =
                    activity.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS);
            File shareFile;
            if (name == null) {
                shareFile = File.createTempFile("document-", ".pdf", externalFilesDirectory);
            } else {
                shareFile = new File(externalFilesDirectory, name);
            }

            FileOutputStream stream = new FileOutputStream(shareFile);
            stream.write(data);
            stream.close();

            Uri apkURI = FileProvider.getUriForFile(activity,
                    activity.getApplicationContext().getPackageName() + ".flutter.printing",
                    shareFile);

            Intent shareIntent = new Intent();
            shareIntent.setAction(Intent.ACTION_SEND);
            shareIntent.setType("application/pdf");
            shareIntent.putExtra(Intent.EXTRA_STREAM, apkURI);
            shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            Intent chooserIntent = Intent.createChooser(shareIntent, null);
            activity.startActivity(chooserIntent);
            shareFile.deleteOnExit();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void convertHtml(String data, final PrintAttributes.MediaSize size,
            final PrintAttributes.Margins margins, String baseUrl) {
        final WebView webView = new WebView(activity.getApplicationContext());

        webView.loadDataWithBaseURL(baseUrl, data, "text/HTML", "UTF-8", null);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                    PrintAttributes attributes =
                            new PrintAttributes.Builder()
                                    .setMediaSize(size)
                                    .setResolution(
                                            new PrintAttributes.Resolution("pdf", "pdf", 600, 600))
                                    .setMinMargins(margins)
                                    .build();

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        final PrintDocumentAdapter adapter =
                                webView.createPrintDocumentAdapter("printing");

                        PdfConvert.print(activity, adapter, attributes, new PdfConvert.Result() {
                            @Override
                            public void onSuccess(File file) {
                                try {
                                    byte[] fileContent = PdfConvert.readFile(file);
                                    channel.invokeMethod("onHtmlRendered", fileContent);
                                } catch (IOException e) {
                                    onError(e.getMessage());
                                }
                            }

                            @Override
                            public void onError(String message) {
                                channel.invokeMethod("onHtmlError", message);
                            }
                        });
                    }
                }
            }
        });
    }
}
