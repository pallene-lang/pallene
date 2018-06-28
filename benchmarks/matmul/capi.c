#include <lua.h>
#include <lauxlib.h>

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
    {
        int nargs = lua_gettop(L);
        if (nargs != 2) {
            luaL_error(L, "Expected 2 arguments, got %d", nargs);
        }
    }

    // 1 = A
    // 2 = B
    // 3 = C

    lua_len(L, 1);
    lua_Integer NI = getinteger(L, 3);
    lua_pop(L, 1);

    lua_len(L, 2);
    lua_Integer NK = getinteger(L, 3);
    lua_pop(L, 1);

    lua_geti(L, 2, 1);
    lua_len(L, 3);
    lua_Integer NJ = getinteger(L, 4);
    lua_pop(L, 2);

    // 4 = line

    lua_newtable(L);
    for (lua_Integer i = 1; i <= NI; i++) {
        lua_newtable(L);
        for (lua_Integer j = 1; j <= NJ; j++) {
            lua_pushnumber(L, 0.0);
            lua_seti(L, 4, j);
        }
        lua_seti(L, 3, i);
    }

    // 4 = B[k]
    // 5 = A[i]
    // 6 = A[i][k]
    // 7 = C[i]
    // 8 = C[i][j]
    // 9 = B[k][j]
    // 10 = v
    for (lua_Integer k = 1; k <= NK; k++) {
        lua_geti(L, 2, k);
        for (lua_Integer i = 1; i <= NI; i++) {
            lua_geti(L, 1, i);
            lua_geti(L, 5, k);
            lua_Number Aik = getnumber(L, 6);

            lua_geti(L, 3, i);
            for (lua_Integer j = 1; j <= NJ; j++) {
                lua_geti(L, 7, j);
                lua_Number Cij = getnumber(L, 8);

                lua_geti(L, 4, j);
                lua_Number Bkj = getnumber(L, 9);

                lua_Number v = Cij + Aik * Bkj;
                lua_pushnumber(L, v);
                lua_seti(L, 7, j);

                lua_pop(L, 2);
            }

            lua_pop(L, 3);
        }
        lua_pop(L, 1);
    }

    return 1;
}

static luaL_Reg capi_funcs[] = {
    { "matmul", matmul },
    { NULL, NULL}
};

int luaopen_benchmarks_matmul_capi(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
