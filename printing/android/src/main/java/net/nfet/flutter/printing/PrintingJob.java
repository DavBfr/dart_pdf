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
import java.util.HashMap;

/**
 * PrintJob
 */
public class PrintingJob extends PrintDocumentAdapter {
    private static PrintManager printManager;
    private final Context context;
    private final PrintingPlugin printing;
    private PrintJob printJob;
    private byte[] documentData;
    private String jobName;
    private LayoutResultCallback callback;
    int index;

    PrintingJob(Context context, PrintingPlugin printing, int index) {
        this.context = context;
        this.printing = printing;
        this.index = index;
        printManager = (PrintManager) context.getSystemService(Context.PRINT_SERVICE);
    }

    static HashMap<String, Object> printingInfo() {
        HashMap<String, Object> result = new HashMap<>();
        result.put("directPrint", false);
        result.put("dynamicLayout", true);
        result.put("canPrint", true);
        result.put("canConvertHtml", true);
        result.put("canShare", true);
        result.put("canRaster", true);
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
        try {
            while (true) {
                int state = printJob.getInfo().getState();

                if (state == PrintJobInfo.STATE_COMPLETED) {
                    printing.onCompleted(this, true, "");
                    break;
                } else if (state == PrintJobInfo.STATE_CANCELED) {
                    printing.onCompleted(this, false, "User canceled");
                    break;
                }

                Thread.sleep(200);
            }
        } catch (Exception e) {
            printing.onCompleted(this, printJob != null && printJob.isCompleted(), e.getMessage());
        }

        printJob = null;
    }

    void printPdf(@NonNull String name, Double width, Double height, Double marginLeft,
            Double marginTop, Double marginRight, Double marginBottom) {
        jobName = name;
        printJob = printManager.print(name, this, null);
    }

    void cancelJob() {
        if (callback != null) callback.onLayoutCancelled();
        if (printJob != null) printJob.cancel();
    }

    static void sharePdf(final Context context, final byte[] data, final String name) {
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
            Intent chooserIntent = Intent.createChooser(shareIntent, null);
            context.startActivity(chooserIntent);
            shareFile.deleteOnExit();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    void convertHtml(final String data, final PrintAttributes.MediaSize size,
            final PrintAttributes.Margins margins, final String baseUrl) {
        final WebView webView = new WebView(context.getApplicationContext());

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

        PrintDocumentInfo info = new PrintDocumentInfo.Builder(jobName + ".pdf")
                                         .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                                         .build();

        // Content layout reflow is complete
        callback.onLayoutFinished(info, true);
    }

    void rasterPdf(final byte[] data, final int[] pages, final Double scale) {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.LOLLIPOP) {
            Log.e("PDF", "PDF Raster available since Android 5.0 Lollipop (API 21)");
            printing.onPageRasterEnd(this);
            return;
        }

        Thread thread = new Thread(new Runnable() {
            @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
            @Override
            public void run() {
                try {
                    File file = File.createTempFile("printing", null, null);
                    FileOutputStream oStream = new FileOutputStream(file);
                    oStream.write(data);
                    oStream.close();

                    FileInputStream iStream = new FileInputStream(file);
                    ParcelFileDescriptor parcelFD = ParcelFileDescriptor.dup(iStream.getFD());
                    PdfRenderer renderer = new PdfRenderer(parcelFD);

                    if (!file.delete()) {
                        Log.e("PDF", "Unable to delete temporary file");
                    }

                    final int pageCount = pages != null ? pages.length : renderer.getPageCount();
                    for (int i = 0; i < pageCount; i++) {
                        PdfRenderer.Page page = renderer.openPage(pages == null ? i : pages[i]);

                        final int width = Double.valueOf(page.getWidth() * scale).intValue();
                        final int height = Double.valueOf(page.getHeight() * scale).intValue();
                        int stride = width * 4;

                        Matrix transform = new Matrix();
                        transform.setScale(scale.floatValue(), scale.floatValue());

                        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);

                        page.render(
                                bitmap, null, transform, PdfRenderer.Page.RENDER_MODE_FOR_PRINT);

                        page.close();

                        final ByteBuffer buf = ByteBuffer.allocate(stride * height);
                        bitmap.copyPixelsToBuffer(buf);
                        bitmap.recycle();

                        new Handler(Looper.getMainLooper()).post(new Runnable() {
                            @Override
                            public void run() {
                                printing.onPageRasterized(
                                        PrintingJob.this, buf.array(), width, height);
                            }
                        });
                    }

                    renderer.close();
                    iStream.close();

                } catch (IOException e) {
                    e.printStackTrace();
                }

                new Handler(Looper.getMainLooper()).post(new Runnable() {
                    @Override
                    public void run() {
                        printing.onPageRasterEnd(PrintingJob.this);
                    }
                });
            }
        });

        thread.start();
    }
}
