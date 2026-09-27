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

import static java.util.Arrays.asList;
import static java.util.Collections.singletonList;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;

import android.print.RecordingCallbacks;

import java.util.ArrayList;
import java.util.List;

import org.junit.Test;

/**
 * onLayoutCancelled is reserved for a CancellationSignal cancellation. Reporting
 * a Dart-side failure with it dropped the message and left the system print
 * dialog on 'Preparing preview', because printJob.cancel() cannot close a job
 * that is still STATE_CREATED.
 */
public class PrintingJobLayoutFailureTest {
    /** Records what the job reports back to Dart. */
    private static final class RecordingHandler extends PrintingHandler {
        final List<String> completions = new ArrayList<>();

        RecordingHandler() {
            super(null, null);
        }

        @Override
        void onCompleted(PrintingJob printJob, boolean completed, String error) {
            completions.add(completed + ":" + error);
        }
    }

    private PrintingJob jobAwaitingLayout(
            RecordingHandler handler, RecordingCallbacks.Layout callback) {
        final PrintingJob job = new PrintingJob(null, handler, 1);
        // What onLayout does before it asks Dart for the document.
        job.callback = callback;
        return job;
    }

    @Test
    public void aFailureIsReportedAsAFailure() {
        final RecordingHandler handler = new RecordingHandler();
        final RecordingCallbacks.Layout callback = new RecordingCallbacks.Layout();

        jobAwaitingLayout(handler, callback).failJob("no document");

        assertEquals(singletonList("failed"), callback.calls);
        assertEquals("no document", callback.error);
        assertEquals(singletonList("false:no document"), handler.completions);
    }

    @Test
    public void aFailureWithNoMessageStillGetsOne() {
        final RecordingHandler handler = new RecordingHandler();
        final RecordingCallbacks.Layout callback = new RecordingCallbacks.Layout();

        jobAwaitingLayout(handler, callback).failJob(null);

        assertEquals(singletonList("failed"), callback.calls);
        assertNotNull("onLayoutFailed needs a message", callback.error);
    }

    @Test
    public void aCancellationIsReportedAsACancellation() {
        final RecordingHandler handler = new RecordingHandler();
        final RecordingCallbacks.Layout callback = new RecordingCallbacks.Layout();

        jobAwaitingLayout(handler, callback).cancelJob(null);

        assertEquals(singletonList("cancelled"), callback.calls);
        assertEquals(singletonList("false:null"), handler.completions);
    }

    @Test
    public void aSecondTerminalCallIsIgnored() {
        final RecordingHandler handler = new RecordingHandler();
        final RecordingCallbacks.Layout callback = new RecordingCallbacks.Layout();

        final PrintingJob job = jobAwaitingLayout(handler, callback);
        job.failJob("first");
        job.failJob("second");
        job.cancelJob("third");
        job.setDocument(new byte[] {1});

        assertEquals("exactly one terminal callback per onLayout",
                singletonList("failed"), callback.calls);
        assertEquals("exactly one result per job", singletonList("false:first"),
                handler.completions);
    }

    @Test
    public void aDocumentAfterATerminalResultIsIgnored() {
        final RecordingHandler handler = new RecordingHandler();
        final RecordingCallbacks.Layout callback = new RecordingCallbacks.Layout();

        final PrintingJob job = jobAwaitingLayout(handler, callback);
        job.failJob("gone");
        // A late reply from Dart. This used to dereference the null callback.
        job.setDocument(new byte[] {1, 2});

        assertEquals(singletonList("failed"), callback.calls);
        assertEquals(singletonList("false:gone"), handler.completions);
    }

    @Test
    public void afterAFrameworkCancellationTheCancelPathWins() {
        final RecordingHandler handler = new RecordingHandler();
        final RecordingCallbacks.Layout callback = new RecordingCallbacks.Layout();

        final PrintingJob job = jobAwaitingLayout(handler, callback);
        job.layoutCancelled = true;
        job.failJob("too late");

        assertEquals("the framework asked for a cancellation first",
                singletonList("cancelled"), callback.calls);
        assertEquals(asList("false:too late"), handler.completions);
    }
}
