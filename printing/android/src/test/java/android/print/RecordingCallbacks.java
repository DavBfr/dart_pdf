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

import java.util.ArrayList;
import java.util.List;

/**
 * Recording doubles for the print framework's result callbacks.
 *
 * <p>Both callback classes have package-private constructors, so a double has to
 * live in android.print. That is the whole reason for this file's package.
 */
public final class RecordingCallbacks {
    private RecordingCallbacks() {}

    /** Records which terminal method the adapter called, and how often. */
    public static final class Write extends PrintDocumentAdapter.WriteResultCallback {
        public final List<String> calls = new ArrayList<>();
        public PageRange[] pages;
        public CharSequence error;

        @Override
        public void onWriteFinished(PageRange[] pages) {
            calls.add("finished");
            this.pages = pages;
        }

        @Override
        public void onWriteFailed(CharSequence error) {
            calls.add("failed");
            this.error = error;
        }

        @Override
        public void onWriteCancelled() {
            calls.add("cancelled");
        }
    }

    /** The same, for the layout phase. */
    public static final class Layout extends PrintDocumentAdapter.LayoutResultCallback {
        public final List<String> calls = new ArrayList<>();
        public CharSequence error;

        @Override
        public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
            calls.add("finished");
        }

        @Override
        public void onLayoutFailed(CharSequence error) {
            calls.add("failed");
            this.error = error;
        }

        @Override
        public void onLayoutCancelled() {
            calls.add("cancelled");
        }
    }
}
