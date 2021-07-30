-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local trycatch = require "pallene.trycatch"

local function boom(n, cb)
    if n == 1 then
        cb()
    else
        boom(n-1, cb)
    end
end

describe("Try/Catch", function()

    it("works on code without exceptionss", function()
        local ok, ret = trycatch.pcall(function() return 20 end)
        assert.is_true(ok)
        assert.equal(20, ret)
    end)

    it("can try-catch tagged exceptions", function()
        local ok, ret = trycatch.pcall(function()
            boom(2, function()
                trycatch.error("xyz", "hello")
            end)
        end)
        assert.is_false(ok)
        assert.equal("xyz", ret.tag)
        assert.equal("hello", ret.msg)
    end)

    it("can try-catch untagged exceptions", function()
        local ok, ret = trycatch.pcall(function()
            boom(2, function()
                error("world")
            end)
        end)
        assert.is_false(ok)
        assert.equal(false, ret.tag)
        assert.matches("world", ret.msg)
    end)

    describe("the trace ends at the right level", function()

        it("with tagged exceptions (implicit level)", function()
            local ok, ret = trycatch.pcall(function()
                boom(2, function()
                    trycatch.error("xyz", "hello")
                end)
            end)
            assert.is_false(ok)
            local stack = tostring(ret)
            assert.match("trycatch_spec.lua:%d+: in local 'cb'", stack)
        end)

        it("with tagged exceptions (explicit level)", function()
            local ok, ret = trycatch.pcall(function()
                local function ZZZ()
                    trycatch.error("xyz", "hello",2)
                end
                boom(2, function()
                    ZZZ()
                end)
            end)
            assert.is_false(ok)
            local stack = tostring(ret)
            assert.Not.match("ZZZ", stack)
            assert.match("trycatch_spec.lua:%d+: in local 'cb'", stack)
        end)

        it("with Lua crashes", function()
            local ok, ret = trycatch.pcall(function()
                boom(2, function()
                    return "a" .. nil
                end)
            end)
            assert.is_false(ok)
            local stack = tostring(ret)
            assert.match("attempt to concatenate a nil value", stack)
            assert.match("trycatch_spec.lua:%d+: in local 'cb'", stack)
        end)

        it("when calling 'error()'", function()
            local ok, ret = trycatch.pcall(function()
                boom(2, function()
                    error("boom")
                end)
            end)
            assert.is_false(ok)
            local stack = tostring(ret)
            assert.match("in function 'error'", stack)
            assert.match("trycatch_spec.lua:%d+: in local 'cb'", stack)
        end)
    end)

end)
