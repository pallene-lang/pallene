#ifndef TCORE_H
#define TCORE_H

#include "lapi.h"

#define TITAN_NORETURN __attribute__((noreturn))
#define TITAN_UNREACHABLE __builtin_unreachable()

#define TITAN_LIKELY(x)   __builtin_expect(!!(x), 1)
#define TITAN_UNLIKELY(x) __builtin_expect(!!(x), 0)

#define TITAN_LUAINTEGER_NBITS  cast_int(sizeof(lua_Integer) * CHAR_BIT)

const char *titan_tag_name(int raw_tag);

void titan_runtime_arity_error(
    lua_State *L, int expected, int received)
    TITAN_NORETURN;

void titan_runtime_argument_type_error(
    lua_State *L, const char *param_name, int line, int expected_tag,
    TValue *slot)
    TITAN_NORETURN;

void titan_runtime_array_type_error(
    lua_State *L, int line, int expected_tag, const TValue *slot)
    TITAN_NORETURN;

void titan_runtime_function_return_error(
    lua_State *L, int line, int expected_tag, const TValue *slot)
    TITAN_NORETURN;

void titan_runtime_divide_by_zero_error(
    lua_State *L, int line)
    TITAN_NORETURN;

void titan_runtime_mod_by_zero_error(
    lua_State *L, int line)
    TITAN_NORETURN;

#endif
