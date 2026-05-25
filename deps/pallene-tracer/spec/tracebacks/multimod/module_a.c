/*
 * Copyright (c) 2024, The Pallene Developers
 * Pallene Tracer is licensed under the MIT license.
 * Please refer to the LICENSE and AUTHORS files for details
 * SPDX-License-Identifier: MIT
 */

#define PT_IMPLEMENTATION
#include "ptracer.h"

#include "module_include.h"

void some_mod_fn(lua_State *L) {
    MODULE_C_FRAMEENTER();

    /* The lua function which is passed to us. */
    lua_pushvalue(L, 1);

    MODULE_C_SETLINE();
    lua_call(L, 0, 0);

    // Other code...

    MODULE_C_FRAMEEXIT();
}

int some_mod_fn_lua(lua_State *L) {
    int top = lua_gettop(L);
    MODULE_LUA_FRAMEENTER(some_mod_fn_lua);

    /* Look at the macro definition. */
    if(luai_unlikely(top < 1))
        luaL_error(L, "Expected atleast 1 argument");

    if(luai_unlikely(lua_isfunction(L, 1) == 0))
        luaL_error(L, "Expected the first argument to be a function");

    /* Dispatch. */
    some_mod_fn(L);

    return 0;
}

int luaopen_spec_tracebacks_multimod_module_a(lua_State *L) {
    /* Our stack. */
    pt_fnstack_t *fnstack = pallene_tracer_init(L);

    lua_newtable(L);

    /* One very good way to integrate our stack userdatum and finalizer
      object is by using Lua upvalues. */
    /* ---- singular_fn_1 ---- */
    lua_pushlightuserdata(L, fnstack);
    /* `pallene_tracer_init` function pushes the frameexit finalizer to the stack. */
    lua_pushvalue(L, -3);
    lua_pushcclosure(L, some_mod_fn_lua, 2);
    lua_setfield(L, -2, "some_mod_fn");

    return 1;
}

