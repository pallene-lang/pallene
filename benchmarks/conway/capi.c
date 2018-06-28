#include <lua.h>
#include <lauxlib.h>

#include <stdio.h>

inline
static void check_nargs(lua_State *L, int expected)
{
    int nargs = lua_gettop(L);
    if (nargs != expected) {
        luaL_error(L, "Expected %d arguments, got %d", expected, nargs);
    }
}

inline
static lua_Integer getinteger(lua_State *L, int slot)
{
    int isnum;
    lua_Integer out = lua_tointegerx(L, slot, &isnum);
    if (!isnum) { luaL_error(L, "impossible"); }
    return out;
}

inline
static lua_Number getnumber(lua_State *L, int slot)
{
    int isnum;
    lua_Number out = lua_tonumberx(L, slot, &isnum);
    if (!isnum) { luaL_error(L, "impossible"); }
    return out;
}

static int new_canvas(lua_State *L)
{
    // 1 -> N
    // 2 -> M
    // 3 -> t
    // 4 -> line

    lua_Integer N = getinteger(L, 1);
    lua_Integer M = getinteger(L, 2);

    lua_newtable(L);

    for (lua_Integer i = 1; i <= N; i++) {
        lua_newtable(L);
        for (lua_Integer j = 1; j <= M; j++) {
            lua_pushinteger(L, 0);
            lua_seti(L, 4, j);
        }
        lua_seti(L, 3, i);
    }

    return 1;
}

static lua_Integer c_wrap(lua_Integer i, lua_Integer N)
{
    i = i - 1;
    if (i < 0) i += N;
    return (i % N) + 1;
}

static int wrap(lua_State *L)
{
    // 1 -> i
    // 2 -> N

    lua_Integer i = getinteger(L, 1);
    lua_Integer N = getinteger(L, 2);

    lua_Integer r = c_wrap(i, N);
    lua_pushinteger(L, r);

    return 1;
}

static int draw(lua_State *L)
{
    // 1 -> N
    // 2 -> M
    // 3 -> cells
    // 4 -> out
    // 5 -> cells[i]
    // 6 -> cells[i][j]

    lua_Integer N = getinteger(L, 1);
    lua_Integer M = getinteger(L, 2);

    lua_pushstring(L, "");

    for (lua_Integer i = 1; i <= N; i++) {
        lua_geti(L, 3, i);

        lua_pushvalue(L, 4);
        lua_pushstring(L, "|");
        lua_concat(L, 2);
        lua_replace(L, 4);

        for (lua_Integer j = 1; j <= M; j++) {
            lua_geti(L, 5, j);
            lua_Integer cij = getinteger(L, -1);
            lua_pop(L, 1);

            lua_pushvalue(L, 4);
            if (cij != 0) {
                lua_pushstring(L, "*");
            } else {
                lua_pushstring(L, " ");
            }
            lua_concat(L, 2);
            lua_replace(L, 4);
        }

        lua_pushvalue(L, 4);
        lua_pushstring(L, "|\n");
        lua_concat(L, 2);
        lua_replace(L, 4);

        lua_pop(L, 1);
    }


    const char *out = lua_tostring(L, 4);
    printf("%s", out);

    return 0;
}

static int spawn(lua_State *L)
{
    // 1 -> N
    // 2 -> M
    // 3 -> cells
    // 4 -> shape
    // 5 -> top
    // 6 -> left
    // 7 -> #shape, shape_row
    // 8 -> cell_row
    // 9 -> #shape_row

    lua_Integer N = getinteger(L, 1);
    lua_Integer M = getinteger(L, 2);
    lua_Integer top = getinteger(L, 5);
    lua_Integer left = getinteger(L, 6);

    lua_len(L, 4);
    lua_Integer nlines = getinteger(L, -1);
    lua_pop(L, 1);

    for (lua_Integer i = 1; i <= nlines; i++) {
        lua_Integer ci = c_wrap(i+top-1, N);

        lua_geti(L, 4, i);
        lua_geti(L, 3, ci);

        lua_len(L, 7);
        lua_Integer ncols = getinteger(L, -1);
        lua_pop(L, 1);

        for (lua_Integer j = 1; j <= ncols; j++) {
            lua_Integer cj = c_wrap(j+left-1, M);

            lua_geti(L, 7, j);
            lua_seti(L, 8, cj);
        }

        lua_pop(L, 2);
    }

    return 0;
}

static int step(lua_State *L)
{
    // 1 -> N
    // 2 -> M
    // 3 -> curr_cells
    // 4 -> next_cells

    lua_Integer N = getinteger(L, 1);
    lua_Integer M = getinteger(L, 2);

    for (lua_Integer i2 = 1; i2 <= N; i2++) {
        lua_Integer i1 = c_wrap(i2-1, N);
        lua_Integer i3 = c_wrap(i2+1, N);

        // 5 -> cells1
        // 6 -> cells2
        // 7 -> cells3
        // 8 -> next2

        lua_geti(L, 3, i1);
        lua_geti(L, 3, i2);
        lua_geti(L, 3, i3);

        lua_geti(L, 4, i2);

        for (lua_Integer j2 = 1; j2 <= M; j2++) {
            lua_Integer j1 = c_wrap(j2-1, M);
            lua_Integer j3 = c_wrap(j2+1, M);

            lua_geti(L, 5, j1);
            lua_Integer c11 = getinteger(L, -1);

            lua_geti(L, 5, j2);
            lua_Integer c12 = getinteger(L, -1);

            lua_geti(L, 5, j3);
            lua_Integer c13 = getinteger(L, -1);

            lua_geti(L, 6, j1);
            lua_Integer c21 = getinteger(L, -1);

            lua_geti(L, 6, j2);
            lua_Integer c22 = getinteger(L, -1);

            lua_geti(L, 6, j3);
            lua_Integer c23 = getinteger(L, -1);

            lua_geti(L, 7, j1);
            lua_Integer c31 = getinteger(L, -1);

            lua_geti(L, 7, j2);
            lua_Integer c32 = getinteger(L, -1);

            lua_geti(L, 7, j3);
            lua_Integer c33 = getinteger(L, -1);

            lua_pop(L, 9);

            lua_Integer sum =
                c11 + c12 + c13 +
                c21 +       c23 +
                c31 + c32 + c33;

            if (sum == 3 || (sum == 2 &&  c22 == 1)) {
                lua_pushinteger(L, 1);
            } else {
                lua_pushinteger(L, 0);
            }
            lua_seti(L, 8, j2);
        }

        lua_pop(L, 4);
    }

    return 0;
}


static luaL_Reg capi_funcs[] = {
    { "new_canvas", new_canvas },
    { "wrap", wrap },
    { "draw", draw },
    { "spawn", spawn },
    { "step", step },
    { NULL, NULL },
};

int luaopen_benchmarks_conway_capi(lua_State *L)
{
    luaL_newlib(L, capi_funcs);
    return 1;
}
