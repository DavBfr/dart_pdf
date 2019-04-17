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

import android.app.Activity;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;

public class PdfConvert {
    public static void print(final Activity activity, final PrintDocumentAdapter adapter,
            final PrintAttributes attributes, final Result result) {
        adapter.onLayout(null, attributes, null, new PrintDocumentAdapter.LayoutResultCallback() {
            @Override
            public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
                File outputDir = activity.getCacheDir();
                File outputFile = null;
                try {
                    outputFile = File.createTempFile("printing", "pdf", outputDir);
                } catch (IOException e) {
                    outputFile.delete();
                    result.onError(e.getMessage());
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
                                        finalOutputFile.delete();
                                        result.onError("No page created");
                                    }

                                    result.onSuccess(finalOutputFile);
                                    finalOutputFile.delete();
                                }
                            });
                } catch (FileNotFoundException e) {
                    outputFile.delete();
                    result.onError(e.getMessage());
                }
            }
        }, null);
    }

    public static byte[] readFile(File file) throws IOException {
        byte[] buffer = new byte[(int) file.length()];
        InputStream ios = null;
        try {
            ios = new FileInputStream(file);
            if (ios.read(buffer) == -1) {
                throw new IOException("EOF reached while trying to read the whole file");
            }
        } finally {
            try {
                if (ios != null) ios.close();
            } catch (IOException e) {
            }
        }
        return buffer;
    }

    public interface Result {
        void onSuccess(File file);

        void onError(String message);
    }
}
