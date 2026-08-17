# Vendored Dependencies

## `lua-internals`

- **Source:** [pallene-lang/lua-internals](https://github.com/pallene-lang/lua-internals.git/)
- **Branch:** `main`
- **Commit:** `4197fc71a7967436d117e3eb17c2aa04a5a5fd57`

## `pallene-tracer`

- **Source code:** [pallene-lang/pallene-tracer](https://www.github.com/pallene-lang/pallene-tracer.git/)
- **Tag:** `0.6.0`
- **Commit ID:** `90e08dc71736386f53cd1ba1ea12331a55d8479d`

## `argparse`

- **Source code:** [luarocks/argparse](https://github.com/luarocks/argparse)
- **Version:** `0.7.1`
- **Tag:** `0.7.1`
- **Commit ID:** `27967d7b52295ea7885671af734332038c132837`

## `lpeg`

- **Source code:** [lpeg-1.1.0.tar.gz](https://www.inf.puc-rio.br/~roberto/lpeg/lpeg-1.1.0.tar.gz)
- **Version:** `1.1.0`

# Updating Vendored Dependencies

This section will teach you how to update the vendored dependencies.

## Guidelines for PRs

When a PR updates a vendored dependency in `deps/`, its first commit
must contain nothing but the unmodified upstream sources, with the
upstream version and commit hash recorded in the commit message. Files
we deliberately exclude (e.g. upstream tests, docs, CI config)
may be deleted in this commit; nothing else may be changed.

Everything else goes in later commits: reapplying our patch series,
build system integration, modifying Pallene to account for the new dependency,
and updating `VENDORING.md`.

`VENDORING.md` is the source of truth for what we vendor. It lists every
dependency under `deps/` with:

- Name
- Upstream source URL
- Version (release tag or the version string)
- Commit hash, and the branch it was taken from, if vendored from a Git checkout

Update `VENDORING.md` in the same PR whenever anything under `deps/`
changes—adding a dependency, removing one, or upgrading one.

The tests must pass and the linter must not complain for the latest
commit in the PR. It is OK if intermediate commits do not pass.

## Updating Lua

Pallene requires a Lua build with certain internal APIs exposed. We do this by
having patch files that modify stock Lua.

Here's how to update Lua:

```sh
#
# Note that all these steps are to be done manually. This is not a shell
# script.
#
# Replace $VERSION with whatever version you're upgrading to.
#

cd deps/lua

# First, we have to update the stock Lua.
wget -O - "https://www.lua.org/ftp/lua-$VERSION.tar.gz" | tar -xz
# We do this so as to remove files that existed in the old version
# but were deleted in the newer versions.
rm -rf upstream/*
cp -r lua-$VERSION/* upstream/
rm -rf lua-$VERSION/

# We make a copy of the stock Lua directory to make our changes in.
cp -r upstream/ upstream-patched/

# We can now make the necessary changes to expose the internal APIs...
cd upstream-patched/ && $EDITOR .

# Now that we've made the changes, we can create a patch file for our changes.
cd ..
diff -ruN upstream/ upstream-patched/ > patches/expose-internal-apis.patch

# Delete the directory deps/lua/upstream-patched since we don't need it anymore.
rm -rf upstream-patched/

# NOTE: If you have changed the name of the patch file, you'll have to change the name
# in the root Makefile as well.
```

