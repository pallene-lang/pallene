#include <lua.h>
#include <lauxlib.h>
#include <string.h>

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

struct body {
    lua_Number x;
    lua_Number y;
    lua_Number z;
    lua_Number vx;
    lua_Number vy;
    lua_Number vz;
    lua_Number mass;
};

static int body_index(lua_State *L)
{
    struct body *b = lua_touserdata(L, 1);
    const char *key = lua_tostring(L, 2);
    lua_Number v;

    if      (strcmp(key, "x") == 0)    v = b->x;
    else if (strcmp(key, "y") == 0)    v = b->y;
    else if (strcmp(key, "z") == 0)    v = b->z;
    else if (strcmp(key, "vx") == 0)   v = b->vx;
    else if (strcmp(key, "vy") == 0)   v = b->vy;
    else if (strcmp(key, "vz") == 0)   v = b->vz;
    else if (strcmp(key, "mass") == 0) v = b->mass;
    else
        return luaL_error(L, "impossible");

    lua_pushnumber(L, v);

    return 1;
}

static int body_newindex(lua_State *L)
{
    struct body *b = lua_touserdata(L, 1);
    const char *key = lua_tostring(L, 2);
    lua_Number v = lua_tonumber(L, 3);

    if      (strcmp(key, "x") == 0)    b->x = v;
    else if (strcmp(key, "y") == 0)    b->y = v;
    else if (strcmp(key, "z") == 0)    b->z = v;
    else if (strcmp(key, "vx") == 0)   b->vx = v;
    else if (strcmp(key, "vy") == 0)   b->vy = v;
    else if (strcmp(key, "vz") == 0)   b->vz = v;
    else if (strcmp(key, "mass") == 0) b->mass = v;
    else
        return luaL_error(L, "impossible");

    return 0;
}

static int makebody(lua_State *L)
{
    check_nargs(L, 7);

    struct body *b = lua_newuserdata(L, sizeof(struct body));
    luaL_setmetatable(L, "sim.body");

    b->x = getnumber(L, 1);
    b->y = getnumber(L, 2);
    b->z = getnumber(L, 3);
    b->vx = getnumber(L, 4);
    b->vy = getnumber(L, 5);
    b->vz = getnumber(L, 6);
    b->mass = getnumber(L, 7);

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
        struct body *bi = luaL_checkudata(L, -1, "sim.body");
        lua_Number bix = bi->x;
        lua_Number biy = bi->y;
        lua_Number biz = bi->z;
        lua_Number bivx = bi->vz;
        lua_Number bivy = bi->vy;
        lua_Number bivz = bi->vz;
        lua_Number bimass = bi->mass;
        for (int j = i + 1; j <= nbodies; j++) {
            lua_geti(L, 1, j);
            struct body *bj = luaL_checkudata(L, -1, "sim.body");
            lua_Number dx = bix - bj->x;
            lua_Number dy = biy - bj->y;
            lua_Number dz = biz - bj->z;
            lua_Number dist2 = dx * dx + dy * dy + dz * dz;
            /* lua_Number mag = sqrt(dist2); */
            lua_Number mag = dist2;
            mag = dt / (mag * dist2);
            lua_Number bm = bj->mass * mag;
            bivx = bivx - (dx * bm);
            bivy = bivy - (dy * bm);
            bivz = bivz - (dz * bm);
            bm = bimass*mag;
            bj->vx = bj->vx + (dx * bm);
            bj->vy = bj->vy + (dy * bm);
            bj->vz = bj->vz + (dz * bm);
            lua_pop(L, 1);
        }
        bi->vx = bivx;
        bi->vy = bivy;
        bi->vz = bivz;
        bi->x = bix + dt * bivx;
        bi->y = biy + dt * bivy;
        bi->z = biz + dt * bivz;
        lua_pop(L, 1);
    }

    return 0;
}

static luaL_Reg capi_funcs[] = {
    { "makebody", makebody },
    { "advance", advance },
    { NULL, NULL }
};

int luaopen_benchmarks_nbody_capi_udata(lua_State *L)
{
    luaL_newmetatable(L, "sim.body");
    lua_pushcfunction(L, body_index);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, body_newindex);
    lua_setfield(L, -2, "__newindex");
    lua_pop(L, 1);

    luaL_newlib(L, capi_funcs);
    return 1;
}
