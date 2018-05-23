/* Same as cidiomatic.c but using an array of lua_Integer instead
 * of an array of bool. This helps us get a rough idea of the impact
 * of memory locality / smaller array elements.
 * */

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

    lua_Integer *is_prime = calloc(N+1, sizeof(lua_Integer));
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

int luaopen_benchmarks_sieve_cidiomatic_int(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
