
#
# You must run this from the root project folder:
#   make -f experiments/makefile
#

CSVS:=experiments/matmul.csv experiments/binsearch.csv experiments/sieve.csv experiments/queen.csv \
      experiments/conway.csv experiments/centroid.csv\
      experiments/matmulperf.csv

N:=42

.PHONY: all clean

all: $(CSVS)

#

experiments/matmul.csv:
	./experiments/collect_times.lua matmul     $N 800 2 | tee $@

experiments/binsearch.csv:
	./experiments/collect_times.lua binsearch  $N 10000000 10000000| tee $@

experiments/sieve.csv:
	./experiments/collect_times.lua sieve      $N 100000 2000 | tee $@

experiments/queen.csv:
	./experiments/collect_times.lua queen      $N 13 | tee $@

experiments/conway.csv:
	./experiments/collect_times.lua conway     $N 4000 | tee $@

experiments/centroid.csv:
	./experiments/collect_times.lua centroid   $N 10000 100000| tee $@

#

experiments/matmulperf.csv:
	./experiments/collect_perf.lua $N | tee $@

#

clean:
	rm -- $(CSVS)


