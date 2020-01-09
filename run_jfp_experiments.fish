#!/usr/bin/fish

function run -a name N k
    for i in (seq 1 5)
        echo "$name i=$i k=$k"
        ./benchmarks/run benchmarks/$name $N $k
    end
end
    
for k in (seq 0 7)
    run spectralnormGrid/inject.pln 1000 $k
end

for k in (seq 0 7)
    run queenGrid/injectPln.pln 13 $k
end

for k in (seq 0 7)
    run nbodyGrid/injectPln.pln 2000000 $k
end

for k in (seq 0 3)
    run streamSieve/injectPln.pln 2000 $k
end
