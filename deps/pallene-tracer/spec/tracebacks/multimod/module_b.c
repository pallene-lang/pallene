/*
 * Copyright (c) 2024, The Pallene Developers
 * Pallene Tracer is licensed under the MIT license.
 * Please refer to the LICENSE and AUTHORS files for details
 * SPDX-License-Identifier: MIT
 */

#define PT_IMPLEMENTATION
#include "ptracer.h"

#include "module_include.h"

void another_mod_fn(lua_State *L) {
    MODULE_C_FRAMEENTER();

    // Other code...

    MODULE_C_SETLINE();
    luaL_error(L, "Error from another module!");

    // Other code...

    MODULE_C_FRAMEEXIT();
}

int another_mod_fn_lua(lua_State *L) {
    MODULE_LUA_FRAMEENTER(another_mod_fn_lua);

    /* Dispatch. */
    another_mod_fn(L);

    return 0;
}

int luaopen_spec_tracebacks_multimod_module_b(lua_State *L) {
    /* Our stack. */
    pt_fnstack_t *fnstack = pallene_tracer_init(L);

    lua_newtable(L);

    /* One very good way to integrate our stack userdatum and finalizer
      object is by using Lua upvalues. */
    /* ---- singular_fn_1 ---- */
    lua_pushlightuserdata(L, fnstack);
    /* `pallene_tracer_init` function pushes the frameexit finalizer to the stack. */
    lua_pushvalue(L, -3);
    lua_pushcclosure(L, another_mod_fn_lua, 2);
    lua_setfield(L, -2, "another_mod_fn");

    return 1;
}
