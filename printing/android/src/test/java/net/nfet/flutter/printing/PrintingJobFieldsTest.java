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

import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.print.PrintManager;

import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;

import org.junit.Test;

/**
 * A static field holding a Context, or anything that holds one, roots the host
 * Activity for the lifetime of the process.
 *
 * <p>PrintingJob used to keep the PrintManager in a static field and reassign it
 * from the current context in every constructor. PrintManager keeps that Context
 * in a final field, so one print retained the Activity, its Window and its
 * FlutterView until the process died.
 */
public class PrintingJobFieldsTest {
    @Test
    public void noStaticFieldHoldsAContext() {
        final List<String> offenders = new ArrayList<>();

        for (final Class<?> type :
                new Class<?>[] {PrintingJob.class, PrintingHandler.class, PrintingPlugin.class}) {
            for (final Field field : type.getDeclaredFields()) {
                if (!Modifier.isStatic(field.getModifiers())) {
                    continue;
                }
                if (Context.class.isAssignableFrom(field.getType())
                        || PrintManager.class.isAssignableFrom(field.getType())) {
                    offenders.add(type.getSimpleName() + "." + field.getName() + " ("
                            + field.getType().getName() + ")");
                }
            }
        }

        assertTrue("static fields that root a Context: " + offenders, offenders.isEmpty());
    }
}
