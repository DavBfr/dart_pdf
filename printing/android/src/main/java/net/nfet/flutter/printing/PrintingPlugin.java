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
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

/**
 * PrintingPlugin
 */
public class PrintingPlugin implements FlutterPlugin, ActivityAware {
    private Context context;
    private MethodChannel channel;
    private PrintingHandler handler;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        onAttachedToEngine(binding.getBinaryMessenger());
    }

    private void onAttachedToEngine(BinaryMessenger messenger) {
        channel = new MethodChannel(messenger, "net.nfet.printing");

        if (context != null) {
            handler = new PrintingHandler(context, channel);
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
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        if (context != null) {
            context = null;
        }
        context = binding.getActivity();
        onAttachedToActivity(context);
    }

    private void onAttachedToActivity(Context context) {
        if (context != null && channel != null) {
            handler = new PrintingHandler(context, channel);
            channel.setMethodCallHandler(handler);
        }
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        context = null;
        context = binding.getActivity();
        onAttachedToActivity(context);
    }

    @Override
    public void onDetachedFromActivity() {
        channel.setMethodCallHandler(null);
        context = null;
        handler = null;
    }
}
