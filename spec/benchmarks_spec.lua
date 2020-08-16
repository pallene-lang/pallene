--
-- In this test file we run all our benchmarks with a small N, to ensure that they aren't broken by
-- updates to the compiler.
--

local benchlib = require "benchmarks.benchlib"
local util= require "pallene.util"

local impls
if util.outputs_of_execute("luajit -v") then
    impls = {"lua", "capi", "pallene", "luajit", "ffi"}
else
    impls = {"lua", "capi", "pallene"}
    print("Warning: not testing the LuaJIT benchmarks, because LuaJIT is not installed.")
end

local function assert_benchmark(bench, params, expected_output)
    for _, impl in ipairs(impls) do
        if benchlib.find_benchmark(bench, impl) then
            it(impl, function()
                local out = benchlib.run_with_impl_name("none", bench, impl, params)
                assert.are.same(expected_output, out)
            end)
        end
    end
end


describe("Binarytrees /", function()
    assert_benchmark("binarytrees", {5, 1}, [[
stretch tree of depth 7	 check: 255
64	 trees of depth 4	 check: 1984
16	 trees of depth 6	 check: 2032
long lived tree of depth 6	 check: 127
]])
end)

describe("Binsearch /", function()
    assert_benchmark("binsearch", {100, 10}, [[
10
]])
end)

describe("Centroid /", function()
    assert_benchmark("centroid", {10, 1}, [[
17.27825	17.27825
]])
end)

describe("Conway /", function()
    assert_benchmark("conway", {1, 1}, [[
|          * *  * *         *       * *  * *         *       * *  * *         *  |
|  *    *   **   **    *  * *    *   **   **    *  * *    *   **   **    *  * *  |
|* *  * *            * *   **  * *            * *   **  * *            * *   **  |
| **   **             **        **             **        **             **       |
|            *    *                   *    *                   *    *            |
|          * *  * *         *       * *  * *         *       * *  * *         *  |
|  *    *   **   **    *  * *    *   **   **    *  * *    *   **   **    *  * *  |
|* *  * *            * *   **  * *            * *   **  * *            * *   **  |
| **   **             **        **             **        **             **       |
|            *    *                   *    *                   *    *            |
|          * *  * *         *       * *  * *         *       * *  * *         *  |
|  *    *   **   **    *  * *    *   **   **    *  * *    *   **   **    *  * *  |
|* *  * *            * *   **  * *            * *   **  * *            * *   **  |
| **   **             **        **             **        **             **       |
|            *    *                   *    *                   *    *            |
|          * *  * *         *       * *  * *         *       * *  * *         *  |
|  *    *   **   **    *  * *    *   **   **    *  * *    *   **   **    *  * *  |
|* *  * *            * *   **  * *            * *   **  * *            * *   **  |
| **   **             **        **             **        **             **       |
|            *    *                   *    *                   *    *            |
|          * *  * *         *       * *  * *         *       * *  * *         *  |
|  *    *   **   **    *  * *    *   **   **    *  * *    *   **   **    *  * *  |
|* *  * *            * *   **  * *            * *   **  * *            * *   **  |
| **   **             **        **             **        **             **       |
|            *    *                   *    *                   *    *            |
|          * *  * *         *       * *  * *         *       * *  * *         *  |
|  *    *   **   **    *  * *    *   **   **    *  * *    *   **   **    *  * *  |
|* *  * *            * *   **  * *            * *   **  * *            * *   **  |
| **   **             **        **             **        **             **       |
|            *    *                   *    *                   *    *            |
|          * *  * *         *       * *  * *         *       * *  * *         *  |
|  *    *   **   **    *  * *    *   **   **    *  * *    *   **   **    *  * *  |
|* *  * *            * *   **  * *            * *   **  * *            * *   **  |
| **   **             **        **             **        **             **       |
|            *    *                   *    *                   *    *            |
|          * *  * *         *       * *  * *         *       * *  * *         *  |
|  *    *   **   **    *  * *    *   **   **    *  * *    *   **   **    *  * *  |
|* *  * *            * *   **  * *            * *   **  * *            * *   **  |
| **   **             **        **             **        **             **       |
|            *    *                   *    *                   *    *            |

|            **   **       *          **   **       *          **   **       *   |
| *    *    **   **   *     **  *    **   **   *     **  *    **   **   *     ** |
|  **   **             **  **    **             **  **    **             **  **  |
| **   **             **        **             **        **             **       |
|           *    *                   *    *                   *    *             |
|            **   **       *          **   **       *          **   **       *   |
| *    *    **   **   *     **  *    **   **   *     **  *    **   **   *     ** |
|  **   **             **  **    **             **  **    **             **  **  |
| **   **             **        **             **        **             **       |
|           *    *                   *    *                   *    *             |
|            **   **       *          **   **       *          **   **       *   |
| *    *    **   **   *     **  *    **   **   *     **  *    **   **   *     ** |
|  **   **             **  **    **             **  **    **             **  **  |
| **   **             **        **             **        **             **       |
|           *    *                   *    *                   *    *             |
|            **   **       *          **   **       *          **   **       *   |
| *    *    **   **   *     **  *    **   **   *     **  *    **   **   *     ** |
|  **   **             **  **    **             **  **    **             **  **  |
| **   **             **        **             **        **             **       |
|           *    *                   *    *                   *    *             |
|            **   **       *          **   **       *          **   **       *   |
| *    *    **   **   *     **  *    **   **   *     **  *    **   **   *     ** |
|  **   **             **  **    **             **  **    **             **  **  |
| **   **             **        **             **        **             **       |
|           *    *                   *    *                   *    *             |
|            **   **       *          **   **       *          **   **       *   |
| *    *    **   **   *     **  *    **   **   *     **  *    **   **   *     ** |
|  **   **             **  **    **             **  **    **             **  **  |
| **   **             **        **             **        **             **       |
|           *    *                   *    *                   *    *             |
|            **   **       *          **   **       *          **   **       *   |
| *    *    **   **   *     **  *    **   **   *     **  *    **   **   *     ** |
|  **   **             **  **    **             **  **    **             **  **  |
| **   **             **        **             **        **             **       |
|           *    *                   *    *                   *    *             |
|            **   **       *          **   **       *          **   **       *   |
| *    *    **   **   *     **  *    **   **   *     **  *    **   **   *     ** |
|  **   **             **  **    **             **  **    **             **  **  |
| **   **             **        **             **        **             **       |
|           *    *                   *    *                   *    *             |
]])
end)

describe("Fannkuch /", function()
    assert_benchmark("fannkuchredux", {5, 1}, [[
11
Pfannkuchen(5) = 7
]])
end)

describe("Fasta /", function()
    assert_benchmark("fasta", {20, 1}, [[
>ONE Homo sapiens alu
GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTT
>TWO IUB ambiguity codes
cttBtatcatatgctaKggNcataaaSatgtaaaDcDRtBggDtctttataattcBgtcg
>THREE Homo sapiens frequency
tacgtgtagcctagtgtttgtgttgcgttatagtctatttgtggacacagtatggtcaaa
tgacgtcttttgatctgacggcgttaacaaagatactctg
]])
end)

describe("mandelbrot /", function()
    assert_benchmark("mandelbrot", {8, 1}, "P4\n8 8\n\x02\x00\x0f\x2f\xff\x2f\x0f\x00")
end)

describe("Matmul /", function()
    assert_benchmark("matmul", {17, 1}, [[
#C	17	17
C[1][1]	20803.898903
]])
end)

describe("Nbody /", function()
    assert_benchmark("nbody", {50, 1}, [[
-0.169075164
-0.169063618
]])
end)

describe("Objmandelbrot /", function()
    assert_benchmark("objmandelbrot", {2, 1}, [[
P2
2	2	255
0
255
0
255
]])
end)

describe("Queen /", function()
    -- We use regular quotes strings here because Vim likes to eat the trailing whitespace.
    assert_benchmark("queen", {4, 1},
"- X - - \n"..
"- - - X \n"..
"X - - - \n"..
"- - X - \n"..
"\n"..
"- - X - \n"..
"X - - - \n"..
"- - - X \n"..
"- X - - \n"..
"\n")
end)

describe("Sieve /", function()
    assert_benchmark("sieve", {50, 1}, [[
15
]])
end)

describe("Spectral Norm /", function()
    assert_benchmark("spectralnorm", {20, 1}, [[
1.273839841
]])
end)
