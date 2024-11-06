#!/bin/sh
set -eu

tabs -8

# 检查输入参数，如果没有指定目录，则默认为根目录
dir=${1:-/}

# 使用find命令统计文件大小，排除特定目录
find "$dir" \( -path "/proc/*" -o -path "/sys/*" -o -path "/boot/*" -o -path "/run/*" -o -path "/dev/*" -o -path "/var/*"  \) -prune -o -type f -exec du -b -- {} + | awk -vOFS='\t' '
BEGIN {split("KB MB GB TB PB", u); u[0] = "B"}
{
    ++hist[$1 ? length($1) - 1 : -1]
    total += $1
}
END {
    max = -2
    for (i in hist)
        max = (i > max ? i : max)

    print "From", "To", "Count\n"
    for (i = -1; i <= max; ++i)
    {
        if (i in hist)
            {
                if (i == -1)
                    print "0B", "0B", hist[i]
                else
                    print 10 ** (i       % 3) u[int(i       / 3)],
                          10 ** ((i + 1) % 3) u[int((i + 1) / 3)],
                          hist[i]
            }
    }
    base = 1024
    unit = "B"
    if (total >= base) {
        total /= base
        unit = "KB"
    }
    if (total >= base) {
        total /= base
        unit = "MB"
    }
    if (total >= base) {
        total /= base
        unit = "GB"
    }
    if (total >= base) {
        total /= base
        unit = "TB"
    }
    printf "\nTotal: %.1f %s in %d files\n",  total,  unit,   NR
    }'