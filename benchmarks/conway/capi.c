#include <lua.h>
#include <lauxlib.h>

#include <stdio.h>

static int new_canvas(lua_State *L)
{
    // 1 -> N
    // 2 -> M
    // 3 -> t
    // 4 -> line

    lua_Integer N;
    {
        int isnum;
        N = lua_tointegerx(L, 1, &isnum);
        if (!isnum) { luaL_error(L, "N is not integer"); }
    }

    lua_Integer M;
    {
        int isnum;
        M = lua_tointegerx(L, 2, &isnum);
        if (!isnum) { luaL_error(L, "M is not integer"); }
    }

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
    
    lua_Integer i;
    {
        int isnum;
        i = lua_tointegerx(L, 1, &isnum);
        if (!isnum) { luaL_error(L, "i is not integer"); }
    }

    lua_Integer N;
    {
        int isnum;
        N = lua_tointegerx(L, 2, &isnum);
        if (!isnum) { luaL_error(L, "N is not integer"); }
    }

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

    lua_Integer N;
    {
        int isnum;
        N = lua_tointegerx(L, 1, &isnum);
        if (!isnum) { luaL_error(L, "N is not integer"); }
    }

    lua_Integer M;
    {
        int isnum;
        M = lua_tointegerx(L, 2, &isnum);
        if (!isnum) { luaL_error(L, "M is not integer"); }
    }

    lua_pushstring(L, "");

    for (lua_Integer i = 1; i <= N; i++) {
        lua_geti(L, 3, i);

        lua_pushvalue(L, 4);
        lua_pushstring(L, "|");
        lua_concat(L, 2);
        lua_replace(L, 4);

        for (lua_Integer j = 1; j <= M; j++) {
            lua_geti(L, 5, j);
            lua_Integer cij;
            {
                int isnum;
                cij = lua_tointegerx(L, -1, &isnum);
                if (!isnum) { luaL_error(L, "impossible"); }
            }
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
    
    lua_Integer N;
    {
        int isnum;
        N = lua_tointegerx(L, 1, &isnum);
        if (!isnum) { luaL_error(L, "N is not integer"); }
    }

   lua_Integer M;
    {
        int isnum;
        M = lua_tointegerx(L, 2, &isnum);
        if (!isnum) { luaL_error(L, "M is not integer"); }
    }

    lua_Integer top;
    {
        int isnum;
        top = lua_tointegerx(L, 5, &isnum);
        if (!isnum) { luaL_error(L, "top is not integer"); }
    }

    lua_Integer left;
    {
        int isnum;
        left = lua_tointegerx(L, 6, &isnum);
        if (!isnum) { luaL_error(L, "left is not integer"); }
    }

    lua_len(L, 4);
    lua_Integer nlines;
    {
        int isnum;
        nlines = lua_tointegerx(L, -1, &isnum);
        if (!isnum) { luaL_error(L, "nlines is not integer"); }
    }
    lua_pop(L, 1);


    for (lua_Integer i = 1; i <= nlines; i++) {
        lua_Integer ci = c_wrap(i+top-1, N);
        
        lua_geti(L, 4, i);
        lua_geti(L, 3, ci);

        lua_len(L, 7);
        lua_Integer ncols;
        {
            int isnum;
            ncols = lua_tointegerx(L, -1, &isnum);
            if (!isnum) { luaL_error(L, "ncols is not integer"); }
        }
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
    
    lua_Integer N;
    {
        int isnum;
        N = lua_tointegerx(L, 1, &isnum);
        if (!isnum) { luaL_error(L, "N is not integer"); }
    }

    lua_Integer M;
    {
        int isnum;
        M = lua_tointegerx(L, 2, &isnum);
        if (!isnum) { luaL_error(L, "M is not integer"); }
    }

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
            lua_Integer c11;
            {
                int isnum;
                c11 = lua_tointegerx(L, -1, &isnum);
                if (!isnum) { luaL_error(L, "impossible"); }
            }
            lua_pop(L, 1);

            lua_geti(L, 5, j2);
            lua_Integer c12;
            {
                int isnum;
                c12 = lua_tointegerx(L, -1, &isnum);
                if (!isnum) { luaL_error(L, "impossible"); }
            }
            lua_pop(L, 1);

            lua_geti(L, 5, j3);
            lua_Integer c13;
            {
                int isnum;
                c13 = lua_tointegerx(L, -1, &isnum);
                if (!isnum) { luaL_error(L, "impossible"); }
            }
            lua_pop(L, 1);

            lua_geti(L, 6, j1);
            lua_Integer c21;
            {
                int isnum;
                c21 = lua_tointegerx(L, -1, &isnum);
                if (!isnum) { luaL_error(L, "impossible"); }
            }
            lua_pop(L, 1);

            lua_geti(L, 6, j2);
            lua_Integer c22;
            {
                int isnum;
                c22 = lua_tointegerx(L, -1, &isnum);
                if (!isnum) { luaL_error(L, "impossible"); }
            }
            lua_pop(L, 1);

            lua_geti(L, 6, j3);
            lua_Integer c23;
            {
                int isnum;
                c23 = lua_tointegerx(L, -1, &isnum);
                if (!isnum) { luaL_error(L, "impossible"); }
            }
            lua_pop(L, 1);

            lua_geti(L, 7, j1);
            lua_Integer c31;
            {
                int isnum;
                c31 = lua_tointegerx(L, -1, &isnum);
                if (!isnum) { luaL_error(L, "impossible"); }
            }
            lua_pop(L, 1);

            lua_geti(L, 7, j2);
            lua_Integer c32;
            {
                int isnum;
                c32 = lua_tointegerx(L, -1, &isnum);
                if (!isnum) { luaL_error(L, "impossible"); }
            }
            lua_pop(L, 1);

            lua_geti(L, 7, j3);
            lua_Integer c33;
            {
                int isnum;
                c33 = lua_tointegerx(L, -1, &isnum);
                if (!isnum) { luaL_error(L, "impossible"); }
            }
            lua_pop(L, 1);


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
