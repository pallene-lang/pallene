#include "tcore.h"

#include "lua.h"
#include "lauxlib.h"

#include "lmem.h"
#include "lobject.h"
#include "lstate.h"
#include "lstring.h"
#include "ltm.h"
#include "ltable.h"

#include <string.h>

const char *titan_tag_name(int raw_tag)
{
    if (raw_tag == LUA_TNUMINT) {
        return "integer";
    } else if (raw_tag == LUA_TNUMFLT) {
        return "float";
    } else {
        return ttypename(novariant(raw_tag));
    }
}

void titan_runtime_arity_error(
    lua_State *L,
    int expected,
    int received
){
    luaL_error(
        L,
        "wrong number of arguments to function, expected %d but received %d",
        expected, received
    );
    TITAN_UNREACHABLE;
}

void titan_runtime_argument_type_error(
    lua_State *L,
    const char *param_name,
    int line,
    int expected_tag,
    TValue *slot
){
    const char *expected_type = titan_tag_name(expected_tag);
    const char *received_type = titan_tag_name(rawtt(slot));
    luaL_error(
        L,
        "wrong type for argument %s at line %d, expected %s but found %s",
        param_name, line, expected_type, received_type
    );
    TITAN_UNREACHABLE;
}

void titan_runtime_array_type_error(
   lua_State *L,
   int line,
   int expected_tag,
   int received_tag
){
    const char *expected_type = titan_tag_name(expected_tag);
    const char *received_type = titan_tag_name(received_tag);
    luaL_error(
        L,
        "wrong type for array element at line %d, expected %s but found %s",
        line, expected_type, received_type
    );
    TITAN_UNREACHABLE;
}

void titan_runtime_function_return_error(
    lua_State *L,
    int line,
    int expected_tag,
    int received_tag
){
    const char *expected_type = titan_tag_name(expected_tag);
    const char *received_type = titan_tag_name(received_tag);
    luaL_error(
        L,
        "wrong type for function result at line %d, expected %s but found %s",
        line, expected_type, received_type
    );
    TITAN_UNREACHABLE;
}

void titan_runtime_divide_by_zero_error(
    lua_State *L,
    int line
){
    luaL_error(L, "attempt to divide by zero at line %d", line);
    TITAN_UNREACHABLE;
}

void titan_runtime_mod_by_zero_error(
    lua_State *L,
    int line
){
    luaL_error(L, "attempt to perform 'n%%0' at line %d", line);
    TITAN_UNREACHABLE;
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

TString *titan_string_concatN(lua_State *L, size_t n, TString **ss)
{
    size_t out_len = 0;
    for (size_t i = 0; i < n; i++) {
        size_t l = tsslen(ss[i]);
        if (TITAN_UNLIKELY(l >= (MAX_SIZE/sizeof(char)) - out_len)) {
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

// These definitions are from ltable.h:
#define MAXABITS        cast_int(sizeof(int) * CHAR_BIT - 1)
#define MAXASIZE        luaM_limitN(1u << MAXABITS, TValue)

// Grows the table so that it can fit index "i"
// Our strategy is to grow to the next available power of 2.
void titan_renormalize_array(lua_State *L, Table *arr, unsigned int i, int line)
{
    if (i >= MAXASIZE) {
        luaL_error(L, "invalid index for Pallene array at line %d", line);
    }

    // This loop doesn't overflow because i < MAXASIZE and
    // MAXASIZE is a power of two
    size_t new_size = 1;
    while (i >= new_size) {
        new_size *= 2;
    }

    luaH_resizearray(L, arr, new_size);
}
