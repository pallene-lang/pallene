library(ggplot2)
library(dplyr)
library(tidyr)
library(purrr)

benchmarks <- c(
  "binsearch.csv",
  "centroid.csv",
  "conway.csv",
  "matmul.csv",
  "queen.csv",
  "sieve.csv"
)

data  <- bind_rows(map(benchmarks, read.csv, stringsAsFactors=FALSE))

# Remove outliers

no_outliers <- data %>%
  group_by(Benchmark, Implementation) %>%
    mutate(qmin=quantile(Time, 0.1), qmax=quantile(Time, 0.9)) %>%
    filter(qmin <= Time & Time <= qmax) %>%
    mutate(qmin=NULL, qmax=NULL) %>%
    ungroup()

mean_times <- no_outliers %>%
  group_by(Benchmark,Implementation) %>%
  summarize(Time=mean(Time))

# 1) Latex table for raw data
# ===========================

table_impls <- c(
  "lua",
  "capi",
  "luajit",
  "pallene",
  "nocheck",
  "purec"
)

mean_times_table <- mean_times %>%
  filter(Implementation %in% table_impls) %>%
  mutate(Implementation = factor(Implementation, levels=table_impls)) %>%
  spread(Implementation, Time)
  

print(xtable(mean_times_table),
  file = "mean_times_table.tex",
  floating = FALSE,
  latex.environments = NULL,
  include.rownames = FALSE,
  include.colnames = TRUE,
  booktabs = TRUE
)

# 2) Bar Graphs
# =============

# Normalize by Lua running time

mean_lua <- mean_times %>%
  filter(Implementation=="lua") %>%
  select(Benchmark, mean_lua_time=Time)

normalized_times <- no_outliers %>%
  inner_join(mean_lua, by=c("Benchmark")) %>%
  mutate(Time=Time/mean_lua_time) %>%
  group_by(Benchmark,Implementation) %>%
    mutate(
      mean_time = mean(Time),
      min_time = min(Time),
      max_time = max(Time)) %>%
    ungroup()

# Plot everyone (except nocheck)

plot1_impls <- c("lua", "capi", "luajit", "pallene", "purec")

plot1_data <- normalized_times %>%
  filter(Implementation %in% plot1_impls) %>%
  mutate(Implementation = factor(Implementation, levels=plot1_impls))

plot1 <- ggplot(plot1_data, aes(Benchmark, mean_time, fill=Implementation)) +
  geom_col(position="dodge") +
  geom_errorbar(aes(x=Benchmark, ymin=min_time, ymax=max_time), position="dodge") +
  scale_y_continuous(breaks=seq(from=0.2,to=1.2,by=0.2)) +
  theme_bw() +
  xlab("Benchmark") + 
  ylab("Time (normalized)") +
  theme(legend.position = "bottom")
ggsave("normalized_times.pdf", plot=plot1, device=cairo_pdf())

# Plot No Check 

plot2_impls <- c("pallene", "nocheck")

plot2_data <- normalized_times %>%
  filter(Implementation %in% plot2_impls) %>%
  mutate(Implementation = factor(Implementation, levels=plot2_impls))

plot2 <- ggplot(plot2_data, aes(Benchmark, mean_time, fill=Implementation)) +
  geom_col(position="dodge") +
  geom_errorbar(aes(x=Benchmark, ymin=min_time, ymax=max_time), position="dodge") +
  scale_y_continuous(breaks=seq(from=0.2,to=1.2,by=0.2)) +
  theme_bw() +
  xlab("Benchmark") + 
  ylab("Time (normalized)") +
  theme(legend.position = "bottom")
ggsave("nocheck_normalized_times.pdf", plot=plot2, device=cairo_pdf())


# 3) Latex table for perf tests
# =============================

perf_data <- read.csv("matmulperf.csv", stringsAsFactors=FALSE)

perf_no_outliers <- perf_data %>%
  group_by(N,M,Implementation) %>%
  mutate(qmin=quantile(Time, 0.1), qmax=quantile(Time, 0.9)) %>%
  filter(qmin <= Time & Time <= qmax) %>%
  mutate(qmin=NULL, qmax=NULL) %>%
  ungroup()

perf_mean_times <- perf_no_outliers %>%
  group_by(N,M,Implementation) %>%
  summarize(
      Time=mean(Time),
      IPC=mean(IPC),
      llc_miss_pct=mean(llc_miss_pct))

perf_mean_times_pallene <- perf_mean_times %>%
  filter(Implementation=="pallene") %>%
  select(
    N=N,
    M=M,
    Pallene_Time=Time,
    Pallene_LLC=llc_miss_pct)

perf_mean_times_luajit <- perf_mean_times %>%
  filter(Implementation=="luajit") %>%
  select(
    N=N,
    M=M,
    LuaJIT_Time=Time,
    LuaJIT_LLC=llc_miss_pct)

perf_mean_times_table <-
  inner_join(perf_mean_times_pallene, perf_mean_times_luajit, by=c("N","M")) %>%
  mutate(TimeRatio = Pallene_Time / LuaJIT_Time) %>%
  select(N,M,TimeRatio,Pallene_Time,LuaJIT_Time,Pallene_LLC,LuaJIT_LLC)

print(xtable(perf_mean_times_table),
      file = "perf_table.tex",
      floating = FALSE,
      latex.environments = NULL,
      include.rownames = FALSE,
      include.colnames = TRUE,
      booktabs = TRUE
)