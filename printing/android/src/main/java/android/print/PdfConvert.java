/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 * ... (License Header same as original) ...
 */

package android.print;

import android.content.Context;
import android.os.Build;
import android.os.CancellationSignal;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import androidx.annotation.RequiresApi;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;

@RequiresApi(api = Build.VERSION_CODES.KITKAT)
public class PdfConvert {
    private static final String TAG = "PdfConvert";

    public static void print(final Context context, final PrintDocumentAdapter adapter,
            final PrintAttributes attributes, final Result result) {
        
        // 1. Setup Timeout Handler (Safety Net)
        final Handler mainHandler = new Handler(Looper.getMainLooper());
        final CancellationSignal cancellationSignal = new CancellationSignal();
        
        // Agar 20 second mein kaam nahi hua, toh Fail karo!
        final Runnable timeoutRunnable = new Runnable() {
            @Override
            public void run() {
                Log.e(TAG, "Print Timeout: System took too long.");
                cancellationSignal.cancel();
                result.onError("TIMEOUT: Print Service stuck for >20s");
            }
        };
        mainHandler.postDelayed(timeoutRunnable, 20000); // 20 Seconds Timeout

        // Start Layout
        adapter.onLayout(null, attributes, cancellationSignal, new PrintDocumentAdapter.LayoutResultCallback() {
            @Override
            public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
                File outputDir = context.getCacheDir();
                File outputFile;
                try {
                    outputFile = File.createTempFile("printing", "pdf", outputDir);
                } catch (IOException e) {
                    mainHandler.removeCallbacks(timeoutRunnable); // Stop timer
                    result.onError(e.getMessage());
                    return;
                }

                try {
                    final File finalOutputFile = outputFile;
                    // Start Write
                    adapter.onWrite(new PageRange[] {PageRange.ALL_PAGES},
                            ParcelFileDescriptor.open(
                                    outputFile, ParcelFileDescriptor.MODE_READ_WRITE),
                            cancellationSignal,
                            new PrintDocumentAdapter.WriteResultCallback() {
                                @Override
                                public void onWriteFinished(PageRange[] pages) {
                                    mainHandler.removeCallbacks(timeoutRunnable); // ✅ SUCCESS: Stop timer
                                    super.onWriteFinished(pages);

                                    if (pages.length == 0) {
                                        if (!finalOutputFile.delete()) {
                                            Log.e(TAG, "Unable to delete temporary file");
                                        }
                                        result.onError("No page created");
                                    } else {
                                        result.onSuccess(finalOutputFile);
                                    }
                                    
                                    // Cleanup happens in onSuccess handling usually, but good practice to close things
                                }

                                @Override
                                public void onWriteFailed(CharSequence error) {
                                    mainHandler.removeCallbacks(timeoutRunnable); // 🛑 FAIL: Stop timer
                                    super.onWriteFailed(error);
                                    result.onError("Write Failed: " + error.toString());
                                }

                                @Override
                                public void onWriteCancelled() {
                                    mainHandler.removeCallbacks(timeoutRunnable);
                                    super.onWriteCancelled();
                                    result.onError("Write Cancelled");
                                }
                            });
                } catch (FileNotFoundException e) {
                    mainHandler.removeCallbacks(timeoutRunnable);
                    if (!outputFile.delete()) {
                        Log.e(TAG, "Unable to delete temporary file");
                    }
                    result.onError(e.getMessage());
                }
            }

            @Override
            public void onLayoutFailed(CharSequence error) {
                mainHandler.removeCallbacks(timeoutRunnable); // 🛑 FAIL: Stop timer
                super.onLayoutFailed(error);
                result.onError("Layout Failed: " + error.toString());
            }

            @Override
            public void onLayoutCancelled() {
                mainHandler.removeCallbacks(timeoutRunnable);
                super.onLayoutCancelled();
                result.onError("Layout Cancelled");
            }
        }, null);
    }

    public static byte[] readFile(File file) throws IOException {
        byte[] buffer = new byte[(int) file.length()];
        try (InputStream ios = new FileInputStream(file)) {
            if (ios.read(buffer) == -1) {
                throw new IOException("EOF reached while trying to read the whole file");
            }
        }
        return buffer;
    }

    public interface Result {
        void onSuccess(File file);
        void onError(String message);
    }
}
