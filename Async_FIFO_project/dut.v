/*`include "config.vh"不使用头文件的原因是如果整个工程里需要很多FIFO且深度不一样的时候使用宏定义没办法实现
因此更倾向于使用 parameter
*/
module FIFO#(
    parameter DATA_WIDTH =8,
    parameter DEPTH =16,
    parameter ALMOST_FULL_TH =4,
    parameter ALMOST_EMPTY_TH =4)(
    input wr_clk,
    input rd_clk,
    input reset,
    input wr_en,
    input rd_en,
    input [DATA_WIDTH-1:0]data_in,
    output reg [DATA_WIDTH-1:0]data_out,
    output full,empty,
    output almost_full,almost_empty
);
    localparam ADDR_WIDTH=$clog2(DEPTH);
    localparam PR_WIDTH=ADDR_WIDTH+1;
    reg [PR_WIDTH-1:0]w_ptr,r_ptr;
    reg[DATA_WIDTH-1:0]mem[0:DEPTH-1];

    always@(posedge wr_clk or posedge reset)begin
        if(reset) begin
            w_ptr<=0;
        end
        else if(wr_en&&!full)begin
            mem[w_ptr[ADDR_WIDTH-1:0]]<=data_in;           
            w_ptr<=w_ptr+1;
            //删去回滚防止指针溢出的逻辑是因为直接清零并圈数取反会导致格雷码多位跳变，格雷码只有在+1是能
            //保证只有一位跳变。也因此，只能把异步FIFO的容量设置为2的整数次幂防止指针溢出。
        end
        end
//二进制跳变时（如 011 -> 100）会有多位电平同时改变。由于导线延迟不同，接收方采样时可能正好处在“半路”
//捕获到 111 或 000 这种随机数值。所以需要将二进制转化为格雷码，保证每次只有一位跳变，降低亚稳态概率
//把很多位变为中间态的可能缩减到只有一位有可能是中间态
    wire [PR_WIDTH-1:0] w_ptr_gray;//从转换公式可以看出最高位对齐，故位宽相同
    assign w_ptr_gray = (w_ptr >> 1) ^ w_ptr;//转格雷码公式G_{i}=B_{i+1}^B_{i}=>G =(B >> 1)^B，右移一位后高位补0，所以异或后不变

    always@(posedge rd_clk or posedge reset)begin
        if(reset) begin
            r_ptr<=0; 
            data_out<=0;
        end
        else if(rd_en&&!empty)begin
            data_out<=mem[r_ptr[ADDR_WIDTH-1:0]];
            r_ptr<=r_ptr+1;
        end
    end

    wire [PR_WIDTH-1:0] r_ptr_gray;
    assign r_ptr_gray = (r_ptr >> 1) ^ r_ptr;

/*如果需要判断almost状态就需要知道指针之间的距离但是格雷码不能直接进行加减法，所以需要将格雷码转化为二进制
function是组合逻辑，task可用于时序逻辑。function是一个“组合逻辑模块”，输入一来，马上算出输出，写在module里面
在 Verilog 中，函数名本身就是一个隐含的变量，最后赋给函数名的值就是该函数的返回值。
function的主体是在定义完输入和内部变量之后开始的，所以在integer i之后写begin
*/
    function [PR_WIDTH-1:0] gray2bin;
        input [PR_WIDTH-1:0] gray;
        integer i;
        begin
            gray2bin[PR_WIDTH-1] = gray[PR_WIDTH-1];//格雷码转二进制的逻辑B_{i} = B_{i+1} ^ G_{i},由如果 x ^ y = z，那么 x ^ z = y推导，两边同时异或B_{i+1}
            for (i = PR_WIDTH-2; i >= 0; i = i-1)
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
        end
    endfunction
    wire [PR_WIDTH-1:0] w_ptr_bin_r2, r_ptr_bin_w2;
    assign w_ptr_bin_r2 = gray2bin(w_ptr_gray_r2);
    assign r_ptr_bin_w2 = gray2bin(r_ptr_gray_w2);
    wire [PR_WIDTH-1:0] used_w,used_r;
    assign used_w = w_ptr - r_ptr_bin_w2;
    assign used_r = w_ptr_bin_r2 - r_ptr;
//写两个同步器，使那一位的可能中间态转化为稳定的新值或旧值，利用不稳定的电平会由于正反馈作用在一个周期内随机稳定成0/1的特性
//旧值也不会影响结果：
//其实看空就是看读指针是否追上了读指针看到的写指针，它看到的写指针永远比真正的写指针晚一拍，
//而且有可能是新的也可能是旧的。即使追上一拍之前的写指针（恰好是新值），读指针以为空了不读了，
//此刻也是安全的就等下一个看到的写指针往后移位。旧值就会牺牲更长的时间但是不会乱取数据，只会牺牲一部分时间。
    reg [PR_WIDTH-1:0] w_ptr_gray_r1, w_ptr_gray_r2;
    reg [PR_WIDTH-1:0] r_ptr_gray_w1, r_ptr_gray_w2;
    always @(posedge rd_clk or posedge reset) begin
        if (reset) begin
            w_ptr_gray_r1 <= 0;
            w_ptr_gray_r2 <= 0;
        end else begin
            w_ptr_gray_r1 <= w_ptr_gray;    // 抓取信号，上升沿结束瞬间r1可能还是中间态，但是等一个周期后由于正反馈作用就会随机稳定成0或1
            w_ptr_gray_r2 <= w_ptr_gray_r1; // 抓取上一级已经稳定下来的电平，则r2有可能是新值也可能是旧值但不可能是中间值
        end
    end

    always @(posedge wr_clk or posedge reset) begin
        if (reset) begin
            r_ptr_gray_w1 <= 0;
            r_ptr_gray_w2 <= 0;
        end else begin
            r_ptr_gray_w1 <= r_ptr_gray;
            r_ptr_gray_w2 <= r_ptr_gray_w1; 
        end
    end

//两个指针是由不同的晶振(clk)驱动的，当写时钟域的电路去查看读指针 r_pr 时
//读指针可能正好在跳变，写时钟域看到的可能是一个既不是0又不是1的乱码状态，卡在中间态（比如0.5V）。中间态就是亚稳态
//输出端 Q 在这一时刻会表现为高频振荡或卡在中间电压，这会导致亚稳态 (Metastability)，
//full 信号可能会在 0 和 1 之间疯狂抖动，甚至导致整个芯片逻辑死锁。这个就是跨时钟域直接比较 (CDC Error)

    assign full = (w_ptr_gray == {~r_ptr_gray_w2[PR_WIDTH-1:PR_WIDTH-2], r_ptr_gray_w2[PR_WIDTH-3:0]});//格雷码高两位都需要取反
    assign empty=r_ptr_gray==w_ptr_gray_r2;//只使用经过同步器同步后的信号进行判断状态
    assign almost_full = (used_w >=(DEPTH-ALMOST_FULL_TH));
    assign almost_empty = (used_r <= ALMOST_EMPTY_TH);
endmodule
//因此总结出解决CDC Error的两大原则：
//1.单比特采样：把多位宽的变化，变成单比特的亚稳态风险
//2.两级锁存：用时间换取电平的稳定。信号进入新时钟域后，严禁直接参与逻辑运算，必须先过两级触发器。