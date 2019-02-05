#install packages with install.packages(<name>)
library(ggplot2)
library(dplyr)
library(tidyr)
library(purrr)
library(xtable)
library(RColorBrewer)

####################

filter_impls <- function(df, impls) {
  df %>%
    filter(Implementation %in% impls) %>%
    mutate(Implementation = factor(Implementation, levels=impls))
}

discard_outliers <- function(df) {
  df %>%
    mutate(rank = ntile(Time, 20)) %>%
    filter(between(rank, 2, 19)) %>%
    mutate(rank = NULL)
}

normalize_times <- function(df, normal_times) {
  df %>%
    inner_join(normal_times, by=c("Benchmark")) %>%
    mutate(Time=Time/NormalTime) %>%
    group_by(Benchmark,Implementation) %>%
    summarize(
      median_time = median(Time),
      sd_time  = sd(Time),
      min_time = min(Time),
      max_time = max(Time)) %>%
    ungroup()
}

plot_bargraph <- function(df, colors) {
  dodge <- position_dodge(0.9)
  
  ggplot(df, aes(x=Benchmark, y=median_time, fill=Implementation)) +
    geom_col(position=dodge) +
    geom_linerange(aes(x=Benchmark,ymin=min_time,max=max_time), position=dodge) +
    scale_y_continuous(breaks=seq(from=0.2,to=1.2,by=0.2), limits=c(0.0, 1.4)) +
    scale_fill_manual(values=colors) +
    xlab("Benchmark") + 
    ylab("Time (normalized)") +
    theme_bw() +
    theme(legend.position = "bottom")
}

if(!exists("plot_device")) { # Avoid memory leak when re-sourcing
  plot_device <- cairo_pdf()
}

####################

benchmarks <- c(
  "binsearch.csv",
  "centroid.csv",
  "conway.csv",
  "matmul.csv",
  "queen.csv",
  "sieve.csv"
)

all_data  <-
  bind_rows(map(benchmarks, read.csv, stringsAsFactors=FALSE))

# Discarding outliers here is OK because we only use medians, not means
data <- all_data %>%
  group_by(Benchmark, Implementation) %>%
  filter(between(Seq, 3, 42)) %>% #force N=40
  discard_outliers() %>%
  ungroup()

median_times <- data %>%
  group_by(Benchmark,Implementation) %>%
  summarize(Time=median(Time)) %>%
  ungroup()

# 1) Bar Graphs
# =============

# Normalize by Lua running time

median_times_lua     <- median_times %>%
  filter(Implementation=="Lua 5.4") %>%
  select(Benchmark, NormalTime=Time)

median_times_nocheck <- median_times %>% 
  filter(Implementation=="No Check") %>%
  select(Benchmark, NormalTime=Time)

normalized_times_by_lua <- data %>%
  filter_impls(c("Lua 5.4", "Lua-C API", "LuaJIT 2.1", "Pallene", "C")) %>%
  normalize_times(median_times_lua)

normalized_times_by_nocheck <- data %>%
  filter_impls(c("No Check", "Pallene")) %>%
  normalize_times(median_times_nocheck)

colors <- brewer.pal(10, "Paired")

# Plot everyone (except nocheck)
p1col <- c(colors[1], colors[2], colors[7], colors[4], colors[5])
plot1 <- plot_bargraph(normalized_times_by_lua, p1col)
ggsave("normalized_times.pdf", plot=plot1, device=plot_device, width=10, height=5)

# Plot No Check
p2col <- c(colors[3], colors[4])
plot2 <- plot_bargraph(normalized_times_by_nocheck, p2col)
ggsave("nocheck_normalized_times.pdf", plot=plot2, device=plot_device, width=10, height=5)

# 2) Latex table for raw data
# ===========================

table_impls <- c(
  "Lua",
  "Lua-C API",
  "LuaJIT 2.1",
  "Pallene",
  "No Check",
  "C"
)

median_times_table <- median_times %>%
  filter(Implementation %in% table_impls) %>%
  mutate(Implementation = factor(Implementation, levels=table_impls)) %>%
  spread(Implementation, Time)

print(xtable(median_times_table),
      file = "median_times_table.tex",
      floating = FALSE,
      latex.environments = NULL,
      include.rownames = FALSE,
      include.colnames = TRUE,
      booktabs = TRUE
)

# 3) Latex table for perf tests
# =============================

perf_data <-
  read.csv("matmulperf.csv", stringsAsFactors=FALSE)

perf_median_times <- perf_data %>%
  group_by(N,M,Implementation) %>%
  summarize(
    Time = median(Time),
    Cycles = median(Cycles),
    Instructions = median(Instructions),
    IPC = median(IPC),
    branch_miss_pct = median(branch_miss_pct), 
    llc_miss_pct = median(llc_miss_pct)) %>%
  ungroup()
#N,M,Implementation,Time,Cycles,Instructions,IPC,branch_miss_pct,llc_miss_pct,Seq

perf_median_times_pallene <- perf_median_times %>%
  filter(Implementation=="Pallene") %>%
  select(
    N=N,
    M=M,
    Pallene_Time=Time,
    Pallene_LLC=llc_miss_pct)

perf_median_times_luajit <- perf_median_times %>%
  filter(Implementation=="LuaJIT 2.1") %>%
  select(
    N=N,
    M=M,
    LuaJIT_Time=Time,
    LuaJIT_LLC=llc_miss_pct)

perf_median_times_table <-
  inner_join(perf_median_times_pallene, perf_median_times_luajit, by=c("N","M")) %>%
  mutate(TimeRatio = Pallene_Time / LuaJIT_Time) %>%
  select(N,M,TimeRatio,Pallene_Time,LuaJIT_Time,Pallene_LLC,LuaJIT_LLC)

print(xtable(perf_median_times_table),
      file = "perf_table.tex",
      floating = FALSE,
      latex.environments = NULL,
      include.rownames = FALSE,
      include.colnames = TRUE,
      booktabs = TRUE
)

# 4) Print a Latex table of matmul nocheck running times

perf_matmul <- perf_median_times %>%
  filter(N==800, M==2, Implementation %in% c("Pallene", "No Check")) %>%
  select(Implementation, Time, Cycles, Instructions, IPC)

print(xtable(perf_matmul),
      file = "perf_matmul.tex",
      floating = FALSE,
      latex.environments = NULL,
      include.rownames = FALSE,
      include.colnames = TRUE,
      booktabs = TRUE
)
