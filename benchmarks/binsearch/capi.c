#include <lua.h>
#include <lauxlib.h>

static int binsearch (lua_State *L)
{
    // 1 = t
    // 2 = x
    // 3 = #t; t[mid]
    
    lua_Integer x;
    {
        int isint;
        x = lua_tointegerx(L, 2, &isint);
        if (!isint) { luaL_error(L, "x is not integer"); }
    }
    
    lua_Integer lo = 1;

    lua_len(L, 1);
    lua_Integer hi;
    {
        int isint;
        hi = lua_tointegerx(L, 3, &isint);
        if (!isint) { luaL_error(L, "impossible"); }
    }
    lua_pop(L, 1);

    lua_Integer steps = 0;

    while (lo < hi) {
        lua_Integer mid = lo + (hi - lo)/2;
        steps = steps + 1;

        lua_geti(L, 1, mid);
        lua_Integer tmid;
        {
            int isint;
            tmid = lua_tointegerx(L, 3, &isint);
            if (!isint) { luaL_error(L, "t[mid] is not an integer"); }
        }
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
        
        lua_Integer res;
        {
            int isint;
            res = lua_tointegerx(L, 3, &isint);
            if (!isint) { luaL_error(L, "binserach(t, i) is not an integer"); }
        }
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
};

int luaopen_benchmarks_binsearch_capi(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
