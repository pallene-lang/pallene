#install packages with install.packages(<name>)
library(ggplot2)
library(dplyr)
library(tidyr)
library(purrr)
library(xtable)

####################

filter_impls <- function(df, impls) {
  df %>%
    filter(Implementation %in% impls) %>%
    mutate(Implementation = factor(Implementation, levels=impls))
}

normalize_times <- function(df, normal_times) {
  df %>%
    inner_join(normal_times, by=c("Benchmark")) %>%
    mutate(Time=Time/NormalTime) %>%
    group_by(Benchmark,Implementation) %>%
    summarize(
      mean_time = mean(Time),
      sd_time  = sd(Time),
      lo_quantile = quantile(Time, 0.5),
      hi_quantile = quantile(Time, 0.95),
      min_time = min(Time),
      max_time = max(Time))
}

plot_bargraph <- function(df) {
  dodge <- position_dodge(0.9)
  
  ggplot(df, aes(x=Benchmark, y=mean_time, fill=Implementation)) +
    geom_col(position=dodge) +
    geom_linerange(aes(x=Benchmark,ymin=lo_quantile,max=hi_quantile), position=dodge) +
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

data  <- bind_rows(map(benchmarks, read.csv, stringsAsFactors=FALSE))

mean_times <- data %>%
  group_by(Benchmark,Implementation) %>%
  summarize(Time=mean(Time))

# 1) Bar Graphs
# =============

# Normalize by Lua running time

mean_times_lua     <- mean_times %>%
  filter(Implementation=="lua") %>%
  select(Benchmark, NormalTime=Time)

mean_times_nocheck <- mean_times %>% 
  filter(Implementation=="nocheck") %>%
  select(Benchmark, NormalTime=Time)

normalized_times_by_lua <- data %>%
  filter_impls(c("lua", "capi", "luajit", "pallene", "purec")) %>%
  normalize_times(mean_times_lua)

normalized_times_by_nocheck <- data %>%
  filter_impls(c("pallene", "nocheck")) %>%
  normalize_times(mean_times_nocheck)

# Plot everyone (except nocheck)
plot1 <- plot_bargraph(normalized_times_by_lua)
ggsave("normalized_times.pdf", plot=plot1, device=plot_device)

# Plot No Check 
plot2 <- plot_bargraph(normalized_times_by_nocheck)
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

perf_data <- read.csv("matmulperf.csv", stringsAsFactors=FALSE)

perf_mean_times <- perf_data %>%
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
