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

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.io.Closeable;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.junit.Test;

/**
 * The raster path takes a temp file, two streams, a dup'ed descriptor and a
 * native PdfRenderer, and used to release them only by straight-line statements
 * on the success path. A password-protected or truncated document throws from
 * the PdfRenderer constructor, which nothing caught, so every one of them
 * leaked - and the temp file was deleted on the line after that constructor, so
 * it survived for ever exactly when the constructor threw.
 *
 * <p>closeQuietly is the primitive that makes the teardown safe: one handle
 * refusing to close must not stop the others from being released.
 */
public class PrintingJobRasterTest {
    private static final class Handle implements Closeable {
        Handle(boolean failing) {
            this.failing = failing;
        }

        private final boolean failing;
        boolean closed;

        @Override
        public void close() throws IOException {
            closed = true;
            if (failing) {
                throw new IOException("refuses to close");
            }
        }
    }

    @Test
    public void closesAHandle() {
        final Handle handle = new Handle(false);

        PrintingJob.closeQuietly(handle);

        assertTrue(handle.closed);
    }

    @Test
    public void toleratesNoHandleAtAll() {
        // Every local is null until its step of the setup has run, and the
        // teardown runs however far it got.
        PrintingJob.closeQuietly(null);
    }

    @Test
    public void swallowsAFailureToClose() {
        final Handle handle = new Handle(true);

        PrintingJob.closeQuietly(handle);

        assertTrue(handle.closed);
    }

    @Test
    public void oneFailureDoesNotSkipTheRest() {
        final List<Handle> handles = new ArrayList<>();
        handles.add(new Handle(true));
        handles.add(new Handle(true));
        handles.add(new Handle(false));

        for (final Handle handle : handles) {
            PrintingJob.closeQuietly(handle);
        }

        int closed = 0;
        for (final Handle handle : handles) {
            if (handle.closed) {
                closed++;
            }
        }
        assertEquals(handles.size(), closed);
    }

    @Test
    public void ignoresSomethingThatIsNotCloseable() {
        PrintingJob.closeQuietly("not a handle");
    }
}
