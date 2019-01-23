library(ggplot2)
library(dplyr)
library(tidyr)
library(purrr)
library(xtable)

####################

remove_outliers <- function(df) {
  # Remove top 5% and bottom 5% times!!True
  filter(df, between(ntile(Time, 20), 1, 18))
}

plot_bargraph <- function(df, impls) {
  plot_data <- normalized_times %>%
    filter(Implementation %in% impls) %>%
    mutate(Implementation = factor(Implementation, levels=impls))
  
  dodge <- position_dodge(0.9)
  
  ggplot(plot_data, aes(x=Benchmark, y=mean_time, fill=Implementation)) +
    geom_col(position=dodge) +
    geom_linerange(aes(x=Benchmark, ymin=min_time, ymax=max_time), position=dodge) +
    scale_y_continuous(breaks=seq(from=0.2,to=1.2,by=0.2)) +
    scale_fill_brewer(palette="Paired") +
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

data_all  <- bind_rows(map(benchmarks, read.csv, stringsAsFactors=FALSE))

data <- data_all %>%
  group_by(Benchmark, Implementation) %>%
    remove_outliers() %>%
    ungroup()

mean_times <- data %>%
  group_by(Benchmark,Implementation) %>%
  summarize(Time=mean(Time))

# 1) Bar Graphs
# =============

# Normalize by Lua running time

mean_lua <- mean_times %>%
  filter(Implementation=="lua") %>%
  select(Benchmark, mean_lua_time=Time)

normalized_times <- data %>%
  inner_join(mean_lua, by=c("Benchmark")) %>%
  mutate(Time=Time/mean_lua_time) %>%
  group_by(Benchmark,Implementation) %>%
    mutate(
      mean_time = mean(Time),
      min_time = min(Time),
      max_time = max(Time)) %>%
    ungroup()

# Plot everyone (except nocheck)
plot1 <- plot_bargraph(normalized_times, c("lua", "capi", "luajit", "pallene", "purec"))
ggsave("normalized_times.pdf", plot=plot1, device=plot_device)

# Plot No Check 
plot2 <- plot_bargraph(normalized_times, c("pallene", "nocheck"))
ggsave("nocheck_normalized_times.pdf", plot=plot2, device=plot_device)

# 2) Latex table for raw data
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

# 3) Latex table for perf tests
# =============================

perf_data_all <- read.csv("matmulperf.csv", stringsAsFactors=FALSE)

perf_data <- perf_data_all %>%
  group_by(N,M,Implementation) %>%
    remove_outliers() %>%
    ungroup()

perf_mean_times <- perf_data %>%
  group_by(N,M,Implementation) %>%
  summarize(
      Time=mean(Time),
      IPC=mean(IPC),
      llc_miss_pct=mean(llc_miss_pct))

perf_mean_times_pallene <- perf_data %>%
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