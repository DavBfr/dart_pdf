#include <glib.h>

static bool fail_creation = false;
static GThreadPool* returned_pool = nullptr;
static int freed_pools = 0;

static GThreadPool* test_pool_new(GFunc worker, gpointer data, int max_threads,
                                  gboolean exclusive, GError** error) {
  if (fail_creation) {
    g_set_error_literal(error, G_THREAD_ERROR, G_THREAD_ERROR_AGAIN,
                        "Worker unavailable");
    returned_pool = g_thread_pool_new(worker, data, 0, FALSE, nullptr);
    return returned_pool;
  }
  return g_thread_pool_new(worker, data, max_threads, exclusive, error);
}

static void test_pool_free(GThreadPool* pool, gboolean immediate,
                           gboolean wait) {
  if (pool == returned_pool) freed_pools++;
  g_thread_pool_free(pool, immediate, wait);
}

#define g_thread_pool_new test_pool_new
#define g_thread_pool_free test_pool_free
#include "../raster_dispatch.h"
#undef g_thread_pool_new
#undef g_thread_pool_free

static void count_task(gpointer data, gpointer) {
  g_atomic_int_inc(static_cast<int*>(data));
}

static void creation_failure() {
  fail_creation = true;
  g_autoptr(GError) error = nullptr;
  auto pool = printing_raster::create_pool(count_task, &error);
  g_assert_error(error, G_THREAD_ERROR, G_THREAD_ERROR_AGAIN);
  g_assert_null(pool);
  g_assert_cmpint(freed_pools, ==, 1);
  fail_creation = false;
}

static void exclusive_worker() {
  g_autoptr(GError) error = nullptr;
  auto pool = printing_raster::create_pool(count_task, &error);
  g_assert_no_error(error);
  g_assert_nonnull(pool);
  g_assert_true(pool->exclusive);
  g_assert_cmpuint(g_thread_pool_get_num_threads(pool), ==, 1);
  int completed = 0;
  for (int n = 0; n < 2; n++) {
    g_assert_true(g_thread_pool_push(pool, &completed, &error));
    g_assert_no_error(error);
  }
  g_thread_pool_free(pool, FALSE, TRUE);
  g_assert_cmpint(g_atomic_int_get(&completed), ==, 2);
}

static GThread* owner;
static GArray* deliveries;
static int destroyed = 0;
static gboolean deliver(gpointer data) {
  g_assert_true(g_thread_self() == owner);
  const int value = GPOINTER_TO_INT(data);
  g_array_append_val(deliveries, value);
  return G_SOURCE_REMOVE;
}
static void destroy(gpointer) {
  g_assert_true(g_thread_self() == owner);
  destroyed++;
}
static gpointer post(gpointer) {
  printing_raster::post_message(deliver, GINT_TO_POINTER(1), destroy);
  printing_raster::post_message(deliver, GINT_TO_POINTER(2), destroy);
  return nullptr;
}

static void owner_dispatch() {
  owner = g_thread_self();
  deliveries = g_array_new(FALSE, FALSE, sizeof(int));
  // Keep the default context unowned while the worker posts both messages.
  g_thread_join(g_thread_new("raster-test", post, nullptr));
  g_assert_cmpuint(deliveries->len, ==, 0);
  g_assert_cmpint(destroyed, ==, 0);
  while (g_main_context_iteration(nullptr, FALSE)) {
  }
  g_assert_cmpuint(deliveries->len, ==, 2);
  g_assert_cmpint(g_array_index(deliveries, int, 0), ==, 1);
  g_assert_cmpint(g_array_index(deliveries, int, 1), ==, 2);
  g_assert_cmpint(destroyed, ==, 2);
  g_array_unref(deliveries);
}

int main(int argc, char** argv) {
  g_test_init(&argc, &argv, nullptr);
  g_test_add_func("/raster/create-failure", creation_failure);
  g_test_add_func("/raster/exclusive-worker", exclusive_worker);
  g_test_add_func("/raster/owner-dispatch", owner_dispatch);
  return g_test_run();
}
