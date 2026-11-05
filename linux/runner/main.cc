#include "my_application.h"

#include <cstdlib>
#include <unistd.h>

static void repair_working_directory() {
  char* cwd = getcwd(nullptr, 0);
  if (cwd != nullptr) {
    std::free(cwd);
    return;
  }
  const gchar* home = g_get_home_dir();
  if (home != nullptr && g_path_is_absolute(home) && chdir(home) == 0) {
    return;
  }
  if (chdir("/") != 0) {
    g_warning("Unable to recover a usable working directory");
  }
}

int main(int argc, char** argv) {
  // A bundle swap can unlink the inherited cwd before Flutter reads metadata.
  repair_working_directory();
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
