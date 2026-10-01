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

import static java.util.Collections.singletonList;
import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;

import android.print.PageRange;
import android.print.RecordingCallbacks;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;

import org.junit.Test;

/**
 * android.print requires exactly one of onWriteFinished, onWriteFailed or
 * onWriteCancelled per onWrite, and has no timeout. The copy used to report
 * onWriteFinished only as the last statement of its try block and the catch only
 * printed a stack trace, so a failed write left no terminal callback: the
 * preview sat on 'Preparing preview' and Printing.layoutPdf never returned.
 */
public class PrintingJobWriteTest {
    private static final byte[] document = new byte[] {1, 2, 3, 4};

    private PrintingJob jobWithDocument() {
        final PrintingJob job = new PrintingJob(null, null, 1);
        job.setDocument(document);
        return job;
    }

    @Test
    public void aSuccessfulWriteReportsFinishedOnce() {
        final ByteArrayOutputStream output = new ByteArrayOutputStream();
        final RecordingCallbacks.Write callback = new RecordingCallbacks.Write();

        jobWithDocument().writeDocument(output, callback);

        assertEquals(singletonList("finished"), callback.calls);
        assertArrayEquals(new PageRange[] {PageRange.ALL_PAGES}, callback.pages);
        assertArrayEquals(document, output.toByteArray());
    }

    @Test
    public void aFailedWriteReportsFailedOnceWithAMessage() {
        // What a full disk, or a descriptor the spooler closed when the dialog
        // was dismissed, looks like from here.
        final OutputStream output = new OutputStream() {
            @Override
            public void write(int b) throws IOException {
                throw new IOException("No space left on device");
            }

            @Override
            public void write(byte[] b, int off, int len) throws IOException {
                throw new IOException("No space left on device");
            }
        };
        final RecordingCallbacks.Write callback = new RecordingCallbacks.Write();

        jobWithDocument().writeDocument(output, callback);

        assertEquals(singletonList("failed"), callback.calls);
        assertEquals("No space left on device", callback.error);
    }

    @Test
    public void aFailureWithNoMessageStillReportsOne() {
        final OutputStream output = new OutputStream() {
            @Override
            public void write(int b) throws IOException {
                throw new IOException();
            }

            @Override
            public void write(byte[] b, int off, int len) throws IOException {
                throw new IOException();
            }
        };
        final RecordingCallbacks.Write callback = new RecordingCallbacks.Write();

        jobWithDocument().writeDocument(output, callback);

        assertEquals(singletonList("failed"), callback.calls);
        assertNotNull("the framework needs a message, not null", callback.error);
    }

    @Test
    public void aFailureWhileClosingIsStillOneResult() {
        // close() throwing after a successful write must not turn into a
        // second callback.
        final OutputStream output = new OutputStream() {
            @Override
            public void write(int b) {}

            @Override
            public void write(byte[] b, int off, int len) {}

            @Override
            public void close() throws IOException {
                throw new IOException("cannot close");
            }
        };
        final RecordingCallbacks.Write callback = new RecordingCallbacks.Write();

        jobWithDocument().writeDocument(output, callback);

        assertEquals(1, callback.calls.size());
    }
}
