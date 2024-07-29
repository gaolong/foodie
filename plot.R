library(ggplot2)
library(reshape2)

datasets <- list.dirs(path = '../01-outputs/info', recursive = F)
#datasets <- list.dirs(path = '../02-merge-outputs/info_merge', recursive = F)

pdf("converted_ratio.pdf", width = 3.7, height = 2.5)
print(datasets)

for (f in datasets) {

prefix <- unlist(strsplit(f,'/'))[4]
fname <- paste(f, paste(prefix, '.call.o.txt', sep = ''), sep = '/')
print(fname)

if (!file.exists(fname)) {next}

info = file.info(fname)
empty = (info$size[1] == 0)

if (empty) {next}

print(fname)

stats <- read.delim(fname, header = F)
#print(stats)
#stats <- as.numeric(unlist(stats[2,]))
stats <- as.numeric(unlist(stats[1,]))
stats <- matrix(stats, nrow = 8)
stats <- t(stats[c(2,4,6,8),]/(stats[c(1,3,5,7),] + stats[c(2,4,6,8),]))
print(stats)
rownames(stats) <- colnames(stats) <- c('A','T','C','G')
stats <- as.data.frame(stats)
stats$preceding_base <- rownames(stats)

#prefix <- substring(prefix,8)

stats <- melt(stats, variable.name = "following_base", value.name = "converted_ratio")
p1 <- ggplot(data = stats, aes(x=following_base, y = preceding_base)) + geom_tile(aes(fill = converted_ratio)) + geom_text(aes(label=round(converted_ratio, 3))) + theme_classic() + theme(axis.line = element_blank(), plot.title = element_text(size = 5, face = "bold")) + scale_fill_gradient(low ='white',high ='red', limits=c(0,1)) + ggtitle(prefix)
print(p1)
}

dev.off()
