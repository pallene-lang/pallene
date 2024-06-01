-- /*
-- /*
-- Copyright (c) 2022, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT
-- */

-- /*
-- PALLENE RUNTIME LIBRARY
-- =======================
-- This is the Pallene C library, inside a Lua string. If you are wondering why, it is
-- to make it easier to install with Luarocks. I didn't want to add a dependency to
-- https://github.com/hishamhm/datafile just for this.
--
-- We copy paste this library at the start of every Pallene module, effectively statically linking
-- it. This is necessary for some of the functions and macros, which are designed to be inlined
-- and therefore must be defined in the same translation unit. It is a bit wasteful for the
-- non-inline functions though. We considered putting them in a separate library but it's less than
-- 10 KB so we decided that it wasn't worth the extra complexity.
--
-- 1. One option we tried in the past was to bundle the Pallene library into the custom Lua
-- interpreter. We moved away from that because of the inconvenience of having to recompile and
-- reinstall Lua every time the Pallene lib changed.
--
-- 2. Another option we considered was packaging it as a regular shared library. The main problem is
-- that Luarocks doesn't have a clean way to install shared libraries into /usr/lib. That means that
-- we would need to install it to a non-standard place and pass appropriate -L flags when compiling
-- a pallene module.
--
-- 3. A third option would be to package it as a Lua extension module, putting the functions inside
-- an userdata struct and telling Pallene to fetch them using "require". This would play nice with
-- Luarocks but would introduce additional complexity to implement that userdata workaround.
-- */

return [==[
#define LUA_CORE
#include <lua.h>
#include <lauxlib.h>
#include <luacore.h>

#include <string.h>
#include <stdarg.h>
#include <locale.h>
#include <math.h>
#include <stdbool.h>

#define PALLENE_UNREACHABLE __builtin_unreachable()

/* Part of Pallene Tracer. */
#define PALLENE_FRAMEENTER(L, name, sig) pt_frame_t _frame = {                                  \
                                             .fn_name = PALLENE_SOURCE_FILE_WO_EXT "." name,    \
                                             .mod_name = PALLENE_SOURCE_FILE,                   \
                                             .line = -1                                         \
                                         };                                                     \
                                        pallene_tracer_frameenter(L, &_frame, sig)
#define PALLENE_GLOBAL_SETLINE(L, line) pallene_tracer_global_setline(L, line)
#define PALLENE_SETLINE(line)           pallene_tracer_setline(&_frame, line)
#define PALLENE_FRAMEEXIT(L, ...)       pallene_tracer_frameexit(L);                            \
                                        return __VA_ARGS__

/* Pallene Tracer related data-structures. */
typedef struct pt_frame {
    /* Here we would store the function name and the module name. */
    const char *const fn_name;
    const char *const mod_name;

    /* Line number. */
    int line;

    /* The frame signature. */
    ptrdiff_t frame_sig;

    struct pt_frame *next;
    struct pt_frame *prev;
} pt_frame_t;

/* Pallene Tracer. */
static void pallene_tracer_frameenter(lua_State *L, pt_frame_t * restrict frame, ptrdiff_t sig);
static void pallene_tracer_global_setline(lua_State *L, int line);
static void pallene_tracer_setline(pt_frame_t * restrict frame, int line);
static void pallene_tracer_frameexit(lua_State *L);
static int  pallene_tracer_debug_traceback(lua_State *L);
static void pallene_tracer_init(lua_State *L);

/* Type tags */
static const char *pallene_type_name(lua_State *L, const TValue *v);
static int pallene_is_truthy(const TValue *v);
static int pallene_is_record(const TValue *v, const TValue *meta_table);
static int pallene_bvalue(TValue *obj);
static void pallene_setbvalue(TValue *obj, int b);

/* Garbage Collection */
static void pallene_barrierback_unboxed(lua_State *L, GCObject *p, GCObject *v);

/* Runtime errors */
static l_noret pallene_runtime_tag_check_error(lua_State *L, const char* file, int line,
                                const char *expected_type_name, const TValue *received_type, const char *description_fmt, ...);
static l_noret pallene_runtime_arity_error(lua_State *L, const char *name, int expected, int received, int line);
static l_noret pallene_runtime_divide_by_zero_error(lua_State *L, const char* file, int line);
static l_noret pallene_runtime_mod_by_zero_error(lua_State *L, const char* file, int line);
static l_noret pallene_runtime_number_to_integer_error(lua_State *L, const char* file, int line);
static l_noret pallene_runtime_array_metatable_error(lua_State *L, const char* file, int line);
static l_noret pallene_runtime_cant_grow_stack_error(lua_State *L, int line);

/* Arithmetic operators */
static lua_Integer pallene_int_divi(lua_State *L, lua_Integer m, lua_Integer n, const char* file, int line);
static lua_Integer pallene_int_modi(lua_State *L, lua_Integer m, lua_Integer n, const char* file, int line);
static lua_Integer pallene_shiftL(lua_Integer x, lua_Integer y);
static lua_Integer pallene_shiftR(lua_Integer x, lua_Integer y);

/* String operators */
static TString *pallene_string_concatN(lua_State *L, size_t n, TString **ss);

/* Table operators */
static Table *pallene_createtable(lua_State *L, lua_Integer narray, lua_Integer nrec);
static void pallene_grow_array(lua_State *L, const char* file, int line, Table *arr, unsigned int ui);
static void pallene_renormalize_array(lua_State *L,Table *arr, lua_Integer i, const char* file, int line);
static TValue *pallene_getshortstr(Table *t, TString *key, int *restrict cache);
static TValue *pallene_getstr(size_t len, Table *t, TString *key, int *cache);

/* Math builtins */
static lua_Integer pallene_checked_float_to_int(lua_State *L, const char* file, int line, lua_Number d);
static lua_Integer pallene_math_ceil(lua_State *L, const char* file, int line, lua_Number n);
static lua_Integer pallene_math_floor(lua_State *L, const char* file, int line, lua_Number n);
static lua_Number  pallene_math_log(lua_Integer x, lua_Integer base);
static lua_Integer pallene_math_modf(lua_State *L, const char* file, int line, lua_Number n, lua_Number* out);

/* Other builtins */
static TString *pallene_string_char(lua_State *L, const char* file, int line, lua_Integer c);
static TString *pallene_string_sub(lua_State *L, TString *str, lua_Integer start, lua_Integer end);
static TString *pallene_type_builtin(lua_State *L, TValue v);
static TString *pallene_tostring(lua_State *L, const char* file, int line, TValue v);
static void pallene_io_write(lua_State *L, TString *str);

/* Pallene tracer implementation. */

static void pallene_tracer_frameenter(lua_State *L, pt_frame_t * restrict frame, ptrdiff_t sig) {
    pt_frame_t *head, *tail;

    lua_getglobal(L, "__pallene_tracer_stack_head");
    head = (pt_frame_t *) lua_topointer(L, -1);
    lua_getglobal(L, "__pallene_tracer_stack_tail");
    tail = (pt_frame_t *) lua_topointer(L, -1);
    lua_pop(L, 2);

    /* If there is no frame in the stack. */
    if(head == NULL) {
        /* Just to be safe. */
        frame->prev = NULL;
        frame->next = NULL;

        /* There is no other signature. */
        frame->frame_sig = sig;

        head = frame;
        tail = frame;

        goto out;
    }

    /* The frame signature. */
    /* If we don't have any frame signature, that denotes the call was made from Pallene
       environment. */
    if(sig) frame->frame_sig = sig;
    else    frame->frame_sig = tail->frame_sig;

    tail ->next = frame;
    frame->prev = tail;

    tail = frame;

out:
    /* Now update the registry. */
    lua_pushlightuserdata(L, head);
    lua_setglobal(L, "__pallene_tracer_stack_head");
    lua_pushlightuserdata(L, tail);
    lua_setglobal(L, "__pallene_tracer_stack_tail");
}

static void pallene_tracer_global_setline(lua_State *L, int line) {
    lua_getglobal(L, "__pallene_tracer_stack_tail");
    pt_frame_t *tail = (pt_frame_t *) lua_topointer(L, -1);
    lua_pop(L, 1);

    if(tail != NULL)
        tail->line = line;
}

static void pallene_tracer_setline(pt_frame_t * restrict frame, int line) {
    frame->line = line;
}

static void pallene_tracer_frameexit(lua_State *L) {
    pt_frame_t *head, *tail;

    lua_getglobal(L, "__pallene_tracer_stack_head");
    head = (pt_frame_t *) lua_topointer(L, -1);
    lua_getglobal(L, "__pallene_tracer_stack_tail");
    tail = (pt_frame_t *) lua_topointer(L, -1);
    lua_pop(L, 2);

    /* We are popping the very last frame. */
    if(tail->prev == NULL) {
        tail = NULL;
        head = NULL;

        goto out;
    }

    tail->prev->next = NULL;
    tail = tail->prev;

out:
    /* Now update the registry. */
    lua_pushlightuserdata(L, head);
    lua_setglobal(L, "__pallene_tracer_stack_head");
    lua_pushlightuserdata(L, tail);
    lua_setglobal(L, "__pallene_tracer_stack_tail");
}

static int pallene_tracer_debug_traceback(lua_State *L) {
    /* The debug traceback function frame. */
    pt_frame_t self = {
        .fn_name  = "pallene_tracer_debug_traceback",
        .mod_name = "pallene_debug",
        .line     = 0
    };
    pallene_tracer_frameenter(L, &self, (ptrdiff_t) pallene_tracer_debug_traceback);

    const char *message = lua_tostring(L, 1);
    fprintf(stderr, "Runtime error: %s\nStack traceback: \n", message);

    lua_getglobal(L, "__pallene_tracer_stack_tail");
    pt_frame_t *frame = (pt_frame_t *) lua_topointer(L, -1);
    lua_pop(L, 1);

    /* For context switch from Pallene to Lua or vice versa. */
    /* We use the respective call-stack depending on the context.
     * In Lua context we use the Lua call-stack and in Pallene context
     * we use our self-maintained call stack. */
    /* 1: Lua, 0: Pallene */
    int context = 1;

    /* Current level of depth we are at in the Lua call stack. */
    int level   = 0;

    /* Are we done iterating through all the call-frames in the Lua stack? */
    bool gstack  = 0;

    /* Which context we were in previously? */
    /* The numeric representation is same as `context`. */
    int prev_context = 1;

    /* The frame signature. */
    ptrdiff_t frame_sig = frame->frame_sig;

    while(gstack || frame != NULL) {
        if(context) {
            /* Get lua call stack information. */
            lua_Debug ar;

            if(!(gstack = lua_getstack(L, level, &ar)))
                continue;

            level++;

            /* We need more info for a good traceback entry. */
            lua_getinfo(L, "Slntf", &ar);

            /* We have got a C frame. Time to make a context switch. */
            if(lua_iscfunction(L, -1)) {
                frame_sig = (ptrdiff_t) lua_tocfunction(L, -1);

                context = 0;
            } else {
                fprintf(stderr, "    %s:%d: in function '%s'\n", ar.short_src, ar.currentline,
                        ar.name != NULL ? ar.name : "<anonymous>");
            }

            lua_pop(L, 1);
            prev_context = 1;
        } else {
            /* If the frame signature does not match, then it's just a normal
               C function  */
            if(frame == NULL || frame->frame_sig != frame_sig) {
                /* If we switched from Lua and the frame signature is
                   not known, then function is just a C function oblivious to Pallene and Lua. */
                if(prev_context == 1)
                    fprintf(stderr, "    C Function: 0x%lx\n", (void *) frame_sig);

                context = 1;
                goto pallene_stack_done;
            }

            fprintf(stderr, "    %s:%d: in function '%s'\n", frame->mod_name, frame->line,
                    frame->fn_name);

            /* We are done, now go to the previous frame. */
            frame = frame->prev;

pallene_stack_done:
            prev_context = 0;
        }
    }

    /* Self frame. */
    pallene_tracer_frameexit(L);

    return 0;
}

static void pallene_tracer_init(lua_State *L) {
    lua_getglobal(L, "__pallene_tracer_stack_head");

    /* Setup the stack head, tail and custom pallene traceback fn. */
    if(l_likely(lua_isnil(L, -1) == true)) {
        lua_pushlightuserdata(L, NULL);
        lua_setglobal(L, "__pallene_tracer_stack_head");
        lua_pushlightuserdata(L, NULL);
        lua_setglobal(L, "__pallene_tracer_stack_tail");

        /* The debug traceback fn. */
        lua_register(L, "pallene_tracer_debug_traceback", pallene_tracer_debug_traceback);
    }
}

static const char *pallene_type_name(lua_State *L, const TValue *v)
{
    if (rawtt(v) == LUA_VNUMINT) {
        return "integer";
    } else if (rawtt(v) == LUA_VNUMFLT) {
        return "float";
    } else {
        return luaT_objtypename(L, v);
    }
}

static int pallene_is_truthy(const TValue *v)
{
    return !l_isfalse(v);
}

static int pallene_is_record(const TValue *v, const TValue *meta_table)
{
    return ttisfulluserdata(v) && uvalue(v)->metatable == hvalue(meta_table);
}

/* Starting with Lua 5.4-rc1, Lua the boolean type now has two variants, LUA_VTRUE and LUA_VFALSE.
 * The value of the boolean is encoded in the type tag instead of in the `Value` union. */
static int pallene_bvalue(TValue *obj)
{
    return ttistrue(obj);
}

static void pallene_setbvalue(TValue *obj, int b)
{
    if (b) {
        setbtvalue(obj);
    } else {
        setbfvalue(obj);
    }
}

/* We must call a GC write barrier whenever we set "v" as an element of "p", in order to preserve
 * the color invariants of the incremental GC. This function is a specialization of luaC_barrierback
 * for when we already know the type of the child object and have an untagged pointer to it. */
static void pallene_barrierback_unboxed(lua_State *L, GCObject *p, GCObject *v)
{
    if (isblack(p) && iswhite(v)) {
        luaC_barrierback_(L, p);
    }
}

static void pallene_runtime_tag_check_error(
    lua_State *L,
    const char* file,
    int line,
    const char *expected_type_name,
    const TValue *received_type,
    const char *description_fmt,
    ...
){
    const char *received_type_name = pallene_type_name(L, received_type);

    /* This code is inspired by luaL_error */
    luaL_where(L, 1);
    if (line > 0) {
        lua_pushfstring(L, "file %s: line %d: ", file, line);
    } else {
        lua_pushfstring(L, "");
    }
    lua_pushfstring(L, "wrong type for ");
    {
        va_list argp;
        va_start(argp, description_fmt);
        lua_pushvfstring(L, description_fmt, argp);
        va_end(argp);
    }
    lua_pushfstring(L, ", expected %s but found %s",
        expected_type_name, received_type_name);
    lua_concat(L, 5);
    PALLENE_GLOBAL_SETLINE(L, line);
    lua_error(L);
    PALLENE_UNREACHABLE;
}

static void pallene_runtime_arity_error(lua_State *L, const char *name, int expected, int received, int line)
{
    PALLENE_GLOBAL_SETLINE(L, line);
    luaL_error(L,
        "wrong number of arguments to function '%s', expected %d but received %d",
        name, expected, received
    );
    PALLENE_UNREACHABLE;
}

static void pallene_runtime_divide_by_zero_error(lua_State *L, const char* file, int line)
{
    PALLENE_GLOBAL_SETLINE(L, line);
    luaL_error(L, "file %s: line %d: attempt to divide by zero", file, line);
    PALLENE_UNREACHABLE;
}

static void pallene_runtime_mod_by_zero_error(lua_State *L, const char* file, int line)
{
    PALLENE_GLOBAL_SETLINE(L, line);
    luaL_error(L, "file %s: line %d: attempt to perform 'n%%0'", file, line);
    PALLENE_UNREACHABLE;
}

static void pallene_runtime_number_to_integer_error(lua_State *L, const char* file, int line)
{
    PALLENE_GLOBAL_SETLINE(L, line);
    luaL_error(L, "file %s: line %d: conversion from float does not fit into integer", file, line);
    PALLENE_UNREACHABLE;
}

static void pallene_runtime_array_metatable_error(lua_State *L, const char* file, int line)
{
    PALLENE_GLOBAL_SETLINE(L, line);
    luaL_error(L, "file %s: line %d: arrays in Pallene must not have a metatable", file, line);
    PALLENE_UNREACHABLE;
}

static l_noret pallene_runtime_cant_grow_stack_error(lua_State *L, int line)
{
    PALLENE_GLOBAL_SETLINE(L, line);
    luaL_error(L, "stack overflow");
    PALLENE_UNREACHABLE;
}

/* Lua and Pallene round integer division towards negative infinity, while C rounds towards zero.
 * Here we inline luaV_div, to allow the C compiler to constant-propagate. For an explanation of the
 * algorithm, see the comments for luaV_div. */
static lua_Integer pallene_int_divi(
    lua_State *L,
    lua_Integer m, lua_Integer n,
    const char* file, int line)
{
    if (l_castS2U(n) + 1u <= 1u) {
        if (n == 0){
            pallene_runtime_divide_by_zero_error(L, file, line);
        } else {
            return intop(-, 0, m);
        }
    } else {
        lua_Integer q = m / n;
        if ((m ^ n) < 0 && (m % n) != 0) {
            q -= 1;
        }
        return q;
    }
}

/* Lua and Pallene guarantee that (m == n*(m//n) + (m%n))
 * For details, see gen_int_div, luaV_div, and luaV_mod. */
static lua_Integer pallene_int_modi(
    lua_State *L,
    lua_Integer m, lua_Integer n,
    const char* file, int line)
{
    if (l_castS2U(n) + 1u <= 1u) {
        if (n == 0){
            pallene_runtime_mod_by_zero_error(L, file, line);
        } else {
            return 0;
        }
    } else {
        lua_Integer r = m % n;
        if (r != 0 && (m ^ n) < 0) {
            r += n;
        }
        return r;
    }
}

/* In C, there is undefined behavior if the shift amount is negative or is larger than the integer
 * width. On the other hand, Lua and Pallene specify the behavior in these cases (negative means
 * shift in the opposite direction, and large shifts saturate at zero).
 *
 * Most of the time, the shift amount is a compile-time constant, in which case the C compiler
 * should be able to simplify this down to a single shift instruction.  In the dynamic case with
 * unknown "y" this implementation is a little bit faster Lua because we put the most common case
 * under a single level of branching. (~20% speedup) */

#define PALLENE_NBITS  (sizeof(lua_Integer) * CHAR_BIT)

static lua_Integer pallene_shiftL(lua_Integer x, lua_Integer y)
{
    if (l_likely(l_castS2U(y) < PALLENE_NBITS)) {
        return intop(<<, x, y);
    } else {
        if (l_castS2U(-y) < PALLENE_NBITS) {
            return intop(>>, x, -y);
        } else {
            return 0;
        }
    }
}

static lua_Integer pallene_shiftR(lua_Integer x, lua_Integer y)
{
    if (l_likely(l_castS2U(y) < PALLENE_NBITS)) {
        return intop(>>, x, y);
    } else {
        if (l_castS2U(-y) < PALLENE_NBITS) {
            return intop(<<, x, -y);
        } else {
            return 0;
        }
    }
}

static void copy_strings_to_buffer(char *out_buf, size_t n, TString **ss)
{
    char *b = out_buf;
    for (size_t i = 0; i < n; i ++) {
        size_t l = tsslen(ss[i]);
        memcpy(b,  getstr(ss[i]), l);
        b += l;
    }
}

static TString *pallene_string_concatN(lua_State *L, size_t n, TString **ss)
{
    size_t out_len = 0;
    for (size_t i = 0; i < n; i++) {
        size_t l = tsslen(ss[i]);
        if (l_unlikely(l >= (MAX_SIZE/sizeof(char)) - out_len)) {
            luaL_error(L, "string length overflow");
        }
        out_len += l;
    }

    if (out_len <= LUAI_MAXSHORTLEN) {
        char buff[LUAI_MAXSHORTLEN];
        copy_strings_to_buffer(buff, n, ss);
        return luaS_newlstr(L, buff, out_len);
    } else {
        TString *out_str = luaS_createlngstrobj(L, out_len);
        char *buff = getstr(out_str);
        copy_strings_to_buffer(buff, n, ss);
        return out_str;
    }
}

/* These definitions are from ltable.c */
#define MAXABITS        cast_int(sizeof(int) * CHAR_BIT - 1)
#define MAXASIZE        luaM_limitN(1u << MAXABITS, TValue)

/* This version of lua_createtable bypasses the Lua stack, and can be inlined and optimized when the
 * allocation size is known at compilation time. */
static Table *pallene_createtable(lua_State *L, lua_Integer narray, lua_Integer nrec)
{
    Table *t = luaH_new(L);
    if (narray > 0 || nrec > 0) {
        luaH_resize(L, t, narray, nrec);
    }
    return t;
}

/* Grows the table so that it can fit index "i"
 * Our strategy is to grow to the next available power of 2. */
static void pallene_grow_array(lua_State *L, const char* file, int line, Table *arr, unsigned ui)
{
    if (ui >= MAXASIZE) {
        luaL_error(L, "file %s: line %d: invalid index for Pallene array", file, line);
    }

    /* This loop doesn't overflow because i < MAXASIZE and MAXASIZE is a power of two */
    size_t new_size = 1;
    while (ui >= new_size) {
        new_size *= 2;
    }

    luaH_resizearray(L, arr, new_size);
}

/* When reading and writing to a Pallene array, we force everything to fit inside the array part of
 * the table. The optimizer and branch predictor prefer when it is this way. */
static void pallene_renormalize_array(
    lua_State *L,
    Table *arr, lua_Integer i,
    const char* file,int line
){
    lua_Unsigned ui = (lua_Unsigned) i - 1;
    if (l_unlikely(ui >= arr->alimit)) {
        pallene_grow_array(L, file, line, arr, ui);
    }
}

/* These specializations of luaH_getstr and luaH_getshortstr introduce two optimizations:
 *   - After inlining, the length of the string is a compile-time constant
 *   - getshortstr's table lookup uses an inline cache. */

static const TValue PALLENE_ABSENTKEY = {ABSTKEYCONSTANT};

static TValue *pallene_getshortstr(Table *t, TString *key, int *restrict cache)
{
    if (0 <= *cache && *cache < sizenode(t)) {
       Node *n = gnode(t, *cache);
       if (keyisshrstr(n) && eqshrstr(keystrval(n), key))
           return gval(n);
    }
    Node *n = gnode(t, lmod(key->hash, sizenode(t)));
    for (;;) {
        if (keyisshrstr(n) && eqshrstr(keystrval(n), key)) {
            *cache = n - gnode(t, 0);
            return gval(n);
        }
        else {
            int nx = gnext(n);
            if (nx == 0) {
                /* It is slightly better to have an invalid cache when we don't expect the cache to
                 * hit. The code will be faster because getstr will jump straight to the key search
                 * instead of trying to access a cache that we expect to be a miss. */
                *cache = UINT_MAX;
                return (TValue *)&PALLENE_ABSENTKEY;  /* not found */
            }
            n += nx;
        }
    }
}

static TValue *pallene_getstr(size_t len, Table *t, TString *key, int *cache)
{
    if (len <= LUAI_MAXSHORTLEN) {
        return pallene_getshortstr(t, key, cache);
    } else {
        return cast(TValue *, luaH_getstr(t, key));
    }
}

/* Some Lua math functions return integer if the result fits in integer, or float if it doesn't.
 * In Pallene, we can't return different types, so we instead raise an error if it doesn't fit
 * See also: pushnumint in lmathlib */
static lua_Integer pallene_checked_float_to_int(
    lua_State *L, const char* file, int line, lua_Number d)
{
    lua_Integer n;
    if (lua_numbertointeger(d, &n)) {
        return n;
    } else {
        pallene_runtime_number_to_integer_error(L, file, line);
    }
}

static lua_Integer pallene_math_ceil(lua_State *L, const char* file, int line, lua_Number n)
{
    lua_Number d = l_mathop(ceil)(n);
    return pallene_checked_float_to_int(L, file, line, d);
}

static lua_Integer pallene_math_floor(lua_State *L, const char* file, int line, lua_Number n)
{
    lua_Number d = l_mathop(floor)(n);
    return pallene_checked_float_to_int(L, file, line, d);
}

/* Based on math_log from lmathlib.c
 * The C compiler should be able to get rid of the if statement if this function is inlined
 * and the base parameter is a compile-time constant */
static lua_Number pallene_math_log(lua_Integer x, lua_Integer base)
{
    if (base == l_mathop(10.0)) {
        return l_mathop(log10)(x);
#if !defined(LUA_USE_C89)
    } else if (base == l_mathop(2.0)) {
        return l_mathop(log2)(x);
#endif
    } else {
        return l_mathop(log)(x)/l_mathop(log)(base);
    }
}

static lua_Integer pallene_math_modf(
    lua_State *L, const char* file, int line, lua_Number n, lua_Number* out)
{
    /* integer part (rounds toward zero) */
    lua_Number ip = (n < 0) ? l_mathop(ceil)(n) : l_mathop(floor)(n);
    /* fractional part (test needed for inf/-inf) */
    *out = (n == ip) ? l_mathop(0.0) : (n - ip);
    return pallene_checked_float_to_int(L, file, line, ip);
}

static TString* pallene_string_char(lua_State *L, const char* file, int line, lua_Integer c)
{
    if (l_castS2U(c) > UCHAR_MAX) {
        luaL_error(L, "file %s: line %d: char value out of range", file, line);
    }

    char buff[2];
    buff[0] = c;
    buff[1] = '\0';
    return luaS_newlstr(L, buff, 1);
}

/* Translate a relative initial string position. (Negative means back from end)
 * Clip result to [1, inf). See posrelatI() in lstrlib.c
 */
static size_t get_start_pos(lua_Integer pos, size_t len)
{
    if (pos > 0) {
        return (size_t)pos;
    } else if (pos == 0) {
        return 1;
    } else if (pos < -(lua_Integer)len) {
        return 1;
    } else {
        return len + (size_t)pos + 1;
    }
}

/* Clip i between [0, len]. Negative means back from end.
 * See getendpos() in lstrlib.c */
static size_t get_end_pos(lua_Integer pos, size_t len)
{
    if (pos > (lua_Integer)len) {
        return len;
    } else if (pos >= 0) {
        return (size_t)pos;
    } else if (pos < -(lua_Integer)len) {
        return 0;
    } else {
        return len + (size_t)pos + 1;
    }
}

static TString* pallene_string_sub(
        lua_State *L, TString *str, lua_Integer istart, lua_Integer iend)
{
    const char *s = getstr(str);
    size_t len = tsslen(str);
    size_t start = get_start_pos(istart, len);
    size_t end = get_end_pos(iend, len);
    if (start <= end) {
        return luaS_newlstr(L, s + start - 1, (end - start) + 1);
    } else {
        return luaS_new(L, "");
    }
}

static TString *pallene_type_builtin(lua_State *L, TValue v) {
    return luaS_new(L, lua_typename(L, ttype(&v)));
}

/* Based on function luaL_tolstring */
static TString *pallene_tostring(lua_State *L, const char* file, int line, TValue v) {
    #define MAXNUMBER2STR	50
    int len;
    char buff[MAXNUMBER2STR];
    switch (ttype(&v)) {
        case LUA_TNUMBER: {
            if (ttisinteger(&v)) {
                len = lua_integer2str(buff, MAXNUMBER2STR, ivalue(&v));
            } else {
                len = lua_number2str(buff, MAXNUMBER2STR, fltvalue(&v));
                if (buff[strspn(buff, "-0123456789")] == '\0') {  /* looks like an int? */
                  buff[len++] = lua_getlocaledecpoint();
                  buff[len++] = '0';  /* adds '.0' to result */
                }
            }
            return luaS_newlstr(L, buff, len);
        }
        case LUA_TSTRING:
            return luaS_new(L, svalue(&v));
        case LUA_TBOOLEAN:
            return luaS_new(L, ((pallene_is_truthy(&v)) ? "true" : "false"));
        default: {
            luaL_error(L, "file %s: line %d: tostring called with unsuported type '%s'", file, line,
                lua_typename(L, ttype(&v)));
            PALLENE_UNREACHABLE;
        }
    }
}

/* A version of io.write specialized to a single string argument */
static void pallene_io_write(lua_State *L, TString *str)
{
    (void) L; /* unused parameter */
    const char *s = getstr(str);
    size_t len = tsslen(str);
    fwrite(s, 1, len, stdout);
}

/* To avoid looping infinitely due to integer overflow, lua 5.4 carefully computes the number of
 * iterations before starting the loop (see op_forprep). the code that implements this behavior does
 * not look like a regular c for loop, so to help improve the readability of the generated c code we
 * hide it behind the following set of macros. note that some of the open braces in the begin macro
 * are only closed in the end macro, so they must always be used together. we assume that the c
 * compiler will be able to optimize the common case where the step parameter is a compile-time
 * constant. */

#define PALLENE_INT_FOR_LOOP_BEGIN(i, A, B, C) \
    { \
        lua_Integer _init  = A; \
        lua_Integer _limit = B; \
        lua_Integer _step  = C; \
        if (_step == 0 ) { \
            luaL_error(L, "'for' step is zero"); \
        } \
        if (_step > 0 ? (_init <= _limit) : (_init >= _limit)) {        \
            lua_Unsigned _uinit  = l_castS2U(_init);                    \
            lua_Unsigned _ulimit = l_castS2U(_limit);                   \
            lua_Unsigned _count = ( _step > 0                           \
                ? (_ulimit - _uinit) / _step                            \
                : (_uinit - _ulimit) / (l_castS2U(-(_step + 1)) + 1u)); \
            lua_Integer _loopvar = _init; \
            while (1) { \
                i = _loopvar; \
                {
                    /* Loop body goes here*/

#define PALLENE_INT_FOR_LOOP_END \
                } \
                if (_count == 0) break; \
                _loopvar += _step; \
                _count -= 1; \
            } \
        } \
    }


#define PALLENE_FLT_FOR_LOOP_BEGIN(i, A, B, C) \
    { \
        lua_Number _init  = A; \
        lua_Number _limit = B; \
        lua_Number _step  = C; \
        if (_step == 0.0) { \
            luaL_error(L, "'for' step is zero"); \
        } \
        for ( \
            lua_Number _loopvar = _init; \
            (_step > 0.0 ? (_loopvar <= _limit) : (_loopvar >= _limit)); \
            _loopvar += _step \
        ){ \
            i = _loopvar;
            /* Loop body goes here*/

#define PALLENE_FLT_FOR_LOOP_END \
        } \
    }


]==]
