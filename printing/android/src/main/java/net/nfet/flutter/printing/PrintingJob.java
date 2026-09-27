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
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Matrix;
import android.graphics.pdf.PdfRenderer;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.print.PageRange;
import android.print.PdfConvert;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintDocumentInfo;
import android.print.PrintJob;
import android.print.PrintJobInfo;
import android.print.PrintManager;
import android.util.Log;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.annotation.VisibleForTesting;
import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

/**
 * PrintJob
 */
@RequiresApi(api = Build.VERSION_CODES.KITKAT)
public class PrintingJob extends PrintDocumentAdapter {
    private final Context context;
    private final PrintingHandler printing;
    private PrintJob printJob;
    private byte[] documentData;
    private String jobName;
    // Package-private, so the unit tests can put a job in the state the print
    // framework would have put it in.
    @VisibleForTesting LayoutResultCallback callback;
    // Set from the CancellationSignal listener, so onLayoutCancelled is only
    // ever used for a cancellation the framework actually asked for.
    @VisibleForTesting boolean layoutCancelled;
    // Whether the terminal result has already gone to Dart.
    private boolean completed;
    // The html conversion owns these for the length of one convertHtml call.
    private WebView htmlWebView;
    private PrintDocumentAdapter htmlAdapter;
    private boolean htmlDone;
    int index;

    PrintingJob(Context context, PrintingHandler printing, int index) {
        this.context = context;
        this.printing = printing;
        this.index = index;
    }

    static HashMap<String, Object> printingInfo(Context context) {
        // PrintManager.print refuses anything but an Activity, so an engine
        // with none attached - a background or cached engine - cannot print.
        // This used to report canPrint true there and then fail the call.
        final boolean canPrint = android.os.Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT
                && context instanceof Activity;
        final boolean canRaster = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP;

        HashMap<String, Object> result = new HashMap<>();
        result.put("directPrint", false);
        result.put("dynamicLayout", canPrint);
        result.put("canPrint", canPrint);
        result.put("canShare", true);
        result.put("canRaster", canRaster);
        return result;
    }

    @Override
    public void onWrite(PageRange[] pageRanges, ParcelFileDescriptor parcelFileDescriptor,
            CancellationSignal cancellationSignal, WriteResultCallback writeResultCallback) {
        // android.print requires exactly one of onWriteFinished,
        // onWriteFailed or onWriteCancelled per onWrite, and has no timeout.
        // A swallowed IOException left none of them, so the preview span on
        // 'Preparing preview' and layoutPdf never returned.
        if (cancellationSignal != null && cancellationSignal.isCanceled()) {
            writeResultCallback.onWriteCancelled();
            return;
        }

        if (documentData == null) {
            writeResultCallback.onWriteFailed("No document to write");
            return;
        }

        // The framework owns the descriptor, so this stream must not be an
        // AutoCloseOutputStream.
        final OutputStream output;
        try {
            output = new FileOutputStream(parcelFileDescriptor.getFileDescriptor());
        } catch (RuntimeException e) {
            reportWriteFailure(writeResultCallback, e);
            return;
        }

        writeDocument(output, writeResultCallback);
    }

    /**
     * Copy the document into an already-open stream and report exactly one
     * result.
     *
     * <p>Separate from onWrite so it can be exercised without a
     * ParcelFileDescriptor.
     */
    void writeDocument(OutputStream output, WriteResultCallback writeResultCallback) {
        try {
            output.write(documentData, 0, documentData.length);
            output.flush();
            output.close();
            writeResultCallback.onWriteFinished(new PageRange[] {PageRange.ALL_PAGES});
        } catch (IOException | RuntimeException e) {
            reportWriteFailure(writeResultCallback, e);
            try {
                output.close();
            } catch (IOException | RuntimeException ignored) {
                // Already failing; the framework still owns the descriptor.
            }
        }
    }

    private void reportWriteFailure(WriteResultCallback writeResultCallback, Throwable e) {
        Log.e("PDF", "Unable to write the document to the print spooler", e);
        final String message = e.getMessage();
        // onWriteFailed needs a message; null used to be the only outcome here
        // because nothing was reported at all.
        writeResultCallback.onWriteFailed(
                message != null ? message : "Unable to write the document");
    }

    @Override
    public void onLayout(PrintAttributes oldAttributes, PrintAttributes newAttributes,
            CancellationSignal cancellationSignal, LayoutResultCallback callback, Bundle extras) {
        // Respond to cancellation request
        if (cancellationSignal != null && cancellationSignal.isCanceled()) {
            callback.onLayoutCancelled();
            return;
        }

        this.callback = callback;
        layoutCancelled = false;

        // Without this listener nothing ever set the flag, so every failure
        // was reported as a cancellation.
        if (cancellationSignal != null) {
            cancellationSignal.setOnCancelListener(
                    () -> new Handler(Looper.getMainLooper()).post(() -> {
                        layoutCancelled = true;
                        cancelJob(null);
                    }));
        }

        PrintAttributes.MediaSize size = newAttributes.getMediaSize();
        PrintAttributes.Margins margins = newAttributes.getMinMargins();
        assert size != null;
        assert margins != null;

        printing.onLayout(this, size.getWidthMils() * 72.0 / 1000.0,
                size.getHeightMils() * 72.0 / 1000.0, margins.getLeftMils() * 72.0 / 1000.0,
                margins.getTopMils() * 72.0 / 1000.0, margins.getRightMils() * 72.0 / 1000.0,
                margins.getBottomMils() * 72.0 / 1000.0);
    }

    /**
     * Report this job's single terminal result to Dart.
     *
     * <p>The onFinish poll below and a layout failure could both report, which
     * the Dart side had to guard against; there is now one owner.
     */
    private void reportCompleted(final boolean success, final String message) {
        if (completed) {
            return;
        }
        completed = true;
        printing.onCompleted(PrintingJob.this, success, message);
    }

    @Override
    public void onFinish() {
        if (completed) {
            // Already reported - a layout failure, or a cancellation - so
            // there is nothing left to wait for.
            printJob = null;
            return;
        }

        Thread thread = new Thread(() -> {
            try {
                final boolean[] wait = {true};
                int count = 5 * 60 * 10; // That's 10 minutes.
                while (wait[0]) {
                    new Handler(Looper.getMainLooper()).post(() -> {
                        if (completed) {
                            wait[0] = false;
                            return;
                        }

                        int state = printJob == null ? PrintJobInfo.STATE_FAILED
                                                     : printJob.getInfo().getState();

                        if (state == PrintJobInfo.STATE_COMPLETED) {
                            reportCompleted(true, null);
                            wait[0] = false;
                        } else if (state == PrintJobInfo.STATE_CANCELED) {
                            reportCompleted(false, null);
                            wait[0] = false;
                        } else if (state == PrintJobInfo.STATE_FAILED) {
                            reportCompleted(false, "Unable to print");
                            wait[0] = false;
                        }
                    });

                    if (--count <= 0) {
                        throw new Exception("Timeout waiting for the job to finish");
                    }

                    if (wait[0]) {
                        Thread.sleep(200);
                    }
                }
            } catch (final Exception e) {
                new Handler(Looper.getMainLooper())
                        .post(()
                                        -> reportCompleted(printJob != null
                                                        && printJob.isCompleted(),
                                                e.getMessage()));
            }

            printJob = null;
        });

        thread.start();
    }

    void printPdf(@NonNull String name, @NonNull Double width, @NonNull Double height) {
        jobName = name;

        PrintAttributes.Builder attrBuilder = new PrintAttributes.Builder();

        // A zero axis means 'unspecified' in the channel protocol: a roll
        // format has no length. Double.intValue() of an out-of-range value is
        // Integer.MAX_VALUE, which then wrapped the comparisons below to
        // negative and left the framework's 1x2-mil unknown-size sentinel.
        final long widthMils = pointsToMils(width);
        final long heightMils = pointsToMils(height);

        PrintAttributes.MediaSize mediaSize = null;
        boolean isPortrait = heightMils == 0 || heightMils >= widthMils;

        if (widthMils > 0 && heightMils > 0) {
            // get the media size from predefined media sizes
            for (PrintAttributes.MediaSize size : getAllPredefinedSizes()) {
                // https://github.com/DavBfr/dart_pdf/issues/635
                final long err = 20;
                PrintAttributes.MediaSize m = isPortrait ? size.asPortrait() : size.asLandscape();
                // Compared in long so the tolerance cannot overflow.
                if ((widthMils + err) >= m.getWidthMils() && (widthMils - err) <= m.getWidthMils()
                        && (heightMils + err) >= m.getHeightMils()
                        && (heightMils - err) <= m.getHeightMils()) {
                    mediaSize = m;
                    break;
                }
            }
        }

        if (mediaSize == null && widthMils > 0) {
            // One axis known: describe a custom sheet rather than falling back
            // to the unknown-size sentinel, which makes the print UI resolve
            // the media from the printer and lay the document out for Letter.
            final long length = heightMils > 0 ? heightMils : widthMils * 2;
            mediaSize = new PrintAttributes.MediaSize(
                    "flutter_printing", "Provided size", (int) widthMils, (int) length);
        }

        if (mediaSize == null) {
            mediaSize = isPortrait ? PrintAttributes.MediaSize.UNKNOWN_PORTRAIT
                                   : PrintAttributes.MediaSize.UNKNOWN_LANDSCAPE;
        }

        attrBuilder.setMediaSize(mediaSize);
        PrintAttributes attrib = attrBuilder.build();

        // Resolved here, the only place that needs it, and never stored: a
        // static PrintManager kept its Context - the host Activity, with its
        // Window and FlutterView - alive for the whole process.
        final PrintManager printManager =
                (PrintManager) context.getSystemService(Context.PRINT_SERVICE);
        if (printManager == null) {
            cancelJob("The print service is not available on this device");
            return;
        }

        printJob = printManager.print(name, this, attrib);
    }

    List<PrintAttributes.MediaSize> getAllPredefinedSizes() {
        List<PrintAttributes.MediaSize> sizes = new ArrayList<>();

        // ISO sizes
        sizes.add(PrintAttributes.MediaSize.ISO_A0);
        sizes.add(PrintAttributes.MediaSize.ISO_A1);
        sizes.add(PrintAttributes.MediaSize.ISO_A2);
        sizes.add(PrintAttributes.MediaSize.ISO_A3);
        sizes.add(PrintAttributes.MediaSize.ISO_A4);
        sizes.add(PrintAttributes.MediaSize.ISO_A5);
        sizes.add(PrintAttributes.MediaSize.ISO_A6);
        sizes.add(PrintAttributes.MediaSize.ISO_A7);
        sizes.add(PrintAttributes.MediaSize.ISO_A8);
        sizes.add(PrintAttributes.MediaSize.ISO_A9);
        sizes.add(PrintAttributes.MediaSize.ISO_A10);
        sizes.add(PrintAttributes.MediaSize.ISO_B0);
        sizes.add(PrintAttributes.MediaSize.ISO_B1);
        sizes.add(PrintAttributes.MediaSize.ISO_B2);
        sizes.add(PrintAttributes.MediaSize.ISO_B3);
        sizes.add(PrintAttributes.MediaSize.ISO_B4);
        sizes.add(PrintAttributes.MediaSize.ISO_B5);
        sizes.add(PrintAttributes.MediaSize.ISO_B6);
        sizes.add(PrintAttributes.MediaSize.ISO_B7);
        sizes.add(PrintAttributes.MediaSize.ISO_B8);
        sizes.add(PrintAttributes.MediaSize.ISO_B9);
        sizes.add(PrintAttributes.MediaSize.ISO_B10);
        sizes.add(PrintAttributes.MediaSize.ISO_C0);
        sizes.add(PrintAttributes.MediaSize.ISO_C1);
        sizes.add(PrintAttributes.MediaSize.ISO_C2);
        sizes.add(PrintAttributes.MediaSize.ISO_C3);
        sizes.add(PrintAttributes.MediaSize.ISO_C4);
        sizes.add(PrintAttributes.MediaSize.ISO_C5);
        sizes.add(PrintAttributes.MediaSize.ISO_C6);
        sizes.add(PrintAttributes.MediaSize.ISO_C7);
        sizes.add(PrintAttributes.MediaSize.ISO_C8);
        sizes.add(PrintAttributes.MediaSize.ISO_C9);
        sizes.add(PrintAttributes.MediaSize.ISO_C10);

        // North America
        sizes.add(PrintAttributes.MediaSize.NA_LETTER);
        sizes.add(PrintAttributes.MediaSize.NA_GOVT_LETTER);
        sizes.add(PrintAttributes.MediaSize.NA_LEGAL);
        sizes.add(PrintAttributes.MediaSize.NA_JUNIOR_LEGAL);
        sizes.add(PrintAttributes.MediaSize.NA_LEDGER);
        sizes.add(PrintAttributes.MediaSize.NA_TABLOID);
        sizes.add(PrintAttributes.MediaSize.NA_INDEX_3X5);
        sizes.add(PrintAttributes.MediaSize.NA_INDEX_4X6);
        sizes.add(PrintAttributes.MediaSize.NA_INDEX_5X8);
        sizes.add(PrintAttributes.MediaSize.NA_MONARCH);
        sizes.add(PrintAttributes.MediaSize.NA_QUARTO);
        sizes.add(PrintAttributes.MediaSize.NA_FOOLSCAP);

        // Chinese
        sizes.add(PrintAttributes.MediaSize.ROC_8K);
        sizes.add(PrintAttributes.MediaSize.ROC_16K);
        sizes.add(PrintAttributes.MediaSize.PRC_1);
        sizes.add(PrintAttributes.MediaSize.PRC_2);
        sizes.add(PrintAttributes.MediaSize.PRC_3);
        sizes.add(PrintAttributes.MediaSize.PRC_4);
        sizes.add(PrintAttributes.MediaSize.PRC_5);
        sizes.add(PrintAttributes.MediaSize.PRC_6);
        sizes.add(PrintAttributes.MediaSize.PRC_7);
        sizes.add(PrintAttributes.MediaSize.PRC_8);
        sizes.add(PrintAttributes.MediaSize.PRC_9);
        sizes.add(PrintAttributes.MediaSize.PRC_10);
        sizes.add(PrintAttributes.MediaSize.PRC_16K);
        sizes.add(PrintAttributes.MediaSize.OM_PA_KAI);
        sizes.add(PrintAttributes.MediaSize.OM_DAI_PA_KAI);
        sizes.add(PrintAttributes.MediaSize.OM_JUURO_KU_KAI);

        // Japanese
        sizes.add(PrintAttributes.MediaSize.JIS_B10);
        sizes.add(PrintAttributes.MediaSize.JIS_B9);
        sizes.add(PrintAttributes.MediaSize.JIS_B8);
        sizes.add(PrintAttributes.MediaSize.JIS_B7);
        sizes.add(PrintAttributes.MediaSize.JIS_B6);
        sizes.add(PrintAttributes.MediaSize.JIS_B5);
        sizes.add(PrintAttributes.MediaSize.JIS_B4);
        sizes.add(PrintAttributes.MediaSize.JIS_B3);
        sizes.add(PrintAttributes.MediaSize.JIS_B2);
        sizes.add(PrintAttributes.MediaSize.JIS_B1);
        sizes.add(PrintAttributes.MediaSize.JIS_B0);
        sizes.add(PrintAttributes.MediaSize.JIS_EXEC);
        sizes.add(PrintAttributes.MediaSize.JPN_CHOU4);
        sizes.add(PrintAttributes.MediaSize.JPN_CHOU3);
        sizes.add(PrintAttributes.MediaSize.JPN_CHOU2);
        sizes.add(PrintAttributes.MediaSize.JPN_HAGAKI);
        sizes.add(PrintAttributes.MediaSize.JPN_OUFUKU);
        sizes.add(PrintAttributes.MediaSize.JPN_KAHU);
        sizes.add(PrintAttributes.MediaSize.JPN_KAKU2);
        sizes.add(PrintAttributes.MediaSize.JPN_YOU4);

        return sizes;
    }

    /**
     * End the job because the print framework cancelled it.
     *
     * <p>onLayoutCancelled is reserved for a CancellationSignal cancellation;
     * using it for a failure left the dialog on 'Preparing preview' with no
     * message, because the message was dropped and printJob.cancel() cannot
     * close a job that is still STATE_CREATED.
     */
    void cancelJob(String message) {
        final LayoutResultCallback pending = callback;
        callback = null;
        if (pending != null) {
            pending.onLayoutCancelled();
        }
        if (printJob != null) printJob.cancel();
        reportCompleted(false, message);
    }

    /** End the job because the document could not be produced. */
    void failJob(String message) {
        if (layoutCancelled) {
            // The framework asked for a cancellation first; that is the
            // terminal callback it expects.
            cancelJob(message);
            return;
        }

        final String reported = message != null ? message : "Unable to produce the document";

        final LayoutResultCallback pending = callback;
        callback = null;
        if (pending != null) {
            pending.onLayoutFailed(reported);
        }
        if (printJob != null) printJob.cancel();
        reportCompleted(false, message);
    }

    /**
     * Write the document to the share cache and offer it to the chooser.
     *
     * <p>Returns false instead of reporting success blindly: the caller's
     * Future used to complete with true even when nothing was presented.
     */
    static boolean sharePdf(final Context context, final byte[] data, final String name,
            final String subject, final String body, final ArrayList<String> emails) {
        if (data == null) {
            return false;
        }

        // Defensive basename: the Dart side already does this, but a stale
        // Dart layer must not be able to write outside the share directory.
        final String safeName = new File(name != null ? name : "document.pdf").getName();
        if (safeName.isEmpty()) {
            return false;
        }

        try {
            final File shareDirectory = new File(context.getCacheDir(), "share");
            if (!shareDirectory.exists()) {
                if (!shareDirectory.mkdirs()) {
                    throw new IOException("Unable to create cache directory");
                }
            } else {
                // The URI grant has to outlive this call, so the previous
                // document can only be removed on the next one. deleteOnExit()
                // does not help: Android kills the process without running it.
                final File[] stale = shareDirectory.listFiles();
                if (stale != null) {
                    for (final File file : stale) {
                        if (!file.getName().equals(safeName) && !file.delete()) {
                            Log.w("PDF", "Unable to delete a stale shared file");
                        }
                    }
                }
            }

            File shareFile = new File(shareDirectory, safeName);

            FileOutputStream stream = new FileOutputStream(shareFile);
            stream.write(data);
            stream.close();

            Uri apkURI = FileProvider.getUriForFile(context,
                    context.getApplicationContext().getPackageName() + ".flutter.printing",
                    shareFile);

            Intent shareIntent = new Intent();
            shareIntent.setAction(Intent.ACTION_SEND);
            shareIntent.setType("application/pdf");
            shareIntent.putExtra(Intent.EXTRA_STREAM, apkURI);
            shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            shareIntent.putExtra(Intent.EXTRA_SUBJECT, subject);
            shareIntent.putExtra(Intent.EXTRA_TEXT, body);
            shareIntent.putExtra(
                    Intent.EXTRA_EMAIL, emails != null ? emails.toArray(new String[0]) : null);
            Intent chooserIntent = Intent.createChooser(shareIntent, null);
            if (!(context instanceof Activity)) {
                // startActivity on a non-Activity context needs its own task,
                // and threw an AndroidRuntimeException without it, so sharing
                // from a background or cached engine opened nothing.
                chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            }
            List<ResolveInfo> resInfoList = context.getPackageManager().queryIntentActivities(
                    chooserIntent, PackageManager.MATCH_DEFAULT_ONLY);

            for (ResolveInfo resolveInfo : resInfoList) {
                String packageName = resolveInfo.activityInfo.packageName;
                // Read is all a share needs; write let every matching app
                // modify the document.
                context.grantUriPermission(
                        packageName, apkURI, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
            context.startActivity(chooserIntent);
            shareFile.deleteOnExit();
            return true;
        } catch (IOException e) {
            Log.e("PDF", "Unable to share the document", e);
            return false;
        } catch (RuntimeException e) {
            // IllegalArgumentException from the FileProvider,
            // ActivityNotFoundException and AndroidRuntimeException from the
            // chooser: none of them should cross the channel raw.
            Log.e("PDF", "Unable to share the document", e);
            return false;
        }
    }

    void convertHtml(final String data, final PrintAttributes.MediaSize size,
            final PrintAttributes.Margins margins, final String baseUrl) {
        Configuration configuration = context.getResources().getConfiguration();
        configuration.fontScale = (float) 1;
        Context webContext = context.createConfigurationContext(configuration);
        // Held in a field rather than a local: nothing else keeps the WebView
        // or its adapter alive for the length of the conversion, and nothing
        // used to destroy them afterwards.
        htmlDone = false;
        final WebView webView = new WebView(webContext);
        htmlWebView = webView;

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
                        htmlAdapter = adapter;

                        PdfConvert.print(context, adapter, attributes, new PdfConvert.Result() {
                            @Override
                            public void onSuccess(File file) {
                                try {
                                    byte[] fileContent = PdfConvert.readFile(file);
                                    printing.onHtmlRendered(PrintingJob.this, fileContent);
                                } catch (IOException e) {
                                    printing.onHtmlError(PrintingJob.this, e.getMessage());
                                }
                                finishHtmlJob();
                            }

                            @Override
                            public void onError(String message) {
                                printing.onHtmlError(PrintingJob.this, message);
                                finishHtmlJob();
                            }
                        });
                    }
                }
            }
        });
    }

    /// Release the WebView used by convertHtml, exactly once.
    ///
    /// Posted to the main looper on purpose: the result callbacks run inside a
    /// Chromium callback stack, and destroying the WebView re-entrantly from
    /// there crashes the renderer. WebView also demands the UI thread.
    private void finishHtmlJob() {
        if (htmlDone) {
            return;
        }
        htmlDone = true;

        new Handler(Looper.getMainLooper()).post(() -> {
            // PdfConvert already called onFinish() on the adapter.
            htmlAdapter = null;

            final WebView webView = htmlWebView;
            htmlWebView = null;
            if (webView != null) {
                webView.stopLoading();
                webView.setWebViewClient(new WebViewClient());
                webView.destroy();
            }
        });
    }

    void setDocument(byte[] data) {
        documentData = data;

        final LayoutResultCallback pending = callback;
        if (pending == null) {
            // The layout already ended - cancelled, or failed - so a second
            // terminal callback would be a framework violation, and reading
            // the null callback was a NullPointerException.
            return;
        }
        callback = null;

        PrintDocumentInfo info = new PrintDocumentInfo.Builder(jobName)
                                         .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                                         .build();

        // Content layout reflow is complete
        pending.onLayoutFinished(info, true);
    }

    void rasterPdf(final byte[] data, final ArrayList<Integer> pages, final Double scale) {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.LOLLIPOP) {
            printing.onPageRasterEnd(
                    this, "PDF Raster available since Android 5.0 Lollipop (API 21)");
            return;
        }

        Thread thread = new Thread(() -> {
            String error = null;
            try {
                File tempDir = context.getCacheDir();
                File file = File.createTempFile("printing", null, tempDir);
                FileOutputStream oStream = new FileOutputStream(file);
                oStream.write(data);
                oStream.close();

                FileInputStream iStream = new FileInputStream(file);
                ParcelFileDescriptor parcelFD = ParcelFileDescriptor.dup(iStream.getFD());
                PdfRenderer renderer = new PdfRenderer(parcelFD);

                if (!file.delete()) {
                    Log.e("PDF", "Unable to delete temporary file");
                }

                final int pageCount = pages != null ? pages.size() : renderer.getPageCount();
                for (int i = 0; i < pageCount; i++) {
                    PdfRenderer.Page page = renderer.openPage(pages == null ? i : pages.get(i));

                    final int width = Double.valueOf(page.getWidth() * scale).intValue();
                    final int height = Double.valueOf(page.getHeight() * scale).intValue();
                    int stride = width * 4;

                    Matrix transform = new Matrix();
                    transform.setScale(scale.floatValue(), scale.floatValue());

                    Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);

                    page.render(bitmap, null, transform, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);

                    page.close();

                    final ByteBuffer buf = ByteBuffer.allocate(stride * height);
                    bitmap.copyPixelsToBuffer(buf);
                    bitmap.recycle();

                    new Handler(Looper.getMainLooper())
                            .post(()
                                            -> printing.onPageRasterized(
                                                    PrintingJob.this, buf.array(), width, height));
                }

                renderer.close();
                iStream.close();

            } catch (IOException e) {
                e.printStackTrace();
                error = e.getMessage();
            }

            final String finalError = error;
            new Handler(Looper.getMainLooper())
                    .post(() -> printing.onPageRasterEnd(PrintingJob.this, finalError));
        });

        thread.setUncaughtExceptionHandler((t, e) -> {
            final String finalError = e.getMessage();
            new Handler(Looper.getMainLooper())
                    .post(() -> printing.onPageRasterEnd(PrintingJob.this, finalError));
        });

        thread.start();
    }

    /// Convert PDF points to mils, clamped to what an int media size can hold.
    ///
    /// Returns 0 for a value that is not finite - a roll format carries
    /// infinity - or that does not fit, so the caller can treat that axis as
    /// unspecified instead of using a wrapped number.
    private static long pointsToMils(double points) {
        if (Double.isNaN(points) || Double.isInfinite(points) || points <= 0) {
            return 0;
        }
        final double mils = points * 1000.0 / 72.0;
        if (mils < 1 || mils > Integer.MAX_VALUE) {
            return 0;
        }
        return (long) mils;
    }
}
