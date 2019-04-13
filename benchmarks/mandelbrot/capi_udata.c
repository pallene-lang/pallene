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

struct point {
    lua_Number re;
    lua_Number im;
};

static inline void point_new(lua_State *L, lua_Number x, lua_Number y)
{
    struct point *p = lua_newuserdata(L, sizeof(struct point));

    p->re = x;
    p->im = y;

    luaL_setmetatable(L, "point");
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

    struct point *p = luaL_checkudata(L, 1, "point");

    point_new(L, p->re, p->im);

    return 1;
}

static int conj(lua_State *L)
{
    check_nargs(L, 1);

    struct point *p = luaL_checkudata(L, 1, "point");

    point_new(L, p->re, -p->im);

    return 1;
}

static int add(lua_State *L)
{
    check_nargs(L, 2);

    struct point *x = luaL_checkudata(L, 1, "point");
    struct point *y = luaL_checkudata(L, 2, "point");

    point_new(L, x->re + y->re, x->im + y->im);

    return 1;
}

static int mul(lua_State *L)
{
    check_nargs(L, 2);

    struct point *x = luaL_checkudata(L, 1, "point");
    struct point *y = luaL_checkudata(L, 2, "point");

    point_new(L, x->re * y->re - x->im * y->im, x->re * y->im + x->im * y->re);

    return 1;
}

static int norm2(lua_State *L)
{
    check_nargs(L, 1);

    struct point *x = luaL_checkudata(L, 1, "point");

    lua_pushnumber(L, x->re * x->re + x->im * x->im);

    return 1;
}

static int abs(lua_State *L)
{
    check_nargs(L, 1);

    struct point *x = luaL_checkudata(L, 1, "point");

    lua_pushnumber(L, x->re * x->re + x->im * x->im);
    /* lua_pushnumber(L, sqrt(x->re * x->re + x->im * x->im)); */

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

int luaopen_benchmarks_mandelbrot_capi_udata(lua_State *L)
{
    luaL_newmetatable(L, "point");
    lua_pop(L, 1);
    luaL_newlib(L, capi_funcs);
    return 1;
}
