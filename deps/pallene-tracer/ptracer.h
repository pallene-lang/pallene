/*
 * Copyright (c) 2024, The Pallene Developers
 * Pallene Tracer is licensed under the MIT license.
 * Please refer to the LICENSE and AUTHORS files for details
 * SPDX-License-Identifier: MIT
 */

#ifndef PALLENE_TRACER_H
#define PALLENE_TRACER_H

#include <lua.h>
#include <lauxlib.h>

#include <stdlib.h>
#include <stdbool.h>
#include <string.h>

#if LUA_VERSION_RELEASE_NUM < 50400
#error "Pallene Tracer needs atleast Lua 5.4 to work properly"
#endif

/* ---------------- MACRO DEFINITIONS ---------------- */

#ifdef PT_BUILD_AS_DLL
#ifdef PT_LIB
#define PT_API    __declspec(dllexport)
#else
#define PT_API    __declspec(dllimport)
#endif // PT_LIB
#else
#define PT_API    extern
#endif // PT_BUILD_AS_DLL

/* Pallene stack reference entry for the registry. */
/* DO NOT CHANGE EVEN BY MISTAKE. */
#define PALLENE_TRACER_CONTAINER_ENTRY  "__PALLENE_TRACER_CONTAINER"

/* Finalizer metatable key. */
/* DO NOT CHANGE EVEN BY MISTAKE. */
#define PALLENE_TRACER_FINALIZER_ENTRY  "__PALLENE_TRACER_FINALIZER"

/* The size of the Pallene call-stack. */
/* DO NOT CHANGE EVEN BY MISTAKE. */
#define PALLENE_TRACER_MAX_CALLSTACK         100000

/* API wrapper macros. Using these wrappers instead is raw functions
 * are highly recommended. */
#ifdef PT_DEBUG
#define PALLENE_TRACER_FRAMEENTER(fnstack, frame)       pallene_tracer_frameenter(fnstack, frame)
#define PALLENE_TRACER_SETLINE(fnstack, line)           pallene_tracer_setline(fnstack, line)
#define PALLENE_TRACER_FRAMEEXIT(fnstack)               pallene_tracer_frameexit(fnstack)

#else
#define PALLENE_TRACER_FRAMEENTER(fnstack, frame)
#define PALLENE_TRACER_SETLINE(fnstack, line)
#define PALLENE_TRACER_FRAMEEXIT(fnstack)
#endif // PT_DEBUG

/* Not part of the API. */
#ifdef PT_DEBUG
#define _PALLENE_TRACER_PREPARE_C_FRAME(fn_name, filename, var_name)                  \
pt_fn_details_t var_name##_details =                                                  \
    PALLENE_TRACER_FN_DETAILS(fn_name, filename);                                     \
pt_frame_t var_name = PALLENE_TRACER_C_FRAME(var_name##_details)

#define _PALLENE_TRACER_PREPARE_LUA_FRAME(fnptr, var_name)                            \
pt_frame_t var_name = PALLENE_TRACER_LUA_FRAME(fnptr)

#define _PALLENE_TRACER_FINALIZER(L, location)       lua_pushvalue(L, (location));    \
    lua_toclose(L, -1)

#else
#define _PALLENE_TRACER_PREPARE_LUA_FRAME(fnptr, var_name)
#define _PALLENE_TRACER_PREPARE_C_FRAME(fn_name, filename, var_name)
#define _PALLENE_TRACER_FINALIZER(L, location)
#endif // PT_DEBUG

/* ---- DATA-STRUCTURE HELPER MACROS ---- */

/* Use this macro to fill in the details structure. */
/* E.U.:
       pt_fn_details_t det = PALLENE_TRACER_FN_DETAILS("fn_name", "some_mod.c");
 */
#define PALLENE_TRACER_FN_DETAILS(name, fname)    \
{ .fn_name = name, .filename = fname }

/* Use this macro to fill in the frame structure as a
   Lua interface frame. */
/* E.U.: `pt_frame_t frame = PALLENE_TRACER_LUA_FRAME(lua_fn);` */
#define PALLENE_TRACER_LUA_FRAME(fnptr)           \
{ .type = PALLENE_TRACER_FRAME_TYPE_LUA,          \
  .shared = { .c_fnptr = fnptr } }

/* Use this macro to fill in the frame structure as a
   C interface frame. */
/* E.U.: `pt_frame_t frame = PALLENE_TRACER_C_FRAME(_details);` */
#define PALLENE_TRACER_C_FRAME(detl)              \
{ .type = PALLENE_TRACER_FRAME_TYPE_C,            \
  .shared = { .details = &detl } }

/* ---- DATA-STRUCTURE HELPER MACROS END ---- */

/* ---- API HELPER MACROS ---- */

/* Use this macro the bypass some frameenter boilerplates for Lua interface frames. */
/* Note: `location` is where the finalizer object is in the stack, acquired from
   `pallene_tracer_init()` function. If the object is passed to Lua C functions as an
   upvalue, this should be `lua_upvalueindex(n)`. Otherwise, it should just be a number
   denoting the parameter index where the object is found if passed as a plain parameter
   to the functon. */
/* The `var_name` indicates the name of the `pt_frame_t` structure variable. */
#define PALLENE_TRACER_LUA_FRAMEENTER(L, fnstack, fnptr, location, var_name)    \
_PALLENE_TRACER_PREPARE_LUA_FRAME(fnptr, var_name);                             \
PALLENE_TRACER_FRAMEENTER(fnstack, &var_name);                                  \
_PALLENE_TRACER_FINALIZER(L, location)

/* Use this macro the bypass some frameenter boilerplates for C interface frames. */
/* The `var_name` indicates the name of the `pt_frame_t` structure variable. */
#define PALLENE_TRACER_C_FRAMEENTER(fnstack, fn_name, filename, var_name)       \
_PALLENE_TRACER_PREPARE_C_FRAME(fn_name, filename, var_name);                   \
PALLENE_TRACER_FRAMEENTER(fnstack, &var_name);

/* -- GENERIC MACROS -- */

/* FOR NORMAL C MODULES THESE MACROS SHOULD SUFFICE.  */
#define PALLENE_TRACER_GENERIC_C_FRAMEENTER(fnstack, var_name)               \
    PALLENE_TRACER_C_FRAMEENTER(fnstack, __func__, __FILE__, var_name)

#define PALLENE_TRACER_GENERIC_C_SETLINE(fnstack)                               \
    PALLENE_TRACER_SETLINE(fnstack, __LINE__ + 1)

/* ---- API HELPER MACROS END ---- */

/* ---------------- MACRO DEFINITIONS END ---------------- */

/* ---------------- DATA STRUCTURES ---------------- */

/* What type of frame we are dealing with? Is it just a normal
   C function or Lua C Function? */
typedef enum frame_type {
    PALLENE_TRACER_FRAME_TYPE_C,
    PALLENE_TRACER_FRAME_TYPE_LUA
} frame_type_t;

/* Details of the callee function (name, where it is from etc.) */
/* Optimization Tip: Try declaring the struct 'static'. */
typedef struct pt_fn_details {
    const char *const fn_name;
    const char *const filename;
} pt_fn_details_t;

/* A single frame representation. */
typedef struct pt_frame {
    frame_type_t type;
    int line;

    union {
        pt_fn_details_t *details;
        lua_CFunction c_fnptr;
    } shared;
} pt_frame_t;

/* Our stack is fully heap-allocated stack. We need some structure to hold
   the stack information. This structure will be an Userdatum. */
typedef struct pt_fnstack {
    pt_frame_t *stack;
    int count;
} pt_fnstack_t;

/* ---------------- DATA STRUCTURES END ---------------- */

/* ---------------- DECLARATIONS ---------------- */

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

/* Initializes the Pallene Tracer. The initialization refers to creating the stack
   if not created, preparing the traceback fn and finalizers. */
/* This function must only be called from Lua module entry point. */
/* NOTE: Pushes the finalizer object to the stack. The object has to be closed
   everytime you are in a Lua C function using `lua_toclose(L, idx)`. */
PT_API pt_fnstack_t *pallene_tracer_init(lua_State *L);

/* Pushes a frame to the stack. The frame structure is self-managed for every function. */
static inline void pallene_tracer_frameenter(pt_fnstack_t *fnstack, pt_frame_t *restrict frame) {
    /* Have we ran out of stack entries? If we do, stop pushing frames. */
    if(luai_likely(fnstack->count < PALLENE_TRACER_MAX_CALLSTACK))
        fnstack->stack[fnstack->count] = *frame;

    fnstack->count++;
}

/* Sets line number to the topmost frame in the stack. */
static inline void pallene_tracer_setline(pt_fnstack_t *fnstack, int line) {
    if(luai_likely(fnstack->count != 0))
        fnstack->stack[fnstack->count - 1].line = line;
}

/* Removes the last frame from the stack. */
static inline void pallene_tracer_frameexit(pt_fnstack_t *fnstack) {
    fnstack->count -= (fnstack->count > 0);
}

#ifdef __cplusplus
}
#endif // __cplusplus

/* ---------------- DECLARATIONS END ---------------- */

#endif // PALLENE_TRACER_H

#if defined(PT_IMPLEMENTATION) && !defined(PT_IMPLEMENTED)
/* This is implementation guard, making sure we include the implementation just one time. */
#define PT_IMPLEMENTED

/* ---------------- PRIVATE ---------------- */

/* When we encounter a runtime error, `pallene_tracer_frameexit()` may not
   get called. Therefore, the stack will get corrupted if the previous
   call-frames are not removed. The finalizer function makes sure it
   does not happen. Its guardian angel. */
/* The finalizer function will be called from a to-be-closed value (since
   Lua 5.4). If you are using Lua version prior 5.4, you are outta luck. */
static int _pallene_tracer_finalizer(lua_State *L) {
    /* Get the userdata. */
    pt_fnstack_t *fnstack = (pt_fnstack_t *) lua_touserdata(L, lua_upvalueindex(1));

    /* Remove all the frames until last Lua frame. */
    int idx = fnstack->count - 1;
    while(fnstack->stack[idx].type != PALLENE_TRACER_FRAME_TYPE_LUA)
        idx--;

    /* Remove the Lua frame as well. */
    fnstack->count = idx;

    return 0;
}

/* Frees the heap-allocated resources. */
/* This function will be used as `__gc` metamethod to free our stack. */
static int _pallene_tracer_free_resources(lua_State *L) {
    pt_fnstack_t *fnstack = (pt_fnstack_t *) lua_touserdata(L, 1);
    free(fnstack->stack);

    return 0;
}

/* ---------------- PRIVATE END ---------------- */

/* ---------------- DEFINITIONS ---------------- */

/* Initializes the Pallene Tracer. The initialization refers to creating the stack
   if not created, preparing the traceback fn and finalizers. */
/* This function must only be called from Lua module entry point. */
/* NOTE: Pushes the finalizer object to the stack. The object has to be closed
   everytime you are in a Lua C function using `lua_toclose(L, idx)`. */
/* ALSO NOTE: The stack and finalizer object would be returned if and only if `PT_DEBUG`
   is set. Otherwise, a NULL pointer would be returned alongside a NIL value pushed onto the stack. */
pt_fnstack_t *pallene_tracer_init(lua_State *L) {
#ifdef PT_DEBUG
    pt_fnstack_t *fnstack = NULL;

    /* Try getting the userdata. */
    lua_getfield(L, LUA_REGISTRYINDEX, PALLENE_TRACER_CONTAINER_ENTRY);

    /* If we don't find any userdata, initialize resources. */
    if(luai_unlikely(lua_isnil(L, -1) == 1)) {
        fnstack = (pt_fnstack_t *) lua_newuserdata(L, sizeof(pt_fnstack_t));
        fnstack->stack = malloc(PALLENE_TRACER_MAX_CALLSTACK * sizeof(pt_frame_t));
        fnstack->count = 0;

        /* Prepare the `__gc` finalizer to free the stack. */
        lua_newtable(L);
        lua_pushcfunction(L, _pallene_tracer_free_resources);
        lua_setfield(L, -2, "__gc");
        lua_setmetatable(L, -2);

        /* This is our finalizer which will reside in the value stack. */
        lua_newtable(L);
        lua_newtable(L);
        lua_pushvalue(L, -3);

        /* Our finalizer fn. */
        lua_pushcclosure(L, _pallene_tracer_finalizer, 1);
        lua_setfield(L, -2, "__close");
        lua_setmetatable(L, -2);

        /* Set finalizer object to registry. */
        lua_setfield(L, LUA_REGISTRYINDEX, PALLENE_TRACER_FINALIZER_ENTRY);

        /* Set stack function stack container to registry .*/
        lua_setfield(L, LUA_REGISTRYINDEX, PALLENE_TRACER_CONTAINER_ENTRY);

        /* Push the finalizer object in the stack. */
        lua_getfield(L, LUA_REGISTRYINDEX, PALLENE_TRACER_FINALIZER_ENTRY);
    } else {
        fnstack = lua_touserdata(L, -1);
        lua_getfield(L, LUA_REGISTRYINDEX, PALLENE_TRACER_FINALIZER_ENTRY);
    }

    return fnstack;
#else
    /* No debug mode, no stack and finalizer object. Regardless we need to fill in the blanks. */
    lua_pushnil(L);
    return NULL;
#endif // PT_DEBUG
}

/* ---------------- DEFINITIONS END ---------------- */

#endif
