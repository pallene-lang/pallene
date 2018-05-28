#include <lua.h>
#include <lauxlib.h>

#include <stdio.h>

// 1 -> N
// 2 -> a

static int isplaceok(lua_State *L, lua_Integer n, lua_Integer c)
{
    for (lua_Integer i = 1; i <= n-1; i++) {
        lua_geti(L, 2, i);
        lua_Integer d;
        {
            int isnum;
            d = lua_tointegerx(L, -1, &isnum);
            if (!isnum) { luaL_error(L, "impossible"); }
        }
        lua_pop(L, 1);
        
        if (d == c || d-i == c-n || d+i == c+n) {
            return 0;
        }
    }
    return 1;
}

static void printsolution(lua_State *L, lua_Integer N)
{
    for (lua_Integer i = 1; i <= N; i++) {

        lua_geti(L, 2, i);
        lua_Integer ai;
        {
            int isnum;
            ai = lua_tointegerx(L, -1, &isnum);
            if (!isnum) { luaL_error(L, "impossible"); }
        }
        lua_pop(L, 1);


        for (lua_Integer j = 1; j <= N; j++) {
            if (ai == j) {
                putchar('X');
            } else {
                putchar('-');
            }
            putchar(' ');
        }
        putchar('\n');
    }
    putchar('\n');
}

static void addqueen(lua_State *L, lua_Integer N, lua_Integer n)
{
    if (n > N) {
        printsolution(L, N);
    } else {
        for (lua_Integer c = 1; c <= N; c++) {
            if (isplaceok(L, n, c)) {
                lua_pushinteger(L, c);
                lua_seti(L, 2, n);
                addqueen(L, N, n+1);
            }
        }
    }

}

static int nqueens(lua_State *L)
{
    lua_Integer N;
    {
        int isnum;
        N = lua_tointegerx(L, 1, &isnum);
        if (!isnum) { luaL_error(L, "N is not a integer"); }
    }

    lua_newtable(L);

    addqueen(L, N, 1);
    return 0;
}

static luaL_Reg capi_funcs[] = {
    { "nqueens", nqueens },
    { NULL, NULL },
};

int luaopen_benchmarks_queen_capi(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
