//`include "config.vh"
module tb ();
    reg wr_clk;
    reg rd_clk;
    reg reset;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0]data_in;
    wire [DATA_WIDTH-1:0]data_out;
    wire full,empty;
    wire almost_full,almost_empty;
/*进行参数化，不在调用时直接使用数字是因为tb内部也使用了DEPTH等数据，必须定义出来
在其他模块调用FIFO的时候直接写数字就行，像tb这类需要使用具体变量的需要先定义
不用写在#()里，因为dut的#()：是为了“被别人调用”时留出的接口。
parameter用于参数化，类似模块内部的宏定义
*/
    parameter DATA_WIDTH =8;
    parameter DEPTH =16;
    parameter ALMOST_FULL_TH =4;
    parameter ALMOST_EMPTY_TH =4;
    
    reg [DATA_WIDTH-1:0] expected_queue[$]; // 定义一个自动伸缩的队列

    FIFO#(.DATA_WIDTH(DATA_WIDTH),.DEPTH(DEPTH),.ALMOST_FULL_TH(ALMOST_FULL_TH),.ALMOST_EMPTY_TH(ALMOST_EMPTY_TH)) f1(wr_clk,rd_clk,reset,wr_en,rd_en,data_in,data_out,full,empty,almost_full,almost_empty);
    
    always #3 wr_clk=~wr_clk;
    always #7 rd_clk=~rd_clk;

    integer hit_full = 0; 
    integer hit_empty = 0;

    initial begin
        wr_clk = 0;rd_clk=0; reset = 1; wr_en = 0; data_in = 0;
        #20 reset = 0;
        forever begin
            @(posedge wr_clk);//后面都跟<=，就是等上升沿跳变后的极短时间进行赋值，完美模拟触发器。跟=会引发竞争冒险
            if (!full) begin
                wr_en <= $random % 2; // 50% 概率写入
                if (wr_en) begin
                    data_in <= $random % (2**DATA_WIDTH);
                    expected_queue.push_back(data_in); 
                end
            end else begin
                wr_en <= 0; // 满了必须停,而且不需要对指针进行自增操作，只需要决定是否写入。用size判断还有多少元素
            end
        end
    end
    reg [DATA_WIDTH-1:0] exp_data;
    initial begin
        rd_en = 0;
        wait(!reset); // 等复位结束

        forever begin
            @(posedge rd_clk); // 紧跟读时钟
            if (!empty) begin
                rd_en <= $random % 2; // 50% 概率读取
                if (rd_en) begin
                    #1;//赋值用<=，比较用#1，在都稳定之后再进行比较
                    if (expected_queue.size() > 0) begin//用size判断而不是empty
                        exp_data = expected_queue.pop_front();// 可以使用automatic动态分配局部内存，避开静态变量重入冲突，每一拍产生的 exp_data 都应该是独立的个体.读完之后从队列中物理删除这个数据
                        if (data_out !== exp_data) begin
                            $display("ERROR!!! Time:%0t | Expected:%h | Data:%h", $time, exp_data, data_out);
                        end else begin
                            $display("PASS!!!! Time:%0t | Data:%h", $time, data_out);
                        end
                    end
                end
            end else begin
                rd_en <= 0; // 空了必须停
            end
        end
    end

    always @(posedge wr_clk) begin
    if (!reset) begin
        if ((expected_queue.size() >= (DEPTH - ALMOST_FULL_TH +3 ))&&(!almost_full)) begin
        //if ((expected_queue.size() >= (`DEPTH - `ALMOST_FULL_TH ))&&(!almost_full))这么写有问题
        //前者判断的是实时的，就是现实的读写指针差距达到阈值。但是后者almost_full使用的是写指针看到的读指针或读指针看到的写指针，
        //可能现实两个指针已经达到阈值了但是后者由于慢了几拍判断还没有达到阈值,所以会报错
        //所以引入3这个缓冲区，最坏的情况是旧的比真实的晚了2-3拍
            $display("ALMOST_FULL ERROR at %0t", $time);
        end
    end
end
    always @(posedge rd_clk) begin
    if (!reset) begin
        if ((expected_queue.size() <= ALMOST_EMPTY_TH -3)&&(!almost_empty)) begin
            $display("ALMOST_EMPTY ERROR at %0t", $time);
        end
    end
end

    initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb);

    #5000; 
    
    $display("========================================");
    $display("Final Report: Full_hits:%0d, Empty_hits:%0d", hit_full, hit_empty);
    $display("================TEST END================");
    $finish;
end

reg full_d1;
always @(posedge wr_clk) begin
    full_d1 <= full;
    if (full && !full_d1) hit_full++; // 只有在变满的一瞬间计数
end

reg empty_d1;
always @(posedge rd_clk) begin
    empty_d1 <= empty;
    if (empty && !empty_d1) hit_empty++;
end
endmodule
/*
1.reg [`DATA_WIDTH-1:0] expected_queue[$];定义一个自动伸缩的队列
expected_queue.push_back(data_in);队列末尾添加元素
data = expected_queue.pop_front();从队列开头取出并移除元素
expected_queue.delete();清空整个队列
size(): 返回队列中当前元素的个数
[index]: 像数组一样访问某个位置的值（但不删除它）expected_queue[0] 是队首，expected_queue[$] 是队尾
push_front(data): 在队列开头插入元素
pop_back(): 从队列末尾弹出元素
insert(index, data): 在指定位置插入
expected_queue.insert(2, 8'hAA); // 在索引2的位置插入AA
delete(index): 删除指定位置的元素。
expected_queue.delete(0); // 等同于 pop_front 但不返回值
2。在testbench是不存在触发器，我是模拟了一个触发器，具体的操作就是@(posedge clk)后面赋值用<=,
比较用#1，形成的现象就是上升沿到来取的是前一瞬间的值然后上升沿瞬间锁定，上升沿结束再赋值。
3.为什么testbench和dut逻辑不一样？
DUT 是“造机器”，TB 是“上帝视角对答案”
TB 使用的Queue (队列)$random、initial、forever 都是不可综合的语法。它们在芯片里找不到对应的晶体管电路。
比如 Queue，硬件里没有能“自动无限伸缩”的存储，必须老老实实写 RAM、写读写指针。
DUT (异步 FIFO)：侧重于严谨的物理同步。它必须处理跨时钟域（CDC）、亚稳态、物理存储映射。
TB (验证)：侧重于行为级描述。TB 是“上帝视角”，它知道我刚才喂进去了什么，所以它能用最简单的软件逻辑（队列）来验证复杂的硬件逻辑。
如果 DUT 用 TB 的逻辑写，编译器会直接报错，因为它无法映射到 FPGA 或硅片的门电路上。
4.在forever或repeat循环中使用automatic确保每循环一次定义的变量都用一个新的内存，是独立的。
如果不加 automatic，变量是 static（静态）的。这就好比一个回收站里的旧瓶子，下一轮循环只是把里面的水倒掉换
成新的，但瓶子还是那个瓶子。如果上一轮循环还没结束（比如有延迟），下一轮就开始灌水，数据就乱了。
5.没有使用automatic变量的原因是：iverilog 的一个已知局限性，虽然它支持 -g2012，但它目前不支持在特定的
 begin...end 块内局部使用 automatic。它要求如果一个任务或模块是 automatic，那么整个模块都得是。而且异步FIFO已经#1了所以
 几乎不存在重入问题。
*/