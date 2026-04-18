//参数化适配，利用头文件与编译器指令构建了单一真值源配置层，支持数据位宽与深度的动态调整。
//并进行自动化位宽计算，采用 $clog2 系统函数实现了地址总线与深度（Depth）的逻辑解耦，确保在任意深度（包括非 2 的幂次方）配置下，逻辑资源占用达到最优。
//`include "config.vh"

module FIFO#(
    parameter DATA_WIDTH=8,
    parameter DEPTH =16
)(
    input clk,
    input reset,
    input wr_en,
    input rd_en,
    input [DATA_WIDTH-1:0]data_in,
    output reg [DATA_WIDTH-1:0]data_out,
    output full,empty
);
    localparam ADDR_WIDTH=$clog2(DEPTH);//定义地址宽度
    localparam PR_WIDTH=ADDR_WIDTH+1;//定义指针宽度,多的一位最高位表示圈数
    reg [PR_WIDTH-1:0]w_pr,r_pr;
    reg[DATA_WIDTH-1:0]mem[0:DEPTH-1];

    always@(posedge clk or posedge reset)begin
        if(reset) begin
            w_pr<=0;
        end
        else if(wr_en&&!full)begin
            mem[w_pr[ADDR_WIDTH-1:0]]<=data_in;           
            if (w_pr[ADDR_WIDTH-1:0] == DEPTH - 1)
                    w_pr <= {~w_pr[PR_WIDTH-1], {ADDR_WIDTH{1'b0}}};//指针在到达 DEPTH-1 时精准回绕,防止出现由于向上取整导致的多余无效地址
            else w_pr<=w_pr+1;//填满后高位自动置1或变0
        end
        end


    always@(posedge clk or posedge reset)begin
        if(reset) begin
            r_pr<=0; 
            data_out<=0;
        end
        else if(rd_en&&!empty)begin
            data_out<=mem[r_pr[ADDR_WIDTH-1:0]];
            if(r_pr[ADDR_WIDTH-1:0]==DEPTH-1)
                r_pr<={~r_pr[PR_WIDTH-1],{ADDR_WIDTH{1'b0}}};
            else r_pr<=r_pr+1;
        end
    end

    assign full=(r_pr[ADDR_WIDTH-1:0]==w_pr[ADDR_WIDTH-1:0]&&(r_pr[PR_WIDTH-1]!=w_pr[PR_WIDTH-1]));
    assign empty=(r_pr==w_pr);
endmodule
/*写入和读取操作最好放在两个always块中写，代码比较清爽，并且当同时读和写是两个always块并行执行没有争议
有点像一个环形跑道，r_pr是起点，w_pr是终点，起终点时刻变化，empty就是起点追上终点，full就是终点套圈追上起点。如果full当成w_pr==3那就是一次性了
!=表示普通不等于：1！=x结果为x,!==表示严格不等于：1！==x结果为1.！=表示比较每一位有任何一位不同返回1
在写dut过程中使用==和!=,在写testbench时用===和!==.dut用逻辑比较，tb用严格比较
clog2 代表 Ceiling of Logarithm base 2（以 2 为底的对数的向上取整）。
parameter（外部可调）例化一个模块时，可以在外部（比如在 Testbench 里）修改它的值
localparam（内部常量）定义在模块内部，外部环境（上层模块）绝对无法修改它
头文件后缀名通常是 .vh,存放全局参数、宏定义、状态机编码等。使用 `include 指令时，编译器会把头文件的内容原地复制到你的代码里。
*/