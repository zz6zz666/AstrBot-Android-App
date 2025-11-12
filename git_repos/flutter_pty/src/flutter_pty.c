#include "flutter_pty.h"

#include "include/dart_api_dl.c"

#if _WIN32
#include "flutter_pty_win.c"
#else
#include "forkpty.c"
#include "flutter_pty_unix.c"
#endif