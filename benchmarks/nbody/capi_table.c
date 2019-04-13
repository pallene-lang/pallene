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

static inline lua_Number _body_get(lua_State *L, int b, const char *field)
{
    lua_getfield(L, b, field);
    lua_Number x = getnumber(L, -1);
    lua_pop(L, 1);
    return x;
}

static inline void _body_set(lua_State *L, int b, const char *field,
    lua_Number v)
{
    lua_pushnumber(L, v);
    lua_setfield(L, b < 0 ? b - 1 : b, field);
}

#define body_get(field, L, b) _body_get(L, b, #field)
#define body_set(field, L, b, v) _body_set(L, b, #field, v)

static int makebody(lua_State *L)
{
    check_nargs(L, 7);

    lua_newtable(L);

    lua_pushvalue(L, 1);
    lua_setfield(L, -2, "x");

    lua_pushvalue(L, 2);
    lua_setfield(L, -2, "y");

    lua_pushvalue(L, 3);
    lua_setfield(L, -2, "z");

    lua_pushvalue(L, 4);
    lua_setfield(L, -2, "vx");

    lua_pushvalue(L, 5);
    lua_setfield(L, -2, "vy");

    lua_pushvalue(L, 6);
    lua_setfield(L, -2, "vz");

    lua_pushvalue(L, 7);
    lua_setfield(L, -2, "mass");

    return 1;
}

static int advance(lua_State *L)
{
    check_nargs(L, 2);

    lua_Number dt = getnumber(L, 2);
    lua_len(L, 1);
    int nbodies = lua_tointeger(L, -1);
    lua_pop(L, 1);

    for (int i = 1; i <= nbodies; i++) {
        lua_geti(L, 1, i);
        lua_Number bix = body_get(x, L, -1);
        lua_Number biy = body_get(y, L, -1);
        lua_Number biz = body_get(z, L, -1);
        lua_Number bivx = body_get(vx, L, -1);
        lua_Number bivy = body_get(vy, L, -1);
        lua_Number bivz = body_get(vz, L, -1);
        lua_Number bimass = body_get(mass, L, -1);
        for (int j = i + 1; j <= nbodies; j++) {
            lua_geti(L, 1, j);
            lua_Number dx = bix - body_get(x, L, -1);
            lua_Number dy = biy - body_get(y, L, -1);
            lua_Number dz = biz - body_get(z, L, -1);
            lua_Number dist2 = dx * dx + dy * dy + dz * dz;
            /* lua_Number mag = sqrt(dist2); */
            lua_Number mag = dist2;
            mag = dt / (mag * dist2);
            lua_Number bm = body_get(mass, L, -1) * mag;
            bivx = bivx - (dx * bm);
            bivy = bivy - (dy * bm);
            bivz = bivz - (dz * bm);
            bm = bimass*mag;
            body_set(vx, L, -1, body_get(vx, L, -1) + (dx * bm));
            body_set(vy, L, -1, body_get(vy, L, -1) + (dy * bm));
            body_set(vz, L, -1, body_get(vz, L, -1) + (dz * bm));
            lua_pop(L, 1);
        }
        body_set(vx, L, -1, bivx);
        body_set(vy, L, -1, bivy);
        body_set(vz, L, -1, bivz);
        body_set(x, L, -1, bix + dt * bivx);
        body_set(y, L, -1, biy + dt * bivy);
        body_set(z, L, -1, biz + dt * bivz);
        lua_pop(L, 1);
    }

    return 0;
}

static luaL_Reg capi_funcs[] = {
    { "makebody", makebody },
    { "advance", advance },
    { NULL, NULL }
};

int luaopen_benchmarks_nbody_capi_table(lua_State *L)
{
    luaL_newlib(L, capi_funcs);

    return 1;
}
