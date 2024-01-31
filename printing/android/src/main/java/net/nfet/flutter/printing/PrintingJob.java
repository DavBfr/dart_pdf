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
    private static PrintManager printManager;
    private final Context context;
    private final PrintingHandler printing;
    private PrintJob printJob;
    private byte[] documentData;
    private String jobName;
    private LayoutResultCallback callback;
    int index;

    PrintingJob(Context context, PrintingHandler printing, int index) {
        this.context = context;
        this.printing = printing;
        this.index = index;
        printManager = (PrintManager) context.getSystemService(Context.PRINT_SERVICE);
    }

    static HashMap<String, Object> printingInfo() {
        final boolean canPrint = android.os.Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT;
        final boolean canRaster = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP;

        HashMap<String, Object> result = new HashMap<>();
        result.put("directPrint", false);
        result.put("dynamicLayout", canPrint);
        result.put("canPrint", canPrint);
        result.put("canConvertHtml", canRaster);
        result.put("canShare", true);
        result.put("canRaster", canRaster);
        return result;
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
        // Respond to cancellation request
        if (cancellationSignal.isCanceled()) {
            callback.onLayoutCancelled();
            return;
        }

        this.callback = callback;

        PrintAttributes.MediaSize size = newAttributes.getMediaSize();
        PrintAttributes.Margins margins = newAttributes.getMinMargins();
        assert size != null;
        assert margins != null;

        printing.onLayout(this, size.getWidthMils() * 72.0 / 1000.0,
                size.getHeightMils() * 72.0 / 1000.0, margins.getLeftMils() * 72.0 / 1000.0,
                margins.getTopMils() * 72.0 / 1000.0, margins.getRightMils() * 72.0 / 1000.0,
                margins.getBottomMils() * 72.0 / 1000.0);
    }

    @Override
    public void onFinish() {
        Thread thread = new Thread(() -> {
            try {
                final boolean[] wait = {true};
                int count = 5 * 60 * 10; // That's 10 minutes.
                while (wait[0]) {
                    new Handler(Looper.getMainLooper()).post(() -> {
                        int state = printJob == null ? PrintJobInfo.STATE_FAILED
                                                     : printJob.getInfo().getState();

                        if (state == PrintJobInfo.STATE_COMPLETED) {
                            printing.onCompleted(PrintingJob.this, true, null);
                            wait[0] = false;
                        } else if (state == PrintJobInfo.STATE_CANCELED) {
                            printing.onCompleted(PrintingJob.this, false, null);
                            wait[0] = false;
                        } else if (state == PrintJobInfo.STATE_FAILED) {
                            printing.onCompleted(PrintingJob.this, false, "Unable to print");
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
                                        -> printing.onCompleted(PrintingJob.this,
                                                printJob != null && printJob.isCompleted(),
                                                e.getMessage()));
            }

            printJob = null;
        });

        thread.start();
    }

    void printPdf(@NonNull String name, @NonNull Double width, @NonNull Double height) {
        jobName = name;

        PrintAttributes.Builder attrBuilder = new PrintAttributes.Builder();

        int widthMils = Double.valueOf(width * 1000.0 / 72.0).intValue();
        int heightMils = Double.valueOf(height * 1000.0 / 72.0).intValue();

        PrintAttributes.MediaSize mediaSize = null;
        boolean isPortrait = heightMils >= widthMils;

        // get the media size from predefined media sizes
        for (PrintAttributes.MediaSize size : getAllPredefinedSizes()) {
            // https://github.com/DavBfr/dart_pdf/issues/635
            int err = 20;
            PrintAttributes.MediaSize m = isPortrait ? size.asPortrait() : size.asLandscape();
            if ((widthMils + err) >= m.getWidthMils() && (widthMils - err) <= m.getWidthMils()
                    && (heightMils + err) >= m.getHeightMils()
                    && (heightMils - err) <= m.getHeightMils()) {
                mediaSize = m;
                break;
            }
        }

        if (mediaSize == null) {
            mediaSize = isPortrait ? PrintAttributes.MediaSize.UNKNOWN_PORTRAIT
                                   : PrintAttributes.MediaSize.UNKNOWN_LANDSCAPE;
        }

        attrBuilder.setMediaSize(mediaSize);
        PrintAttributes attrib = attrBuilder.build();
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

    void cancelJob(String message) {
        if (callback != null) callback.onLayoutCancelled();
        if (printJob != null) printJob.cancel();
        printing.onCompleted(PrintingJob.this, false, message);
    }

    static void sharePdf(final Context context, final byte[] data, final String name,
            final String subject, final String body, final ArrayList<String> emails) {
        assert name != null;

        try {
            final File shareDirectory = new File(context.getCacheDir(), "share");
            if (!shareDirectory.exists()) {
                if (!shareDirectory.mkdirs()) {
                    throw new IOException("Unable to create cache directory");
                }
            }

            File shareFile = new File(shareDirectory, name);

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
            List<ResolveInfo> resInfoList = context.getPackageManager().queryIntentActivities(
                    chooserIntent, PackageManager.MATCH_DEFAULT_ONLY);

            for (ResolveInfo resolveInfo : resInfoList) {
                String packageName = resolveInfo.activityInfo.packageName;
                context.grantUriPermission(packageName, apkURI,
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                                | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
            context.startActivity(chooserIntent);
            shareFile.deleteOnExit();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    void convertHtml(final String data, final PrintAttributes.MediaSize size,
            final PrintAttributes.Margins margins, final String baseUrl) {
        Configuration configuration = context.getResources().getConfiguration();
        configuration.fontScale = (float) 1;
        Context webContext = context.createConfigurationContext(configuration);
        final WebView webView = new WebView(webContext);

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

                        PdfConvert.print(context, adapter, attributes, new PdfConvert.Result() {
                            @Override
                            public void onSuccess(File file) {
                                try {
                                    byte[] fileContent = PdfConvert.readFile(file);
                                    printing.onHtmlRendered(PrintingJob.this, fileContent);
                                } catch (IOException e) {
                                    onError(e.getMessage());
                                }
                            }

                            @Override
                            public void onError(String message) {
                                printing.onHtmlError(PrintingJob.this, message);
                            }
                        });
                    }
                }
            }
        });
    }

    void setDocument(byte[] data) {
        documentData = data;

        PrintDocumentInfo info = new PrintDocumentInfo.Builder(jobName)
                                         .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                                         .build();

        // Content layout reflow is complete
        callback.onLayoutFinished(info, true);
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
}
