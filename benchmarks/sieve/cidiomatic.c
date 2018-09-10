/* Implementation of the prime sieve in C, using the C API
 * and Lua arrays only for the return array. The rest of the
 * computation is entirely with native C datatypes.
 */

#include <lua.h>
#include <lauxlib.h>

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>


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
    //   2 = primes

    lua_Integer N = getinteger(L, 1);

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
