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


struct point {
    lua_Number x;
    lua_Number y;
};

static int new(lua_State *L)
{
    check_nargs(L, 2);
    // 1 = x
    // 2 = y
    // 3 = out

    struct point *p = lua_newuserdata(L, sizeof(struct point));
    p->x = getnumber(L, 1);
    p->y = getnumber(L, 2);

    luaL_setmetatable(L, "point");

    return 1;
}

static int centroid(lua_State *L)
{
    check_nargs(L, 2);
    // 1 = points
    // 2 = nrep

    lua_Integer nrep = getinteger(L, 2);

    lua_Number x = 0.0;
    lua_Number y = 0.0;

    lua_len(L, 1);
    lua_Integer npoints = getinteger(L, -1);
    lua_pop(L, 1);

    for (lua_Integer rep = 1; rep <= nrep; rep++) {
        x = 0.0;
        y = 0.0;
        for (lua_Integer i = 1; i <= npoints; i++) {
            // 3 = p
            // 4 = p[1]
            // 5 = p[2]
            lua_geti(L, 1, i);

            struct point *p = luaL_checkudata(L, -1, "point");

            x = x + p->x;
            y = y + p->y;

            lua_pop(L, 1);
        }
    }

    // 3 = out
    lua_newtable(L);

    lua_pushnumber(L, x/npoints);
    lua_setfield(L, 3, "x");

    lua_pushnumber(L, y/npoints);
    lua_setfield(L, 3, "y");

    return 1;
}

static luaL_Reg capi_funcs[] = {
    { "new", new },
    { "centroid", centroid },
    { NULL, NULL}
};

int luaopen_benchmarks_centroid_capi_udata(lua_State *L)
{
    luaL_newmetatable(L, "point");
    lua_pop(L, 1);
    luaL_newlib(L, capi_funcs);
    return 1;
}
