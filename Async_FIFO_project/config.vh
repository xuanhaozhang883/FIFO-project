`ifndef CONFIG_VH
`define CONFIG_VH

// 全局硬件规格定义
`define DATA_WIDTH 8
`define DEPTH 32  // 修改这里，全工程自动同步
`define ALMOST_FULL_TH 4
`define ALMOST_EMPTY_TH 4
`endif
/*
`ifndef CONFIG_VH
`define CONFIG_VH
...
`endif是文件卫士，如果还没定义过 CONFIG_VH 这个名字，那就定义它，并编译下面的内容。
这个头文件在异步FIFO项目中没有使用
*/