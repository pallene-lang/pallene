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


static int new(lua_State *L)
{
    check_nargs(L, 2);
    // 1 = x
    // 2 = y
    // 3 = out

    lua_newtable(L);

    lua_pushvalue(L, 1);
    lua_seti(L, 3, 1);

    lua_pushvalue(L, 2);
    lua_seti(L, 3, 2);

    return 1;
}

static int centroid(lua_State *L)
{
    check_nargs(L, 2);
    // 1 = points
    // 2 = N

    lua_Integer N = getinteger(L, 2);

    lua_Number x = 0.0;
    lua_Number y = 0.0;

    lua_len(L, 1);
    lua_Integer npoints = getinteger(L, -1);
    lua_pop(L, 1);

    for (lua_Integer rep = 1; rep <= N; rep++) {
        x = 0.0;
        y = 0.0;
        for (lua_Integer i = 1; i <= npoints; i++) {
            // 3 = p
            // 4 = p[1]
            // 5 = p[2]
            lua_geti(L, 1, i);

            lua_geti(L, 3, 1);
            lua_Number dx = getnumber(L, -1);

            lua_geti(L, 3, 2);
            lua_Number dy = getnumber(L, -1);

            x = x + dx;
            y = y + dy;

            lua_pop(L, 3);
        }
    }

    // 3 = out
    lua_newtable(L);

    lua_pushnumber(L, x/npoints);
    lua_seti(L, 3, 1);

    lua_pushnumber(L, y/npoints);
    lua_seti(L, 3, 2);

    return 1;
}

static luaL_Reg capi_funcs[] = {
    { "new", new },
    { "centroid", centroid },
    { NULL, NULL}
};

int luaopen_benchmarks_centroid_capi(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
