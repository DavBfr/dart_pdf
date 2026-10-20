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

@RequiresApi(api = Build.VERSION_CODES.KITKAT)
public class PdfConvert {
    public static void print(final Context context, final PrintDocumentAdapter adapter,
            final PrintAttributes attributes, final Result result) {
        adapter.onLayout(null, attributes, null, new PrintDocumentAdapter.LayoutResultCallback() {
            @Override
            public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
                File outputDir = context.getCacheDir();
                File outputFile;
                try {
                    outputFile = File.createTempFile("printing", "pdf", outputDir);
                } catch (IOException e) {
                    result.onError(e.getMessage());
                    return;
                }

                final ParcelFileDescriptor descriptor;
                try {
                    descriptor = ParcelFileDescriptor.open(
                            outputFile, ParcelFileDescriptor.MODE_READ_WRITE);
                } catch (FileNotFoundException e) {
                    delete(outputFile);
                    result.onError(e.getMessage());
                    return;
                }

                final File finalOutputFile = outputFile;
                adapter.onWrite(new PageRange[] {PageRange.ALL_PAGES}, descriptor,
                        new CancellationSignal(), new PrintDocumentAdapter.WriteResultCallback() {
                            @Override
                            public void onWriteFinished(PageRange[] pages) {
                                super.onWriteFinished(pages);
                                close(descriptor);

                                if (pages.length == 0) {
                                    delete(finalOutputFile);
                                    result.onError("No page created");
                                    return;
                                }

                                result.onSuccess(finalOutputFile);
                                delete(finalOutputFile);
                            }

                            // Without these, a failed or cancelled write never
                            // answered, and the Dart future waited forever.
                            @Override
                            public void onWriteFailed(CharSequence error) {
                                super.onWriteFailed(error);
                                close(descriptor);
                                delete(finalOutputFile);
                                result.onError(error != null ? error.toString() : "Write failed");
                            }

                            @Override
                            public void onWriteCancelled() {
                                super.onWriteCancelled();
                                close(descriptor);
                                delete(finalOutputFile);
                                result.onError("Write cancelled");
                            }
                        });
            }

            @Override
            public void onLayoutFailed(CharSequence error) {
                super.onLayoutFailed(error);
                result.onError(error != null ? error.toString() : "Layout failed");
            }

            @Override
            public void onLayoutCancelled() {
                super.onLayoutCancelled();
                result.onError("Layout cancelled");
            }
        }, null);
    }

    private static void close(ParcelFileDescriptor descriptor) {
        try {
            descriptor.close();
        } catch (IOException e) {
            Log.e("PDF", "Unable to close temporary file");
        }
    }

    private static void delete(File file) {
        if (file.exists() && !file.delete()) {
            Log.e("PDF", "Unable to delete temporary file");
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
