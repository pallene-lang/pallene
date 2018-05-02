#include "tcore.h"

#include "lua.h"
#include "lauxlib.h"

#include "lobject.h"
#include "lstate.h"
#include "ltm.h"

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
