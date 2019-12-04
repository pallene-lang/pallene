-- Fasta benchmark from benchmarks game
-- https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/fasta.html
--
-- Translated from the Java and Python versions found at
-- https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/fasta-java-2.html
-- https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/fasta-python3-1.html
--
-- This differs from the Lua versions of the benchmark in some aspects
--  * Don't use load/eval metaprogramming
--  * Repeat fasta now works correctly when #alu < 60
--  * Use linear search (actually faster than binary search in the tests)
--  * Use // integer division

local fasta = require(arg[1])
local N   = tonumber(arg[2]) or 100
--local REP = tonumber(arg[3]) or 1

local HUMAN_ALU =
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG" ..
    "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA" ..
    "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT" ..
    "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA" ..
    "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG" ..
    "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC" ..
    "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

local IUB = {
    { 'a', 0.27 },
    { 'c', 0.12 },
    { 'g', 0.12 },
    { 't', 0.27 },
    { 'B', 0.02 },
    { 'D', 0.02 },
    { 'H', 0.02 },
    { 'K', 0.02 },
    { 'M', 0.02 },
    { 'N', 0.02 },
    { 'R', 0.02 },
    { 'S', 0.02 },
    { 'V', 0.02 },
    { 'W', 0.02 },
    { 'Y', 0.02 },
}

local HOMO_SAPIENS = {
    { 'a', 0.3029549426680 },
    { 'c', 0.1979883004921 },
    { 'g', 0.1975473066391 },
    { 't', 0.3015094502008 },
}

fasta.repeat_fasta("ONE", "Homo sapiens alu", HUMAN_ALU, N*2)
fasta.random_fasta('TWO', 'IUB ambiguity codes', IUB, N*3)
fasta.random_fasta('THREE', 'Homo sapiens frequency', HOMO_SAPIENS, N*5)
