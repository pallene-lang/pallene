/*
 * Copyright (c) 2024, The Pallene Developers
 * Pallene Tracer is licensed under the MIT license.
 * Please refer to the LICENSE and AUTHORS files for details
 * SPDX-License-Identifier: MIT
 */

/* Static use of the library would suffice. */
#define PT_IMPLEMENTATION
#include "ptracer.h"

/* Here goes user specific macros when Pallene Tracer debug mode is active. */
#ifdef PT_DEBUG
#define MODULE_GET_FNSTACK                                       \
    pt_fnstack_t *fnstack = lua_touserdata(L,                    \
        lua_upvalueindex(1))
#else
#define MODULE_GET_FNSTACK
#endif // PT_DEBUG

/* ---------------- FOR C INTERFACE FUNCTIONS ---------------- */

#define MODULE_C_FRAMEENTER()                                    \
    MODULE_GET_FNSTACK;                                          \
    PALLENE_TRACER_GENERIC_C_FRAMEENTER(fnstack, _frame)

#define MODULE_C_SETLINE()                                       \
    PALLENE_TRACER_GENERIC_C_SETLINE(fnstack)

#define MODULE_C_FRAMEEXIT()                                     \
    PALLENE_TRACER_FRAMEEXIT(fnstack)

/* ---------------- FOR C INTERFACE FUNCTIONS END ---------------- */

/* ---------------- LUA INTERFACE FUNCTIONS ---------------- */

#define MODULE_LUA_FRAMEENTER(fnptr)                             \
    MODULE_GET_FNSTACK;                                          \
    PALLENE_TRACER_LUA_FRAMEENTER(L, fnstack, fnptr,             \
        lua_upvalueindex(2), _frame_lua);                        \
    PALLENE_TRACER_GENERIC_C_FRAMEENTER(fnstack, _frame_c)

/* ---------------- LUA INTERFACE FUNCTIONS END ---------------- */

void lifes_good_fn(lua_State *L) {
    MODULE_C_FRAMEENTER();

    MODULE_C_SETLINE();
    luaL_error(L, "Life's !good");

    MODULE_C_FRAMEEXIT();
}

int singular_fn(lua_State *L) {
    MODULE_LUA_FRAMEENTER(singular_fn);

    /* Call some C function. */
    MODULE_C_SETLINE();
    lifes_good_fn(L);

    return 0;
}

int luaopen_spec_tracebacks_singular_module(lua_State *L) {
    /* Our stack. */
    pt_fnstack_t *fnstack = pallene_tracer_init(L);

    lua_newtable(L);

    /* One very good way to integrate our stack userdatum and finalizer
      object is by using Lua upvalues. */
    /* ---- singular_fn ---- */
    lua_pushlightuserdata(L, fnstack);
    /* `pallene_tracer_init` function pushes the frameexit finalizer to the stack. */
    lua_pushvalue(L, -3);
    lua_pushcclosure(L, singular_fn, 2);
    lua_setfield(L, -2, "singular_fn");

    return 1;
}
