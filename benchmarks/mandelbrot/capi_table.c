#include <lua.h>
#include <lauxlib.h>

inline
static void check_nargs(lua_State *L, int expected)
{
    int nargs = lua_gettop(L);
    if (nargs != expected) {
        luaL_error(L, "Expected %d arguments, got %d", expected, nargs);
    }
}

inline
static lua_Number getnumber(lua_State *L, int slot)
{
    int isnum;
    lua_Number out = lua_tonumberx(L, slot, &isnum);
    if (!isnum) { luaL_error(L, "impossible"); }
    return out;
}

static inline void point_new(lua_State *L, lua_Number x, lua_Number y)
{
    lua_newtable(L);

    lua_pushnumber(L, x);
    lua_setfield(L, -2, "re");

    lua_pushnumber(L, y);
    lua_setfield(L, -2, "im");
}

static inline lua_Number point_re(lua_State *L, int i)
{
    lua_getfield(L, i, "re");
    lua_Number x = getnumber(L, -1);
    lua_pop(L, 1);
    return x;
}

static inline lua_Number point_im(lua_State *L, int i)
{
    lua_getfield(L, i, "im");
    lua_Number x = getnumber(L, -1);
    lua_pop(L, 1);
    return x;
}

static int new(lua_State *L)
{
    check_nargs(L, 2);

    point_new(L, getnumber(L, 1), getnumber(L, 2));

    return 1;
}

static int clone(lua_State *L)
{
    check_nargs(L, 1);

    point_new(L, point_re(L, 1), point_im(L, 1));

    return 1;
}

static int conj(lua_State *L)
{
    check_nargs(L, 1);

    point_new(L, point_re(L, 1), -point_im(L, 1));

    return 1;
}

static int add(lua_State *L)
{
    check_nargs(L, 2);

    lua_Number x_re = point_re(L, 1);
    lua_Number x_im = point_im(L, 1);
    lua_Number y_re = point_re(L, 2);
    lua_Number y_im = point_im(L, 2);

    point_new(L, x_re + y_re, x_im + y_im);

    return 1;
}

static int mul(lua_State *L)
{
    check_nargs(L, 2);

    lua_Number x_re = point_re(L, 1);
    lua_Number x_im = point_im(L, 1);
    lua_Number y_re = point_re(L, 2);
    lua_Number y_im = point_im(L, 2);

    point_new(L, x_re * y_re - x_im * y_im, x_re * y_im + x_im * y_re);

    return 1;
}

static int norm2(lua_State *L)
{
    check_nargs(L, 1);

    lua_Number x_re = point_re(L, 1);
    lua_Number x_im = point_im(L, 1);

    lua_pushnumber(L, x_re * x_re + x_im * x_im);

    return 1;
}

static int abs(lua_State *L)
{
    check_nargs(L, 1);

    lua_Number x_re = point_re(L, 1);
    lua_Number x_im = point_im(L, 1);

    lua_pushnumber(L, x_re * x_re + x_im * x_im);
    /* lua_pushnumber(L, sqrt(x_re * x_re + x_im * x_im)); */

    return 1;
}

static luaL_Reg capi_funcs[] = {
    { "new", new },
    { "clone", clone },
    { "conj", conj },
    { "add", add },
    { "mul", mul },
    { "norm2", norm2 },
    { "abs", abs },
    { NULL, NULL}
};

int luaopen_benchmarks_mandelbrot_capi_table(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
