/* Copyright (c) 2020, The Pallene Developers
 * Pallene is licensed under the MIT license.
 * Please refer to the LICENSE and AUTHORS files for details
 * SPDX-License-Identifier: MIT */

#include "pallene_core.h"

#include "lua.h"
#include "lauxlib.h"

#include "lmem.h"
#include "lobject.h"
#include "lstate.h"
#include "lstring.h"
#include "ltm.h"
#include "ltable.h"

#include <string.h>
#include <stdarg.h>
#include <locale.h>

const char *pallene_tag_name(int raw_tag)
{
    if (raw_tag == LUA_VNUMINT) {
        return "integer";
    } else if (raw_tag == LUA_VNUMFLT) {
        return "float";
    } else {
        return ttypename(novariant(raw_tag));
    }
}

void pallene_runtime_tag_check_error(
    lua_State *L,
    const char* file,
    int line,
    int expected_tag,
    int received_tag,
    const char *description_fmt,
    ...
){
    const char *expected_type = pallene_tag_name(expected_tag);
    const char *received_type = pallene_tag_name(received_tag);

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
        expected_type, received_type);
    lua_concat(L, 5);
    lua_error(L);
    PALLENE_UNREACHABLE;
}

void pallene_runtime_arity_error(
    lua_State *L,
    const char *name,
    int expected,
    int received
){
    luaL_error(
        L,
        "wrong number of arguments to function '%s',"
        " expected %d but received %d",
        name, expected, received
    );
    PALLENE_UNREACHABLE;
}

void pallene_runtime_divide_by_zero_error(
    lua_State *L,
    const char* file,
    int line
){
    luaL_error(L, "file %s: line %d: attempt to divide by zero", file, line);
    PALLENE_UNREACHABLE;
}

void pallene_runtime_mod_by_zero_error(
    lua_State *L,
    const char* file,
    int line
){
    luaL_error(L, "file %s: line %d: attempt to perform 'n%%0'", file, line);
    PALLENE_UNREACHABLE;
}

void pallene_runtime_array_metatable_error(
    lua_State *L, const char* file, int line
){
    luaL_error(L, "file %s: line %d: arrays in Pallene must not have a metatable", file, line);
    PALLENE_UNREACHABLE;
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

TString *pallene_string_concatN(lua_State *L, size_t n, TString **ss)
{
    size_t out_len = 0;
    for (size_t i = 0; i < n; i++) {
        size_t l = tsslen(ss[i]);
        if (PALLENE_UNLIKELY(l >= (MAX_SIZE/sizeof(char)) - out_len)) {
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

/* Grows the table so that it can fit index "i"
 * Our strategy is to grow to the next available power of 2. */
void pallene_grow_array(lua_State *L, const char* file, int line, Table *arr, unsigned int ui)
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

void pallene_io_write(lua_State *L, TString *str)
{
    const char *s = getstr(str);
    size_t len = tsslen(str);
    fwrite(s, 1, len, stdout);
}

TString* pallene_string_char(lua_State *L, const char* file, int line, lua_Integer c)
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
static
size_t get_start_pos(lua_Integer pos, size_t len)
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
static
size_t get_end_pos(lua_Integer pos, size_t len)
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

TString* pallene_string_sub(
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

/* l_strcmp, copied from lvm.c
 *
 * Compare two strings 'ls' x 'rs', returning an integer less-equal-greater than zero if 'ls' is
 * less-equal-greater than 'rs'. The code is a little tricky because it allows '\0' in the strings
 * and it uses 'strcoll' (to respect locales) for each segments of the strings. */
int pallene_l_strcmp (const TString *ls, const TString *rs) {
  const char *l = getstr(ls);
  size_t ll = tsslen(ls);
  const char *r = getstr(rs);
  size_t lr = tsslen(rs);
  for (;;) {  /* for each segment */
    int temp = strcoll(l, r);
    if (temp != 0)  /* not equal? */
      return temp;  /* done */
    else {  /* strings are equal up to a '\0' */
      size_t len = strlen(l);  /* index of first '\0' in both strings */
      if (len == lr)  /* 'rs' is finished? */
        return (len == ll) ? 0 : 1;  /* check 'ls' */
      else if (len == ll)  /* 'ls' is finished? */
        return -1;  /* 'ls' is less than 'rs' ('rs' is not finished) */
      /* both strings longer than 'len'; go on comparing after the '\0' */
      len++;
      l += len; ll -= len; r += len; lr -= len;
    }
  }
}

TString *pallene_type_builtin(lua_State *L, TValue v) {
    return luaS_new(L, lua_typename(L, ttype(&v)));
}

/* This is defined at lobject.c before tostringbuff function definition, where it is used */
#define MAXNUMBER2STR	50

/* Based on function luaL_tolstring */
TString *pallene_tostring(lua_State *L, const char* file, int line, TValue v) {
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
