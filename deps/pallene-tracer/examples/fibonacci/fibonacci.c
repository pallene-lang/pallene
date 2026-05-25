/*
 * Copyright (c) 2024, The Pallene Developers
 * Pallene Tracer is licensed under the MIT license.
 * Please refer to the LICENSE and AUTHORS files for details
 * SPDX-License-Identifier: MIT
 */

#define PT_IMPLEMENTATION
#include "ptracer.h"

/* User specific macros when Pallene Tracer debug mode is enabled. */
#ifdef PT_DEBUG
#define FIB_GET_FNSTACK                          \
    pt_fnstack_t *fnstack = lua_touserdata(L,    \
        lua_upvalueindex(1))

#else
#define FIB_GET_FNSTACK
#endif // PT_DEBUG

/* ---------------- PALLENE TRACER LUA INERFACE ---------------- */
#define FIB_LUA_FRAMEENTER(fnptr)                       \
    FIB_GET_FNSTACK;                                    \
    PALLENE_TRACER_LUA_FRAMEENTER(L, fnstack, fnptr,    \
        lua_upvalueindex(2), _frame)
/* ---------------- PALLENE TRACER LUA INERFACE END ---------------- */

/* ---------------- PALLENE TRACER C INTERFACE ---------------- */

#define FIB_C_FRAMEENTER()                              \
    FIB_GET_FNSTACK;                                    \
    PALLENE_TRACER_GENERIC_C_FRAMEENTER(fnstack, _frame)

#define FIB_C_SETLINE()                                 \
    PALLENE_TRACER_GENERIC_C_SETLINE(fnstack)

#define FIB_C_FRAMEEXIT()                               \
    PALLENE_TRACER_FRAMEEXIT(fnstack)

/* ---------------- PALLENE TRACER C INTERFACE END ---------------- */

int fib(lua_State *L, int n) {
    FIB_C_FRAMEENTER();

    if(n <= 1) {
        FIB_C_FRAMEEXIT();
        return n;
    }

    FIB_C_SETLINE();
    int result = fib(L, n - 1) + fib(L, n - 2);
    FIB_C_FRAMEEXIT();
    return result;
}

int fib_lua(lua_State *L) {
    int top = lua_gettop(L);
    FIB_LUA_FRAMEENTER(fib_lua);

    /* In Lua interface frames, we always have a finalizer object pushed to the stack by
       `FIB_LUA_FRAMEENTER()`. */
    if(luai_unlikely(top < 1)) {
        luaL_error(L, "Expected atleast 1 parameter");
    }

    if(luai_unlikely(lua_isinteger(L, 1) == 0)) {
        luaL_error(L, "Expected the first argument to be an integer");
    }

    /* Dispatch. */
    int result = fib(L, lua_tointeger(L, 1));
    lua_pushinteger(L, result);

    return 1;
}

int luaopen_fibonacci(lua_State *L) {
    pt_fnstack_t *fnstack = pallene_tracer_init(L);

    lua_newtable(L);
    int table = lua_gettop(L);

    /* ---- fib ---- */
    /* One very good way to integrate our stack userdatum and finalizer
       object is by using Lua upvalues. */
    lua_pushlightuserdata(L, fnstack);
    /* `pallene_tracer_init` function pushes the frameexit finalizer to the stack. */
    lua_pushvalue(L, -3);
    lua_pushcclosure(L, fib_lua, 2);
    lua_setfield(L, table, "fib");

    return 1;
}
