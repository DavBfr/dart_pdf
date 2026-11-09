#ifndef PRINTING_LINUX_RASTER_DISPATCH_H_
#define PRINTING_LINUX_RASTER_DISPATCH_H_

#include <glib.h>

namespace printing_raster {

// Internal callers always supply an empty, non-null error location.
inline GThreadPool* create_pool(GFunc worker, GError** error) {
  auto pool = g_thread_pool_new(worker, nullptr, 1, TRUE, error);
  // GLib may return a valid, workerless pool together with a creation error.
  if (pool != nullptr && *error != nullptr) {
    g_thread_pool_free(pool, TRUE, FALSE);
    return nullptr;
  }
  return pool;
}

inline void post_message(GSourceFunc callback, gpointer data,
                         GDestroyNotify destroy) {
  // invoke_full can run inline on a worker when the default context is free.
  g_idle_add_full(G_PRIORITY_DEFAULT, callback, data, destroy);
}

}  // namespace printing_raster

#endif  // PRINTING_LINUX_RASTER_DISPATCH_H_
