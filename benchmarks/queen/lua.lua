-- check whether position (n,c) is free from attacks
local function isplaceok (a, n, c)
  for i = 1, n - 1 do   -- for each queen already placed
    local d = a[i]
    if (d == c) or                -- same column?
       (d - i == c - n) or        -- same diagonal?
       (d + i == c + n) then      -- same diagonal?
      return false            -- place can be attacked
    end
  end
  return true    -- no attacks; place is OK
end


-- print a board
local function printsolution (N, a)
  for i = 1, N do
    for j = 1, N do
      if a[i] == j then
        io.write("X")
      else
        io.write("-")
      end
      io.write(" ")
    end
    io.write("\n")
  end
  io.write("\n")
end


-- add to board 'a' all queens from 'n' to 'N'
local function addqueen (N, a, n)
  if n > N then    -- all queens have been placed?
    printsolution(N, a)
  else  -- try to place n-th queen
    for c = 1, N do
      if isplaceok(a, n, c) then
        a[n] = c    -- place n-th queen at column 'c'
        addqueen(N, a, n + 1)
      end
    end
  end
end

-- run the program
local function nqueens(N)
    addqueen(N, {}, 1)
end

return {
    nqueens = nqueens,
}
