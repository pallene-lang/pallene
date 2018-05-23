/* Implementation of the prime sieve in C, using the C API
 * and Lua arrays only for the return array. The rest of the
 * computation is entirely with native C datatypes.
 */

#include <lua.h>
#include <lauxlib.h>

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

static int sieve(lua_State *L)
{
    // Stack
    //   1 = N
    //   2 = primes

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

    bool *is_prime = calloc(N+1, sizeof(bool));
    is_prime[1] = 0;
    for (lua_Integer n = 2; n <= N; n++) {
        is_prime[n] = 1;
    }

    lua_Integer nprimes = 0;
    lua_newtable(L);

    for (lua_Integer n = 1; n <= N; n++) {
        if (is_prime[n]) {
            nprimes = nprimes + 1;
            lua_pushinteger(L, n);
            lua_seti(L, 2, nprimes);
            for (lua_Integer m = n+n; m <= N; m += n) {
                is_prime[m] = 0;
            }
        }
    }

    free(is_prime);

    return 1;
}

static luaL_Reg capi_funcs[] = {
    { "sieve", sieve },
    { NULL, NULL }
};

int luaopen_benchmarks_sieve_cidiomatic(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
