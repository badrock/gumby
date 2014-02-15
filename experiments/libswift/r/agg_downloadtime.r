library(ggplot2)
library(reshape)


if (file.exists("seeders.err")) {
    df <- read.table("seeders.err", header = TRUE, check.names = FALSE)
    df$percent <- NULL
    df$download <- NULL
    df$client <- NULL

    p <- ggplot(df, aes(x=time, y=upload, fill=experiment))
    p <- p + geom_line(alpha = 0.8, aes(time, upload, group=experiment, colour=experiment))
    p <- p + theme(legend.position="top", legend.title=element_blank())
    p <- p + labs(x = "\nTime (Seconds)", y = "Speed (KByte/s)\n", title = "Seeders upload speed")
    p

    ggsave(file="seeders_speed.png", width=8, height=6, dpi=100)
}


if (file.exists("leechers.err")) {
    df <- read.table("leechers.err", header = TRUE, check.names = FALSE)
    df$percent <- NULL
    df$upload <- NULL
    df$client <- NULL

    p <- ggplot(df, aes(x=time, y=download, fill=experiment))
    p <- p + geom_line(alpha = 0.8, aes(time, download, group=experiment, colour=experiment))
    p <- p + theme(legend.position="top", legend.title=element_blank())
    p <- p + labs(x = "\nTime (Seconds)", y = "Speed (KByte/s)\n", title = "Leechers download upload")
    p

    ggsave(file="leechers_speed.png", width=8, height=6, dpi=100)
}


if (file.exists("leechers.err")) {
    df <- read.table("leechers.err", header = TRUE, check.names = FALSE)
    df$upload <- NULL
    df$download <- NULL
    df$client <- NULL

    p <- ggplot(df, aes(x=time, y=percent, fill=experiment))
    p <- p + geom_line(alpha = 0.8, aes(time, percent, group=experiment, colour=experiment)) + ylim(0,100)
    p <- p + theme(legend.position="top", legend.title=element_blank())
    p <- p + labs(x = "\nTime (Seconds)", y = "Completion (Percent %)\n", title = "Completion")
    p

    ggsave(file="complete.png", width=8, height=6, dpi=100)
}
    
