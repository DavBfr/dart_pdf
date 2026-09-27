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

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodChannel;

/**
 * PrintingPlugin
 */
public class PrintingPlugin implements FlutterPlugin, ActivityAware {
    // Kept for the whole engine lifetime, so the handler can fall back to it
    // when the Activity goes away.
    private Context applicationContext;
    private MethodChannel channel;
    private PrintingHandler handler;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "net.nfet.printing");
        setHandlerContext(applicationContext);
    }

    /** Point the channel at a handler bound to the given context. */
    private void setHandlerContext(Context context) {
        if (channel == null || context == null) {
            return;
        }

        handler = new PrintingHandler(context, channel);
        channel.setMethodCallHandler(handler);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        handler = null;
        applicationContext = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        setHandlerContext(binding.getActivity());
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        setHandlerContext(binding.getActivity());
    }

    @Override
    public void onDetachedFromActivity() {
        // Back to the application context, not to no handler at all: a cached
        // engine outlives its Activity, and sharing still works there. Nulling
        // the handler turned every later call into a MissingPluginException.
        setHandlerContext(applicationContext);
    }
}
