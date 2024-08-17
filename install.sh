# Copyright (c) 2020, The Pallene Developers
# Pallene is licensed under the MIT license.
# Please refer to the LICENSE and AUTHORS files for details
# SPDX-License-Identifier: MIT

# Versions
LUA_VERSION=5.4.7
LUAROCKS_VERSION=3.9.1
PT_VERSION=0.5.0a

# Where we will clone
CLONE_DIR="/tmp/pallene"
mkdir -p $CLONE_DIR

# Current working directory
CURR_DIR=$(pwd)

# Whether to install Pallene locally
SUPERUSER=sudo
LOCAL_FLAG=
if [ "${PALLENE_LOCAL:-0}" -eq 1 ]; then
    SUPERUSER=
    LOCAL_FLAG=--local
fi

# Function to display usage
usage() {
    echo "Usage: $0 { world | lua | rocks | ptracer | pallene }"
    echo "  world    - Install all components"
    echo "  lua      - Install Lua Internals"
    echo "  pallene  - Install Pallene"
    echo "  rocks    - Install LuaRocks"
    echo "  ptracer  - Install Pallene Tracer"
    echo
    echo "Use MYCFLAGS environment variable to pass flags to Lua Internals:"
    echo "  MYCFLAGS=-DLUAI_ASSERT ./install.sh lua"
    echo
    echo "Use PALLENE_TRACER_TESTS=1 to run Pallene Tracer tests after installation:"
    echo "  PALLENE_TRACER_TESTS=1 ./install.sh ptracer"
    echo
    echo "Use PALLENE_LOCAL=1 to install Pallene locally with '--local' flag in LuaRocks:"
    echo "  PALLENE_LOCAL=1 ./install.sh pallene"
    echo
    echo "Use PALLENE_TESTS=1 to run Pallene tests after installation:"
    echo "  PALLENE_TESTS=1 ./install.sh pallene"
    exit $1
}

# Install Lua Internals
install_lua_internals() {
    cd $CLONE_DIR
    wget -O - https://github.com/pallene-lang/lua-internals/archive/refs/tags/$LUA_VERSION.tar.gz | tar xzf -
    cd lua-internals-$LUA_VERSION
    make linux MYCFLAGS=$MYCFLAGS -j$(nproc)
    sudo make install
    cd $CURR_DIR
}

# Install Luarocks
install_luarocks() {
    cd $CLONE_DIR
    wget -O - https://luarocks.org/releases/luarocks-$LUAROCKS_VERSION.tar.gz | tar xzf -
    cd luarocks-$LUAROCKS_VERSION
    ./configure --with-lua=/usr/local
    make -j$(nproc)
    sudo make install
    cd $CURR_DIR
}

# Install Pallene Tracer
install_ptracer() {
    cd $CLONE_DIR
    git clone --depth 1 https://github.com/pallene-lang/pallene-tracer --branch $PT_VERSION
    cd pallene-tracer
    make LUA_PREFIX=/usr/local
    sudo make install

    if [ "${PALLENE_TRACER_TESTS:-0}" -eq 1 ]; then
        ./run-tests
    fi

    cd $CURR_DIR
}

# Install Pallene
install_pallene() {
    eval "$(luarocks path)"
    $SUPERUSER luarocks $LOCAL_FLAG make

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
        usage 0
        ;;
    -h)
        usage 0
        ;;
    *)
        usage 1
        ;;
esac

