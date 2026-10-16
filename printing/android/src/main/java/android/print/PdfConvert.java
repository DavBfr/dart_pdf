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

package android.print;

import android.content.Context;
import android.os.Build;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import androidx.annotation.RequiresApi;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.atomic.AtomicBoolean;

@RequiresApi(api = Build.VERSION_CODES.KITKAT)
public class PdfConvert {
    public static void print(final Context context, final PrintDocumentAdapter adapter,
            final PrintAttributes attributes, final Result result) {
        // Every callback below may fire, or not fire, independently: the print
        // adapter reports failure and cancellation through separate methods,
        // and the zero-page path used to report both an error and a success.
        // The wrapper makes the contract 'exactly one result, then onFinish'.
        final SingleResult once = new SingleResult(adapter, result);

        adapter.onStart();
        adapter.onLayout(null, attributes, null, new PrintDocumentAdapter.LayoutResultCallback() {
            @Override
            public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
                File outputDir = context.getCacheDir();
                File outputFile;
                try {
                    outputFile = File.createTempFile("printing", "pdf", outputDir);
                } catch (IOException e) {
                    once.onError(e.getMessage());
                    return;
                }

                try {
                    final File finalOutputFile = outputFile;
                    adapter.onWrite(new PageRange[] {PageRange.ALL_PAGES},
                            ParcelFileDescriptor.open(
                                    outputFile, ParcelFileDescriptor.MODE_READ_WRITE),
                            new CancellationSignal(),
                            new PrintDocumentAdapter.WriteResultCallback() {
                                @Override
                                public void onWriteFinished(PageRange[] pages) {
                                    super.onWriteFinished(pages);

                                    if (pages.length == 0) {
                                        deleteQuietly(finalOutputFile);
                                        once.onError("No page created");
                                        return;
                                    }

                                    once.onSuccess(finalOutputFile);
                                    deleteQuietly(finalOutputFile);
                                }

                                @Override
                                public void onWriteFailed(CharSequence error) {
                                    super.onWriteFailed(error);
                                    deleteQuietly(finalOutputFile);
                                    once.onError(error != null ? error.toString() : "Write failed");
                                }

                                @Override
                                public void onWriteCancelled() {
                                    super.onWriteCancelled();
                                    deleteQuietly(finalOutputFile);
                                    once.onError("Write cancelled");
                                }
                            });
                } catch (FileNotFoundException e) {
                    deleteQuietly(outputFile);
                    once.onError(e.getMessage());
                }
            }

            @Override
            public void onLayoutFailed(CharSequence error) {
                super.onLayoutFailed(error);
                once.onError(error != null ? error.toString() : "Layout failed");
            }

            @Override
            public void onLayoutCancelled() {
                super.onLayoutCancelled();
                once.onError("Layout cancelled");
            }
        }, null);
    }

    private static void deleteQuietly(File file) {
        if (file.exists() && !file.delete()) {
            Log.e("PDF", "Unable to delete temporary file");
        }
    }

    /// Delivers at most one result and finishes the adapter exactly once.
    private static final class SingleResult implements Result {
        private final PrintDocumentAdapter adapter;
        private final Result delegate;
        private final AtomicBoolean done = new AtomicBoolean(false);

        SingleResult(PrintDocumentAdapter adapter, Result delegate) {
            this.adapter = adapter;
            this.delegate = delegate;
        }

        @Override
        public void onSuccess(File file) {
            if (!done.compareAndSet(false, true)) {
                Log.w("PDF", "Ignoring a duplicate conversion result");
                return;
            }
            try {
                delegate.onSuccess(file);
            } finally {
                finish();
            }
        }

        @Override
        public void onError(String message) {
            if (!done.compareAndSet(false, true)) {
                Log.w("PDF", "Ignoring a duplicate conversion result: " + message);
                return;
            }
            try {
                delegate.onError(message);
            } finally {
                finish();
            }
        }

        private void finish() {
            // The adapter contract requires this so it can release whatever
            // onLayout and onWrite allocated.
            try {
                adapter.onFinish();
            } catch (Exception e) {
                Log.e("PDF", "Unable to finish the print document adapter", e);
            }
        }
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
