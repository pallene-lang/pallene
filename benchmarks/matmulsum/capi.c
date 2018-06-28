#include <lua.h>
#include <lauxlib.h>

#include <stdio.h>

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

static int matmul(lua_State *L)
{
    check_nargs(L, 2);

    // 1 = A
    // 2 = B
    // 3 = #A; #B; B[1]; Bk
    // 4 = #B[1]; A[i]; Bk[j]
    // 5 = A[i][k];

    lua_Number s = 0.0;

    lua_len(L, 1);
    lua_Integer NI = getinteger(L, -1);
    lua_pop(L, 1);

    lua_len(L, 2);
    lua_Integer NK = getinteger(L, -1);
    lua_pop(L, 1);

    lua_geti(L, 2, 1);
    lua_len(L, 3);
    lua_Integer NJ = getinteger(L, -1);
    lua_pop(L, 2);

    for (lua_Integer k = 1; k <= NK; k++) {
        lua_geti(L, 2, k);
        for (lua_Integer i = 1; i <= NI; i++) {
            lua_geti(L, 1, i);
            lua_geti(L, 4, k);
            lua_Number Aik = getnumber(L, -1);
            lua_pop(L, 2);
            for (lua_Integer j = 1; j <= NJ; j++) {
                lua_geti(L, 3, j);
                lua_Number Bkj = getnumber(L, -1);
                lua_pop(L, 1);
                s = s + Aik * Bkj;
            }
        }
        lua_pop(L, 1);
    }

    lua_pushnumber(L, s);
    return 1;
}

static luaL_Reg capi_funcs[] = {
    { "matmul", matmul },
    { NULL, NULL },
};

int luaopen_benchmarks_matmulsum_capi(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
