#include <lua.h>
#include <lauxlib.h>

#include <stdio.h>

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
    // 3 = #A; #B; B[1]; Bk
    // 4 = #B[1]; A[i]; Bk[j]
    // 5 = A[i][k];

    lua_Number s = 0.0;

    lua_len(L, 1);
    lua_Integer NI;
    {
        int isnum;
        NI = lua_tointegerx(L, 3, &isnum);
        if (!isnum) { luaL_error(L, "impossible"); }
    }
    lua_pop(L, 1);
    
    lua_len(L, 2);
    lua_Integer NK;
    {
        int isnum;
        NK = lua_tointegerx(L, 3, &isnum);
        if (!isnum) { luaL_error(L, "impossible"); }
    }
    lua_pop(L, 1);

    lua_geti(L, 2, 1);
    lua_len(L, 3);
    lua_Integer NJ;
    {
        int isnum;
        NJ = lua_tonumberx(L, 4, &isnum);
        if (!isnum) { luaL_error(L, "impossible"); }
    }
    lua_pop(L, 2);

    for (lua_Integer k = 1; k <= NK; k++) {
        lua_geti(L, 2, k);
        for (lua_Integer i = 1; i <= NI; i++) {
            lua_geti(L, 1, i);
            lua_geti(L, 4, k);
            lua_Number Aik;
            {
                int isnum;
                Aik = lua_tonumberx(L, 5, &isnum);
                if (!isnum) { luaL_error(L, "A[i][k] is not a number"); }
            }
            lua_pop(L, 2);
            for (lua_Integer j = 1; j <= NJ; j++) {   
                lua_geti(L, 3, j);
                lua_Number Bkj;
                {
                    int isnum;
                    Bkj = lua_tonumberx(L, 4, &isnum);
                    if (!isnum) { luaL_error(L, "B[k][j] is not a number"); }
                }
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
