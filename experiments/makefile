
#
# You must run this from the root project folder:
#   make -f experiments/makefile
#

INPUTS:=experiments/matmul.csv experiments/binsearch.csv experiments/sieve.csv experiments/queen.csv \
      experiments/conway.csv experiments/centroid.csv

OUTPUTS:=experiments/all_times.csv experiments/matmulperf.csv

.PHONY: all clean

all: $(OUTPUTS)

experiments/all_times.csv: $(INPUTS)
	echo "benchmark,impl,time" > $@
	cat $^ >> $@

experiments/matmul.csv:
	./experiments/collect_times.lua matmul | tee $@

experiments/binsearch.csv:
	./experiments/collect_times.lua binsearch | tee $@

experiments/sieve.csv:
	./experiments/collect_times.lua sieve | tee $@

experiments/queen.csv:
	./experiments/collect_times.lua queen | tee $@

experiments/conway.csv:
	./experiments/collect_times.lua conway | tee $@

experiments/centroid.csv:
	./experiments/collect_times.lua centroid | tee $@

#

experiments/matmulperf.csv:
	./experiments/collect_perf.lua | tee $@

#

clean:
	rm -- $(INPUTS) $(OUTPUTS)


