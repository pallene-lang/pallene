int luaopen_pallene__corelib(lua_State *L)
{
    lua_pushlightuserdata(L, &pallene_lib);
    return 1;
}
