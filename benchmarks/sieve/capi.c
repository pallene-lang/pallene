/* Implementation of the sieve algorithm in C,
 * using Lua arrays and the C API for everything
 * */

#include <lua.h>
#include <lauxlib.h>

static int sieve(lua_State *L)
{
    // Stack
    //   1 = N
    //   2 = is_prime
    //   3 = primes
    //   4 = is_prime[n]

    {
        int nargs = lua_gettop(L);
        if ( nargs != 1 ) {
            luaL_error(L, "Expected 1 argument, for %d", nargs);
        }
    }

    if (!lua_isinteger(L, 1)) {
        luaL_error(L, "Argument 1 is not an integer");
    }

    lua_Integer N = lua_tointeger(L, 1);
    
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
