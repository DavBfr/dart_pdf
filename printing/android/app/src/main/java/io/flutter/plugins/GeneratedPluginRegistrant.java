package io.flutter.plugins;

import io.flutter.plugin.common.PluginRegistry;
import net.nfet.flutter.printing.PrintingPlugin;

/**
 * Generated file. Do not edit.
 */
public final class GeneratedPluginRegistrant {
    public static void registerWith(PluginRegistry registry) {
        if (alreadyRegisteredWith(registry)) {
            return;
        }
        PrintingPlugin.registerWith(
                registry.registrarFor("net.nfet.flutter.printing.PrintingPlugin"));
    }

    private static boolean alreadyRegisteredWith(PluginRegistry registry) {
        final String key = GeneratedPluginRegistrant.class.getCanonicalName();
        if (registry.hasPlugin(key)) {
            return true;
        }
        registry.registrarFor(key);
        return false;
    }
}
