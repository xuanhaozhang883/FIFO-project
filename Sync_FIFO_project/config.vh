`ifndef CONFIG_VH
`define CONFIG_VH

// 全局硬件规格定义
`define DATA_WIDTH 8
`define DEPTH 10  // 修改这里，全工程自动同步

`endif
/*
`ifndef CONFIG_VH
`define CONFIG_VH
...
`endif是文件卫士，如果还没定义过 CONFIG_VH 这个名字，那就定义它，并编译下面的内容。
*/