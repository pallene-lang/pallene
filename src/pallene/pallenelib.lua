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
#define PALLENE_C_FRAMEENTER(cont, name)                         \
        static pt_fn_details_t _details = {                      \
            .fn_name  = name,                                    \
            .mod_name = PALLENE_SOURCE_FILE                      \
        };                                                       \
        pt_frame_t _frame = {                                    \
            .type = PALLENE_TRACER_FRAME_TYPE_C,                 \
            .shared = {                                          \
                .details = &_details                             \
            }                                                    \
        };                                                       \
        pallene_tracer_frameenter(cont, &_frame)

#define PALLENE_LUA_FRAMEENTER(cont, sig)                        \
        pt_frame_t _frame = {                                    \
            .type = PALLENE_TRACER_FRAME_TYPE_LUA,               \
            .shared = {                                          \
                .frame_sig = sig                                 \
            }                                                    \
        };                                                       \
        pallene_tracer_frameenter(cont, &_frame)

#define PALLENE_SETLINE(line)           pallene_tracer_setline(&_frame, line)
#define PALLENE_FRAMEEXIT(cont)         pallene_tracer_frameexit(cont)

/* Pallene stack reference entry for the registry. */
#define PALLENE_TRACER_STACK_ENTRY      "__PALLENE_TRACER_STACK"

/* Traceback elipsis threshold. */
#define PALLENE_TRACEBACK_TOP_THRESHOLD      10
/* This should always be 2 fewer than top threshold, for symmetry.
   Becuase we will always have 2 tail frames lingering around at
   at the end which is not captured by '_countlevels'. */
#define PALLENE_TRACEBACK_BOTTOM_THRESHOLD    8

/* PALLENE TRACER RELATED DATA-STRUCTURES. */

/* Whether the frame is a Pallene->Pallene or Lua->Pallene call. */
typedef enum frame_type {
    PALLENE_TRACER_FRAME_TYPE_C,
    PALLENE_TRACER_FRAME_TYPE_LUA
} frame_type_t;

/* Details of a single function such as what is the name
   and where it is from. */
typedef struct pt_fn_details {
    const char *const fn_name;
    const char *const mod_name;
} pt_fn_details_t;

/* A single frame representation. */
typedef struct pt_frame {
    frame_type_t type;
    int line;

    union {
            const pt_fn_details_t *details;
            const lua_CFunction frame_sig;
    } shared;

    struct pt_frame *prev;
} pt_frame_t;

/* For Full Userdata allocation. That userdata is the module singular
   point for Pallene stack. */
/* 'cont' stands for 'container'. */
typedef struct pt_cont {
    pt_frame_t *stack;
} pt_cont_t;

/* Pallene Tracer. */
static void       pallene_tracer_frameenter(pt_cont_t *cont, pt_frame_t *restrict frame);
static void       pallene_tracer_setline(pt_frame_t *restrict frame, int line);
static void       pallene_tracer_frameexit(pt_cont_t *cont);
static int        pallene_tracer_debug_traceback(lua_State *L);
static pt_cont_t *pallene_tracer_init(lua_State *L);

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
static l_noret pallene_runtime_arity_error(lua_State *L, const char *name, int expected, int received);
static l_noret pallene_runtime_divide_by_zero_error(lua_State *L, const char* file, int line);
static l_noret pallene_runtime_mod_by_zero_error(lua_State *L, const char* file, int line);
static l_noret pallene_runtime_number_to_integer_error(lua_State *L, const char* file, int line);
static l_noret pallene_runtime_array_metatable_error(lua_State *L, const char* file, int line);
static l_noret pallene_runtime_cant_grow_stack_error(lua_State *L);

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

/* Private routines. */

static bool _findfield(lua_State *L, int fn_idx, int level) {
    if(level == 0 || !lua_istable(L, -1))
        return false;

    lua_pushnil(L);    /* Initial key. */

    while(lua_next(L, -2)) {
        /* We are only interested in String keys. */
        if(lua_type(L, -2) == LUA_TSTRING) {
            /* Avoid "_G" recursion in global table. The global table is also part of
               global table. */
            if(!strcmp(lua_tostring(L, -2), "_G")) {
                /* Remove value and continue. */
                lua_pop(L, 1);
                continue;
            }

            /* Is it the function we are looking for? */
            if(lua_rawequal(L, fn_idx, -1)) {
                /* Remove value and keep name. */
                lua_pop(L, 1);

                return true;
            }
            /* If not go one level deeper and get the value recursively. */
            if(_findfield(L, fn_idx, level - 1)) {
                /* Remove the table but keep name. */
                lua_remove(L, -2);

                /* Add a "." in between. */
                lua_pushliteral(L, ".");
                lua_insert(L, -2);

                /* Concatenate last 3 values, resulting "table.some_func". */
                lua_concat(L, 3);

                return true;
            }
        }

        /* Pop the value. */
        lua_pop(L, 1);
    }

    return false;
}

/* Pushes a function name if found in the global table and returns true.
   Returns false otherwise. */
/* Expects the function to be pushed in the stack. */
static bool _pgf_name(lua_State *L) {
    int top = lua_gettop(L);

    lua_pushglobaltable(L);

    if(_findfield(L, top, 2)) {
        lua_remove(L, -2);

        return true;
    }

    lua_pop(L, 1);
    return false;
}

/* Returns the maximum number of levels in Lua stack. */
static int _countlevels (lua_State *L) {
    lua_Debug ar;
    int li = 1, le = 1;

    /* Find an upper bound */
    while (lua_getstack(L, le, &ar)) {
        li = le, le *= 2;
    }

    /* Do a binary search */
    while (li < le) {
        int m = (li + le)/2;

        if (lua_getstack(L, m, &ar)) li = m + 1;
        else le = m;
    }

    return le - 1;
}

/* Counts the number of white and black frames in the Pallene call stack. */
static void _countframes(pt_frame_t *frame, int *mwhite, int *mblack) {
    *mwhite = *mblack = 0;

    while(frame != NULL) {
        *mwhite += (frame->type == PALLENE_TRACER_FRAME_TYPE_C);
        *mblack += (frame->type == PALLENE_TRACER_FRAME_TYPE_LUA);
        frame = frame->prev;
    }
}

/* Responsible for printing and controlling some of the traceback fn parameters. */
static void _dbg_print(const char *buf, bool *elipsis, int *pframes, int nframes) {
    /* We have printed the frame, even tho it might not be visible ;). */
    (*pframes)++;

    /* Should we print? Are we in the point in top or bottom printing threshold? */
    bool should_print = (*pframes <= PALLENE_TRACEBACK_TOP_THRESHOLD)
        || ((nframes - *pframes) <= PALLENE_TRACEBACK_BOTTOM_THRESHOLD);

    if(should_print)
        fprintf(stderr, buf);
    else if(*elipsis) {
        fprintf(stderr, "\n    ... (Skipped %d frames) ...\n\n",
            nframes - (PALLENE_TRACEBACK_TOP_THRESHOLD
            + PALLENE_TRACEBACK_BOTTOM_THRESHOLD));

        *elipsis = false;
    }
}

/* Private routines end. */

static void pallene_tracer_frameenter(pt_cont_t *cont, pt_frame_t *restrict frame) {
    /* If there is no frame in the Pallene stack. */
    if(l_unlikely(cont->stack == NULL)) {
        frame->prev = NULL;
        cont->stack = frame;

        return;
    }

    frame->prev = cont->stack;
    cont->stack = frame;
}

static void pallene_tracer_setline(pt_frame_t *restrict frame, int line) {
    frame->line = line;
}

static void pallene_tracer_frameexit(pt_cont_t *cont) {
    /* We are popping the very last frame. */
    if(cont->stack->prev == NULL) {
        cont->stack = NULL;
        return;
    }

    cont->stack = cont->stack->prev;
}

/* Helper macro specific to this function only :). */
#define DBG_PRINT() _dbg_print(buf, &elipsis, &pframes, nframes)
static int pallene_tracer_debug_traceback(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, PALLENE_TRACER_STACK_ENTRY);
    pt_frame_t *stack = ((pt_cont_t *) lua_touserdata(L, -1))->stack;
    lua_pop(L, 1);

    /* Max number of white and black frames. */
    int mwhite, mblack;
    _countframes(stack, &mwhite, &mblack);
    /* Max levels of Lua stack. */
    int mlevel = _countlevels(L);

    /* Total frames we are going to print. */
    /* Black frames are used for switching and we will start from
       Lua stack level 1. */
    int nframes = mlevel + mwhite - mblack - 1;
    /* Amount of frames printed. */
    int pframes = 0;
    /* Should we print elipsis? */
    bool elipsis = nframes > (PALLENE_TRACEBACK_TOP_THRESHOLD
        + PALLENE_TRACEBACK_BOTTOM_THRESHOLD);

    /* Buffer to store a single frame line to be printed. */
    char buf[1024];

    const char *message = lua_tostring(L, 1);
    fprintf(stderr, "Runtime error: %s\nStack traceback:\n", message);

    lua_Debug ar;
    int top = lua_gettop(L);
    int level = 1;

    while(lua_getstack(L, level++, &ar)) {
        /* Get additional information regarding the frame. */
        lua_getinfo(L, "Slntf", &ar);

        /* If the frame is a C frame. */
        if(lua_iscfunction(L, -1)) {
            if(stack != NULL) {
                /* Check whether this frame is tracked (Pallene C frames). */
                pt_frame_t *check = stack;
                while(check->type != PALLENE_TRACER_FRAME_TYPE_LUA)
                    check = check->prev;

                /* If the frame signature matches, we switch to printing Pallene frames. */
                if(lua_tocfunction(L, -1) == check->shared.frame_sig) {
                    /* Now print all the frames in Pallene stack. */
                    while(stack != check) {
                        sprintf(buf, "    %s:%d: in function '%s'\n",
                            stack->shared.details->mod_name,
                            stack->line, stack->shared.details->fn_name);
                        DBG_PRINT();

                        stack = stack->prev;
                    }

                    /* 'check' is guaranteed to be a Lua interface frame.
                       Which is basically our 'stack' at this point. So,
                       we simply ignore the Lua interface frame. */
                    stack = stack->prev;

                    /* We are done. */
                    lua_settop(L, top);
                    continue;
                }
            }

            /* Then it's an untracked C frame. */
            if(_pgf_name(L))
                lua_pushfstring(L, "%s", lua_tostring(L, -1));
            else lua_pushliteral(L, "<?>");

            sprintf(buf, "    C: in function '%s'\n", lua_tostring(L, -1));
            DBG_PRINT();
        } else {
            /* It's a Lua frame. */

            /* Do we have a name? */
            if(*ar.namewhat != '\0')
                lua_pushfstring(L, "function '%s'", ar.name);
            /* Is it the main chunk? */
            else if(*ar.what == 'm')
                lua_pushliteral(L, "<main>");
            /* Can we deduce the name from the global table? */
            else if(_pgf_name(L))
                lua_pushfstring(L, "function '%s'", lua_tostring(L, -1));
            else lua_pushliteral(L, "function '<?>'");

            sprintf(buf, "    %s:%d: in %s\n", ar.short_src,
                ar.currentline, lua_tostring(L, -1));
            DBG_PRINT();
        }

        lua_settop(L, top);
    }

    return 0;
}
#undef DBG_PRINT

static pt_cont_t *pallene_tracer_init(lua_State *L) {
    pt_cont_t *cont = NULL;

    /* Try getting the userdata. */
    lua_getfield(L, LUA_REGISTRYINDEX, PALLENE_TRACER_STACK_ENTRY);

    /* If we don't find any userdata, create one. */
    if(l_unlikely(lua_isnil(L, -1) == 1)) {
        cont = (pt_cont_t *) lua_newuserdata(L, sizeof(pt_cont_t));
        cont->stack = NULL;

        lua_setfield(L, LUA_REGISTRYINDEX, PALLENE_TRACER_STACK_ENTRY);

        /* The debug traceback fn. */
        lua_register(L, "pallene_tracer_debug_traceback", pallene_tracer_debug_traceback);
    } else {
        cont = lua_touserdata(L, -1);
    }

    return cont;
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
    lua_error(L);
    PALLENE_UNREACHABLE;
}

static void pallene_runtime_arity_error(lua_State *L, const char *name, int expected, int received)
{
    luaL_error(L,
        "wrong number of arguments to function '%s', expected %d but received %d",
        name, expected, received
    );
    PALLENE_UNREACHABLE;
}

static void pallene_runtime_divide_by_zero_error(lua_State *L, const char* file, int line)
{
    luaL_error(L, "file %s: line %d: attempt to divide by zero", file, line);
    PALLENE_UNREACHABLE;
}

static void pallene_runtime_mod_by_zero_error(lua_State *L, const char* file, int line)
{
    luaL_error(L, "file %s: line %d: attempt to perform 'n%%0'", file, line);
    PALLENE_UNREACHABLE;
}

static void pallene_runtime_number_to_integer_error(lua_State *L, const char* file, int line)
{
    luaL_error(L, "file %s: line %d: conversion from float does not fit into integer", file, line);
    PALLENE_UNREACHABLE;
}

static void pallene_runtime_array_metatable_error(lua_State *L, const char* file, int line)
{
    luaL_error(L, "file %s: line %d: arrays in Pallene must not have a metatable", file, line);
    PALLENE_UNREACHABLE;
}

static l_noret pallene_runtime_cant_grow_stack_error(lua_State *L)
{
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
