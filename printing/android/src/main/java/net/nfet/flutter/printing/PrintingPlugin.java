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

import androidx.annotation.NonNull;

import java.lang.ref.WeakReference;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

/**
 * PrintingPlugin
 */
public class PrintingPlugin implements FlutterPlugin, ActivityAware {
    private WeakReference<Context> contextWeakReference;
    private MethodChannel channel;
    private PrintingHandler handler;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        contextWeakReference = new WeakReference<>(binding.getApplicationContext());
        onAttachedToEngine(binding.getBinaryMessenger());
    }

    private void onAttachedToEngine(BinaryMessenger messenger) {
        channel = new MethodChannel(messenger, "net.nfet.printing");

        if (contextWeakReference != null) {
            handler = new PrintingHandler(contextWeakReference, channel);
            channel.setMethodCallHandler(handler);
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        handler = null;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        contextWeakReference.clear();
        contextWeakReference = new WeakReference<>(binding.getActivity().getApplicationContext());
        onAttachedToActivity(contextWeakReference);
    }

    private void onAttachedToActivity(WeakReference<Context>  weakReference) {
        contextWeakReference = weakReference;

        if (contextWeakReference != null && channel != null) {
            handler = new PrintingHandler(contextWeakReference, channel);
            channel.setMethodCallHandler(handler);
        }
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        contextWeakReference = new WeakReference<>(binding.getActivity().getApplicationContext());
        onAttachedToActivity(contextWeakReference);
    }

    @Override
    public void onDetachedFromActivity() {
        channel.setMethodCallHandler(null);
        contextWeakReference.clear();
        handler = null;
    }
}
