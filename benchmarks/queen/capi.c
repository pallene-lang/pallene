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

// 1 -> N
// 2 -> a

static int isplaceok(lua_State *L, lua_Integer n, lua_Integer c)
{
    for (lua_Integer i = 1; i <= n-1; i++) {
        lua_geti(L, 2, i);
        lua_Integer d = getinteger(L, -1);
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
        lua_Integer ai = getinteger(L, -1);
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
    check_nargs(L, 1);
    lua_Integer N = getinteger(L, 1);

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
