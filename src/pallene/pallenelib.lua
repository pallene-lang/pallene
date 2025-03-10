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
#include <stdlib.h>

/* Pallene Tracer for function call tracebacks. */
/* Look at `https://github.com/pallene-lang/pallene-tracer` for more info. */
#define  PT_IMPLEMENTATION
#include <ptracer.h>

#define PALLENE_UNREACHABLE __builtin_unreachable()

/* PALLENE TRACER HELPER MACROS */

#ifdef PT_DEBUG
/* Prepares finalizer function for Lua interface calls. */
#define PALLENE_PREPARE_FINALIZER()                              \
    setobj(L, s2v(L->top.p++), &K->uv[1].uv);                    \
    lua_toclose(L, -1)

#define PALLENE_GET_FNSTACK()                                    \
    pt_fnstack_t *fnstack = pvalue(&K->uv[0].uv)

#define PALLENE_PREPARE_C_FRAME(name)                            \
    PALLENE_GET_FNSTACK();                                       \
    static pt_fn_details_t _details =                            \
        PALLENE_TRACER_FN_DETAILS(name, PALLENE_SOURCE_FILE);    \
    pt_frame_t _frame =                                          \
        PALLENE_TRACER_C_FRAME(_details)

#define PALLENE_PREPARE_LUA_FRAME(fnptr)                         \
    PALLENE_GET_FNSTACK();                                       \
    pt_frame_t _frame =                                          \
        PALLENE_TRACER_LUA_FRAME(fnptr)

#else
#define PALLENE_PREPARE_FINALIZER()
#define PALLENE_PREPARE_C_FRAME(name)
#define PALLENE_PREPARE_LUA_FRAME(fnptr)
#endif // PT_DEBUG

#define PALLENE_C_FRAMEENTER(name)                               \
    PALLENE_PREPARE_C_FRAME(name);                               \
    PALLENE_TRACER_FRAMEENTER(fnstack, &_frame);

#define PALLENE_LUA_FRAMEENTER(fnptr)                            \
    PALLENE_PREPARE_LUA_FRAME(fnptr);                            \
    PALLENE_TRACER_FRAMEENTER(fnstack, &_frame);                 \
    PALLENE_PREPARE_FINALIZER()

#define PALLENE_SETLINE(line)           PALLENE_TRACER_SETLINE(fnstack, line)
#define PALLENE_FRAMEEXIT()             PALLENE_TRACER_FRAMEEXIT(fnstack)

/* Type tags */
static const char *pallene_type_name(lua_State *L, const TValue *v);
static int pallene_is_truthy(const TValue *v);
static int pallene_is_record(const TValue *v, const TValue *meta_table);
static int pallene_bvalue(TValue *obj);
static void pallene_setbvalue(TValue *obj, int b);

/* Runtime errors */
static l_noret pallene_runtime_tag_check_error(lua_State *L, const char* file, int line,
                                const char *expected_type_name, const TValue *received_type, const char *description_fmt, ...);
static l_noret pallene_runtime_arity_error(lua_State *L, const char *name, int min_nargs, int max_nargs, int received);
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
static lua_Number  pallene_math_log(lua_State *L, lua_Number x, TValue optbase);
static lua_Integer pallene_math_modf(lua_State *L, const char* file, int line, lua_Number n, lua_Number* out);

/* Other builtins */
static TString *pallene_string_char(lua_State *L, const char* file, int line, lua_Integer c);
static TString *pallene_string_sub(lua_State *L, TString *str, lua_Integer start, lua_Integer end);
static TString *pallene_type_builtin(lua_State *L, TValue v);
static TString *pallene_tostring(lua_State *L, const char* file, int line, TValue v);
static void pallene_io_write(lua_State *L, TString *str);

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

static l_noret pallene_runtime_tag_check_error(
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

static l_noret pallene_runtime_arity_error(
    lua_State *L,
    const char *name,
    int min_nargs,
    int max_nargs,
    int received)
{
    if (min_nargs == max_nargs) {
        luaL_error(L,
            "wrong number of arguments to function '%s', expected %d but received %d",
            name, min_nargs, received
        );
    } else if (received < min_nargs) {
        luaL_error(L,
            "wrong number of arguments to function '%s', expected at least %d but received %d",
            name, min_nargs, received
        );
    } else { /* received > max_nargs */
        luaL_error(L,
            "wrong number of arguments to function '%s', expected at most %d but received %d",
            name, max_nargs, received
        );
    }
    PALLENE_UNREACHABLE;
}

static l_noret pallene_runtime_divide_by_zero_error(lua_State *L, const char* file, int line)
{
    luaL_error(L, "file %s: line %d: attempt to divide by zero", file, line);
    PALLENE_UNREACHABLE;
}

static l_noret pallene_runtime_mod_by_zero_error(lua_State *L, const char* file, int line)
{
    luaL_error(L, "file %s: line %d: attempt to perform 'n%%0'", file, line);
    PALLENE_UNREACHABLE;
}

static l_noret pallene_runtime_number_to_integer_error(lua_State *L, const char* file, int line)
{
    luaL_error(L, "file %s: line %d: conversion from float does not fit into integer", file, line);
    PALLENE_UNREACHABLE;
}

static l_noret pallene_runtime_array_metatable_error(lua_State *L, const char* file, int line)
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
static lua_Number pallene_math_log(lua_State *L, lua_Number x, TValue optbase)
{

    if (ttisnil(&optbase)) {
        return l_mathop(log)(x);
    } else {
        lua_Number base;
        if (ttisfloat(&optbase)) {
            base = fltvalue(&optbase);
        } else if (ttisinteger(&optbase)) {
            base = cast(lua_Number, ivalue(&optbase));
        } else {
            luaL_error(L, "math log expects a number");
            PALLENE_UNREACHABLE;
        }

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

/* Based on math_atan from lmathlib.c */
static lua_Number pallene_math_atan(lua_State *L, lua_Number y, TValue optx)
{
    lua_Number x;
    if (ttisnil(&optx)) {
        x = 1;
    } else {
        if (ttisfloat(&optx)) {
            x = fltvalue(&optx);
        } else if (ttisinteger(&optx)) {
            x = cast(lua_Number, ivalue(&optx));
        } else {
            luaL_error(L, "math atan expects a number");
            PALLENE_UNREACHABLE;
        }
    }
    return l_mathop(atan2)(y, x);
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
            return luaS_new(L, getstr(tsvalue(&v)));
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
 * hide it behind the following set of macros. we assume that the c compiler will be able to
 * optimize the common case where the step parameter is a compile-time constant. */

#define PALLENE_INT_FOR_PREP(i_, cond_, itervar_, count_, A, B, C) \
    { \
        lua_Integer _start  = A; \
        lua_Integer _limit  = B; \
        lua_Integer _step   = C; \
        if (_step == 0 ) { \
            luaL_error(L, "'for' step is zero"); \
        } \
        cond_ = _step > 0 ? (_start <= _limit) : (_start >= _limit); \
        count_ = ( _step > 0 \
            ? (l_castS2U(_limit) - l_castS2U(_start)) / _step \
            : (l_castS2U(_start) - l_castS2U(_limit)) / (l_castS2U(-(_step + 1)) + 1u)); \
        i_ = itervar_ = _start; \
    }

#define PALLENE_INT_FOR_STEP(i_, cond_, itervar_, count_, start_, limit_, step_) \
    cond_    = (count_ == 0); \
    itervar_ = l_castS2U(itervar_) + l_castS2U(step_); \
    i_       = itervar_; \
    count_   = l_castS2U(count_) - 1llu;

#define PALLENE_FLT_FOR_PREP(i_, cond_, itervar_, count_, A, B, C) \
    { \
        lua_Number _start  = A; \
        lua_Number _limit  = B; \
        lua_Number _step   = C; \
        if (_step == 0 ) { \
            luaL_error(L, "'for' step is zero"); \
        } \
        cond_ = _step > 0 ? (_start <= _limit) : (_start >= _limit); \
        i_ = itervar_ = _start; \
    }

#define PALLENE_FLT_FOR_STEP(i_, cond_, itervar_, count_, A, B, C) \
    { \
        lua_Number _limit  = B; \
        lua_Number _step   = C; \
        itervar_ += _step; \
        i_       = itervar_; \
        cond_ = _step > 0.0 ? (itervar_ > _limit) : (itervar_ < _limit); \
    }

]==]
