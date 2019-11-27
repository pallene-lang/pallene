#include "lauxlib.h"
#include "lualib.h"


static int next_id = 0;

static
void bind_magic(Proto *p)
{
    // This traversal order should be the same one that luaot.c uses
    p->aot_implementation = LUA_AOT_FUNCTIONS[next_id++];
    for(int i=0; i < p->sizep; i++) {
        bind_magic(p->p[i]);
    }
}

int LUA_AOT_LUAOPEN_NAME(lua_State *L) {
    
    int ok = luaL_loadstring(L, LUA_AOT_MODULE_SOURCE_CODE);
    switch (ok) {
      case LUA_OK:
        /* No errors */
        break;
      case LUA_ERRSYNTAX:
        fprintf(stderr, "syntax error in bundled source code.\n");
        exit(1);
        break;
      case LUA_ERRMEM:
        fprintf(stderr, "memory allocation (out-of-memory) error in bundled source code.\n");
        exit(1);
        break;
      default:
        fprintf(stderr, "unknown error. This should never happen\n");
        exit(1);
    }

    LClosure *cl = (void *) lua_topointer(L, -1);
    bind_magic(cl->p);

    lua_call(L, 0, 1);
    return 1;
}
