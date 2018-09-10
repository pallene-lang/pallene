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

static int binsearch (lua_State *L)
{
    check_nargs(L, 2);

    // 1 = t
    // 2 = x
    // 3 = #t; t[mid]

    lua_Integer x = getinteger(L, 2);

    lua_Integer lo = 1;

    lua_len(L, 1);
    lua_Integer hi = getinteger(L, 3);
    lua_pop(L, 1);

    lua_Integer steps = 0;

    while (lo < hi) {
        lua_Integer mid = lo + (hi - lo)/2;
        steps = steps + 1;

        lua_geti(L, 1, mid);
        lua_Integer tmid = getinteger(L, 3);
        lua_pop(L, 1);

        if (x == tmid) {
            goto end;
        } else if (x < tmid) {
            hi = mid - 1;
        } else {
            lo = mid + 1;
        }
    }

end:
    lua_pushinteger(L, steps);
    return 1;
}

static int test (lua_State *L)
{
    check_nargs(L, 1);

    // 1 = t
    // 2 = binsearch
    // 3 = binsearch
    // 4 = t
    // 5 = x

    lua_pushcfunction(L, binsearch);

    lua_Integer s = 0;
    for (lua_Integer i = 1; i <= 10000000; i++) {
        lua_pushvalue(L, 2);
        lua_pushvalue(L, 1);
        lua_pushinteger(L, i);
        lua_call(L, 2, 1);

        lua_Integer res = getinteger(L, 3);
        lua_pop(L, 1);

        if (res != 22) {
            s = s + 1;
        }
    }

    lua_pushinteger(L, s);
    return 1;


}

static luaL_Reg capi_funcs[] = {
    { "binsearch", binsearch },
    { "test", test },
    { NULL, NULL }
};

int luaopen_benchmarks_binsearch_capi(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
