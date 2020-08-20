local IM, IA, IC, seed, random, WIDTH, print_fasta_header, repeat_fasta, linear_search, random_fasta;
IM   = 139968
IA   = 3877
IC   = 29573

seed = 42
function random(max)
    seed = (seed * IA + IC) % IM
    return max * seed / IM;
end

WIDTH = 60

function print_fasta_header(id, desc)
    io.write(">" .. id .. " " .. desc .. "\n")
end

function repeat_fasta(id, desc, alu, n)
    print_fasta_header(id, desc)

    local alusize = #alu

    local aluwrap = alu .. alu
    while #aluwrap < alusize + WIDTH do
        aluwrap = aluwrap .. alu
    end

    local lines     = n // WIDTH
    local last_line = n % WIDTH
    local start = 0 -- (This index is 0-based bacause of the % operator)
    for _ = 1, lines do
        local stop = start + WIDTH
        io.write(string.sub(aluwrap, start+1, stop))
        io.write("\n")
        start = stop % alusize
    end
    if last_line > 0 then
        io.write(string.sub(aluwrap, start+1, start + last_line))
        io.write("\n")
    end
end

function linear_search(ps, p)
    for i = 1, #ps do
        if ps[i]>= p then
            return i
        end
    end
    return 1
end

function random_fasta(id, desc, frequencies, n)
    print_fasta_header(id, desc)

    -- Prepare the cummulative probability table
    local nitems  = #frequencies
    local letters = {}
    local probs = {}
    do
        local total = 0.0
        for i = 1, nitems do
            local o = frequencies[i]
            local c = o[1]
            local p = o[2]
            total = total + p
            letters[i] = c
            probs[i]   = total
        end
        probs[nitems] = 1.0
    end

    -- Generate the output
    local col = 0
    for _ = 1, n do
        local ix = linear_search(probs, random(1.0))
        local c = letters[ix]

        io.write(c)
        col = col + 1
        if col >= WIDTH then
            io.write("\n")
            col = 0
        end
    end
    if col > 0 then
        io.write("\n")
    end
end

return {
    repeat_fasta = repeat_fasta,
    random_fasta = random_fasta,
}
