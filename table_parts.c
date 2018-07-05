/*
 * The functions exported by this module inspect the internals of a table object
 * and revel the size of their array and hash parts.
 */

#include <string.h>

#include "tcore.h"

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "lapi.h"
#include "lfunc.h"
#include "lgc.h"
#include "lobject.h"
#include "lstate.h"
#include "lstring.h"
#include "ltable.h"
#include "lvm.h"

#include "math.h"


inline
static void check_nargs(lua_State *L, int expected)
{
    int nargs = lua_gettop(L);
    if (nargs != expected) {
        luaL_error(L, "Expected %d arguments, got %d", expected, nargs);
    }
}

inline
static lua_Integer getinteger(lua_State *L, int slot)
{
    int isnum;
    lua_Integer out = lua_tointegerx(L, slot, &isnum);
    if (!isnum) { luaL_error(L, "impossible"); }
    return out;
}

inline
static lua_Number getnumber(lua_State *L, int slot)
{
    int isnum;
    lua_Number out = lua_tonumberx(L, slot, &isnum);
    if (!isnum) { luaL_error(L, "impossible"); }
    return out;
}

/*
 * Prints the size of the array and hash parts of a given table.
 */
static int print_sizes(lua_State *L)
{
    check_nargs(L, 1);
    StackValue *stack = L->ci->func;
    TValue *t_arg = s2v(stack + 1);
    if (!ttistable(t_arg)) {
        luaL_error(L, "not a table");
    }
    Table *t = hvalue(t_arg);

    printf("sizearray = %u\n", t->sizearray);
    printf("sizehash = %u\n", 1 << t->lsizenode);
    printf("lastfree = %p\n", (void*) t->lastfree);

    return 0;
}

/*
 * Returns whether the given table has a non-empty hash part.
 */
static int has_hash(lua_State *L)
{
    check_nargs(L, 1);
    StackValue *stack = L->ci->func;
    TValue *t_arg = s2v(stack + 1);
    if (!ttistable(t_arg)) {
        luaL_error(L, "not a table");
    }
    Table *t = hvalue(t_arg);

    int ok = (t->lastfree != NULL);
    lua_pushboolean(L, ok);

    return 1;
}



static luaL_Reg capi_funcs[] = {
    { "print_sizes", print_sizes },
    { "has_hash", has_hash },
    { NULL, NULL},
};

int luaopen_table_parts(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
