#define _POSIX_C_SOURCE 199309L

#include <stdio.h>
#include <time.h>
#include <lua.h>
#include <lauxlib.h>

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

static int run(lua_State *L)
{
    check_nargs(L, 2);

    lua_Number x = getnumber(L, 2);

    struct timespec before, after;
    clock_gettime(CLOCK_MONOTONIC, &before);

    lua_pushnumber(L, x);
    lua_setfield(L, 1, "field");

    clock_gettime(CLOCK_MONOTONIC, &after);
    printf("%ld\n",
        after.tv_nsec - before.tv_nsec +
        (after.tv_sec - before.tv_sec) * 1000000000);

    return 0;
}

static luaL_Reg capi_funcs[] = {
    { "run", run },
    { NULL, NULL}
};

int luaopen_benchmarks_capirecordwrite_capi(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
