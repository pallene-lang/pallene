library(ggplot2)
library(dplyr)
library(tidyr)

setwd("/home/hugo/Hugobox/pallene/experiments")
data  <- read.csv("/home/hugo/Hugobox/pallene/experiments/all_times.csv")
data$impl = factor(data$impl, levels=c("lua","capi","luajit","pallene", "purec"))

norm_ref <- data %>% filter(impl=="lua") %>% group_by(benchmark) %>% summarize(normt=mean(time))
ndata <- data %>% inner_join(norm_ref, by=c("benchmark")) %>% mutate(time=time/normt) 
sdata <- ndata %>% group_by(benchmark, impl) %>% mutate(emax = quantile(time, 0.9), emin=quantile(time, 0.1), mtime=mean(time))

plot <- ggplot(sdata, aes(benchmark, mtime, fill=impl)) +
  geom_col(position="dodge") +
  geom_errorbar(aes(x=benchmark, ymax=emax, ymin=emin), position="dodge") +
  scale_y_continuous(breaks=seq(from=0.2,to=1.2,by=0.2)) +
  theme_bw() +
  xlab("Benchmark") + 
  ylab("Time (normalized)") +
  theme(legend.position = "bottom")

ggsave("plot.pdf", plot=plot, device=cairo_pdf())