#ifndef PALLENE_CORE_H
#define PALLENE_CORE_H

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "lapi.h"
#include "ldo.h"
#include "lfunc.h"
#include "lgc.h"
#include "lobject.h"
#include "lstate.h"
#include "lstring.h"
#include "ltable.h"
#include "lvm.h"

#include <math.h>


#define PALLENE_NORETURN __attribute__((noreturn))
#define PALLENE_UNREACHABLE __builtin_unreachable()

#define PALLENE_LIKELY(x)   __builtin_expect(!!(x), 1)
#define PALLENE_UNLIKELY(x) __builtin_expect(!!(x), 0)

#define PALLENE_LUAINTEGER_NBITS  cast_int(sizeof(lua_Integer) * CHAR_BIT)


const char *pallene_tag_name(int raw_tag);

void pallene_runtime_tag_check_error(
    lua_State *L, int line, int expected_tag, int received_tag,
    const char *description_fmt, ...)
    PALLENE_NORETURN;

void pallene_runtime_arity_error(
    lua_State *L, const char *name, int expected, int received)
    PALLENE_NORETURN;

void pallene_runtime_divide_by_zero_error(
    lua_State *L, int line)
    PALLENE_NORETURN;

void pallene_runtime_mod_by_zero_error(
    lua_State *L, int line)
    PALLENE_NORETURN;

int pallene_runtime_record_nonstr_error(
    lua_State *L, int received_tag)
    PALLENE_NORETURN;

int pallene_runtime_record_index_error(
    lua_State *L, const char *key)
    PALLENE_NORETURN;

TString *pallene_string_concatN(
    lua_State *L, size_t n, TString **ss);

void pallene_grow_array(
    lua_State *L, Table *arr, unsigned int ui, int line);

void pallene_io_write(
    lua_State *L, TString *str);

TString* pallene_string_char(
    lua_State *L, lua_Integer c, int line);

TString* pallene_string_sub(
    lua_State *L, TString *str, lua_Integer start, lua_Integer end);

int pallene_l_strcmp(
    const TString *ls, const TString *rs);

/* --------------------------- */
/* Inline functions and macros */
/* --------------------------- */

/* This is a workaround to avoid -Wmaybe-uninitialized warnings with GCC. If we
 * initialize a TValue with setnilvalue and then follow that with a setobj, GCC
 * complains that the setobj might be reading from an uninitialized obj->value_.
 *
 * To placate the compiler we write some bogus data to the value field whenever
 * we would initialize a TValue with nil. In theory this should not have a
 * noticeable performance impact because it only affects nil literals and
 * variables of type nil. */
static inline
void pallene_setnilvalue(TValue *obj)
{
    val_(obj).b = 0;
    setnilvalue(obj);
}

/* We must call these write barriers whenever we set "v" as an element of "p",
 * in order to preserve the color invariants of the incremental GC.
 *
 * These implementations are specializations of luaC_barrierback tha check at
 * compile time if the child object is collectible. Additionally, the in this
 * version of the macro "p" and "v" receive internal object pointers (the ones
 * described by ctype()). */
#define pallene_barrierback_unknown_child(L, p, v) \
    if (iscollectable(v) && isblack(obj2gco(p)) && iswhite(gcvalue(v))) { \
        luaC_barrierback_(L, obj2gco(p));                                  \
    }
#define pallene_barrierback_collectable_child(L, p, v) \
    if (isblack(obj2gco(p)) && iswhite(obj2gco(v))) { \
        luaC_barrierback_(L, obj2gco(p));             \
    }

/* Lua and Pallene round integer division towards negative infinity, while C
 * rounds towards zero. Here we inline luaV_div, to allow the C compiler to
 * constant-propagate. For an explanation of the algorithm, see the comments
 * for luaV_div. */
static inline
lua_Integer pallene_int_divi(
    lua_State *L,
    lua_Integer m, lua_Integer n,
    int line)
{
    if (l_castS2U(n) + 1u <= 1u) {
        if (n == 0){
            pallene_runtime_divide_by_zero_error(L, line);
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
static inline
lua_Integer pallene_int_modi(
    lua_State *L,
    lua_Integer m, lua_Integer n,
    int line)
{
    if (l_castS2U(n) + 1u <= 1u) {
        if (n == 0){
            pallene_runtime_mod_by_zero_error(L, line);
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

/* In C, there is undefined behavior if the shift ammount is negative or is
 * larger than the integer width. On the other hand, Lua and Pallene specify the
 * behavior in these cases (negative means shift in the opposite direction, and
 * large shifts saturate at zero).
 *
 * Most of the time, the shift amount is a compile-time constant, in which case
 * the C compiler should be able to simplify this down to a single shift
 * instruction.  In the dynamic case with unknown "y" this implementation is a
 * little bit faster Lua because we put the most common case under a single
 * level of branching. (~20% speedup) */
static inline
lua_Integer pallene_shiftL(lua_Integer x, lua_Integer y)
{
    if (PALLENE_LIKELY(l_castS2U(y) < PALLENE_LUAINTEGER_NBITS)) {
        return intop(<<, x, y);
    } else {
        if (l_castS2U(-y) < PALLENE_LUAINTEGER_NBITS) {
            return intop(>>, x, -y);
        } else {
            return 0;
        }
    }
}
static inline
lua_Integer pallene_shiftR(lua_Integer x, lua_Integer y)
{
    if (PALLENE_LIKELY(l_castS2U(y) < PALLENE_LUAINTEGER_NBITS)) {
        return intop(>>, x, y);
    } else {
        if (l_castS2U(-y) < PALLENE_LUAINTEGER_NBITS) {
            return intop(<<, x, -y);
        } else {
            return 0;
        }
    }
}


/* Similar to lua_createtable*/
static inline
Table *pallene_new_array(lua_State *L, lua_Integer n)
{
    Table *t = luaH_new(L);
    if (n > 0) {
        luaH_resizearray(L, t, n);
    }
    return t;
}

/* When reading and writing to a Pallene array, we force everything to fit
 * inside the array part of the table. The optimizer and branch predictor prefer
 * when it is this way. */
static inline
void pallene_renormalize_array(
    lua_State *L,
    Table *arr,
    lua_Integer i,
    int line
){
    lua_Unsigned ui = (lua_Unsigned) i - 1;
    if (PALLENE_UNLIKELY(ui >= arr->alimit)) {
        pallene_grow_array(L, arr, ui, line);
    }
}


#endif
