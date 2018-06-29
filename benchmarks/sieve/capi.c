/* Implementation of the sieve algorithm in C,
 * using Lua arrays and the C API for everything
 * */

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


static int sieve(lua_State *L)
{
    check_nargs(L, 1);

    // Stack
    //   1 = N
    //   2 = is_prime
    //   3 = primes
    //   4 = is_prime[n]

    lua_Integer N = getinteger(L, 1);

    lua_newtable(L);
    lua_pushboolean(L, 0);
    lua_seti(L, 2, 1);
    for (lua_Integer n = 2; n <= N; n++) {
        lua_pushboolean(L, 1);
        lua_seti(L, 2, n);
    }

    lua_Integer nprimes = 0;
    lua_newtable(L);

    for (lua_Integer n = 1; n <= N; n++) {
        lua_geti(L, 2, n);
        int n_is_prime = lua_toboolean(L, 4);
        lua_pop(L, 1);
        if (n_is_prime) {
            nprimes = nprimes + 1;
            lua_pushinteger(L, n);
            lua_seti(L, 3, nprimes);
            for (lua_Integer m = n+n; m <= N; m += n) {
                lua_pushboolean(L, 0);
                lua_seti(L, 2, m);
            }
        }
    }

    return 1;
}

static luaL_Reg capi_funcs[] = {
    { "sieve", sieve },
    { NULL, NULL }
};

int luaopen_benchmarks_sieve_capi(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
