# Copyright (c) 2020, The Pallene Developers
# Pallene is licensed under the MIT license.
# Please refer to the LICENSE and AUTHORS files for details
# SPDX-License-Identifier: MIT

####
# One script to rule them all, one script to find them,
# one script to bring them all and in the ease-of-use bind them.
####

# Versions
LUA_VERSION=5.4.7
LUAROCKS_VERSION=3.9.1
PT_VERSION=0.5.0a

# Where we will clone
CLONE_DIR="/tmp/pallene"
mkdir -p $CLONE_DIR

# Current working directory
CURR_DIR=$(pwd)

# Where to install/locate Lua
LUA_PREFIX=${LUA_PREFIX:-/usr/local}

# Function to display usage
usage() {
    echo "Usage: $0 { world | lua | rocks | ptracer | pallene }"
    echo "  world    - Install all components"
    echo "  lua      - Install Lua Internals"
    echo "  pallene  - Install Pallene"
    echo "  rocks    - Install LuaRocks"
    echo "  ptracer  - Install Pallene Tracer"
    echo
    echo "Lua Internals:"
    echo "  Use LUA_CFLAGS, LUA_LDFLAGS, LUA_LIBS and LUA_OBJS to pass flags:"
    echo "    LUA_MYCFLAGS=-DLUAI_ASSERT ./install.sh lua; or"
    echo "    LUA_CFLAGS=-fsanitize=address LUA_LDFLAGS=-lasan ./install.sh lua; to enable Address Sanitization"
    echo
    echo "  Use LUA_PLAT to define Lua platform. Defualt is 'linux'."
    echo "  Available platforms: guess aix bsd c89 freebsd generic ios linux linux-readline macosx mingw posix solaris"
    echo "    e.g. LUA_PLAT=linux-readline ./install.sh lua"
    echo
    echo "  Use LUA_PREFIX to provide Lua install prefix. Default is '/usr/local'."
    echo "    e.g. LUA_PREFIX=/usr/local ./install.sh lua"
    echo
    echo "Pallene Tracer:"
    echo "  Use PT_TESTS=1 to run Pallene Tracer tests after installation, e.g."
    echo "    PT_TESTS=1 ./install.sh ptracer"
    echo
    echo "  Use PT_LDFLAGS to pass LDFLAGS to Pallene Tracer Makefile, e.g."
    echo "    PT_LDFLAGS=-lasan ./install.sh ptracer; if Lua is built with Address Sanitizer"
    echo
    echo "Pallene:"
    echo "  Use PALLENE_LOCAL=1 to install Pallene locally with '--local' flag in LuaRocks:"
    echo "    PALLENE_LOCAL=1 ./install.sh pallene"
    echo
    echo "  Use PALLENE_TESTS=1 to run Pallene tests after installation:"
    echo "    PALLENE_TESTS=1 ./install.sh pallene"
}

# Install Lua Internals
install_lua_internals() {
    cd $CLONE_DIR
    wget -O - https://github.com/pallene-lang/lua-internals/archive/refs/tags/$LUA_VERSION.tar.gz | tar xzf -
    cd lua-internals-$LUA_VERSION
    make clean
    make ${LUA_PLAT:-linux} MYCFLAGS="$LUA_CFLAGS" MYLDFLAGS="$LUA_LDFLAGS" MYLIBS="$LUA_LIBS" MYOBJS="$LUA_OBJS" -j$(nproc)
    sudo make install INSTALL_TOP=$LUA_PREFIX
    cd $CURR_DIR
}

# Install Luarocks
install_luarocks() {
    cd $CLONE_DIR
    wget -O - https://luarocks.org/releases/luarocks-$LUAROCKS_VERSION.tar.gz | tar xzf -
    cd luarocks-$LUAROCKS_VERSION
    ./configure --with-lua=$LUA_PREFIX
    make -j$(nproc)
    sudo make install
    cd $CURR_DIR
}

# Install Pallene Tracer
install_ptracer() {
    cd $CLONE_DIR
    git clone --depth 1 https://github.com/pallene-lang/pallene-tracer --branch $PT_VERSION
    cd pallene-tracer
    make clean
    sudo make install LUA_PREFIX=$LUA_PREFIX LDFLAGS="$PT_LDFLAGS"

    if [ "${PT_TESTS:-0}" -eq 1 ]; then
        ./run-tests
    fi

    cd $CURR_DIR
}

# Install Pallene
install_pallene() {
    eval "$(luarocks path)"

    # Local installation
    if [ "${PALLENE_LOCAL:-0}" -eq 1 ]; then
        luarocks --local make
    else
        sudo luarocks make
    fi

    # Run tests
    if [ "${PALLENE_TESTS:-0}" -eq 1 ]; then
        ./run-tests
    fi
}

# Install everything
install_world() {
    install_lua_internals
    install_luarocks
    install_ptracer
    install_pallene
}

# Process arguments
case "$1" in
    world)
        install_world
        ;;
    lua)
        install_lua_internals
        ;;
    rocks)
        install_luarocks
        ;;
    ptracer)
        install_ptracer
        ;;
    pallene)
        install_pallene
        ;;
    --help)
        usage
        ;;
    -h)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac

