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

const char *pallene_tag_name(int raw_tag)
{
    if (raw_tag == LUA_TNUMINT) {
        return "integer";
    } else if (raw_tag == LUA_TNUMFLT) {
        return "float";
    } else {
        return ttypename(novariant(raw_tag));
    }
}

void pallene_runtime_tag_check_error(
    lua_State *L,
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
        lua_pushfstring(L, "line %d: ", line);
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
    int line
){
    luaL_error(L, "attempt to divide by zero at line %d", line);
    PALLENE_UNREACHABLE;
}

void pallene_runtime_mod_by_zero_error(
    lua_State *L,
    int line
){
    luaL_error(L, "attempt to perform 'n%%0' at line %d", line);
    PALLENE_UNREACHABLE;
}

int pallene_runtime_record_nonstr_error(
    lua_State *L,
    int received_tag
){
    const char *type = pallene_tag_name(received_tag);
    luaL_error(L, "attempt to access non-string field of type '%s'", type);
    PALLENE_UNREACHABLE;
}

int pallene_runtime_record_index_error(
    lua_State *L,
    const char *key
){
    luaL_error(L, "attempt to access nonexistent field '%s'", key);
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
void pallene_grow_array(lua_State *L, Table *arr, unsigned int ui, int line)
{
    if (ui >= MAXASIZE) {
        luaL_error(L, "invalid index for Pallene array at line %d", line);
    }

    /* This loop doesn't overflow because i < MAXASIZE and
     * MAXASIZE is a power of two */
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

TString* pallene_string_char(lua_State *L, lua_Integer c, int line)
{
    if (l_castS2U(c) > UCHAR_MAX) {
        luaL_error(L, "char value out of range", line);
    }

    char buff[2];
    buff[0] = c;
    buff[1] = '\0';
    return luaS_newlstr(L, buff, 1);
}

/* l_strcmp, copied from lvm.c
 *
 * Compare two strings 'ls' x 'rs', returning an integer less-equal-
 * -greater than zero if 'ls' is less-equal-greater than 'rs'.
 * The code is a little tricky because it allows '\0' in the strings
 * and it uses 'strcoll' (to respect locales) for each segments
 * of the strings. */
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
