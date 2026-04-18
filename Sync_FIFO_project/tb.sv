//`include "config.vh"
module tb ();
    reg clk;
    reg reset;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire full;
    wire empty;

    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;

    FIFO #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) f1 (
        .clk(clk), 
        .reset(reset), 
        .wr_en(wr_en), 
        .rd_en(rd_en), 
        .data_in(data_in), 
        .data_out(data_out), 
        .full(full), 
        .empty(empty)
    );

    // 黄金模型
    reg [DATA_WIDTH-1:0] exp_mem [0:1024];
    reg [DATA_WIDTH-1:0] expected_data_out;
    integer wr = 0;
    integer rd = 0;

    // 覆盖率记录变量，改为 reg
    reg hit_full;
    reg hit_empty;

    // 写逻辑
    always @(posedge clk or posedge reset) begin
        if (reset)
            wr <= 0;
        else if (wr_en && (wr - rd < DEPTH)) begin
            exp_mem[wr[9:0]] <= data_in; // 加上位宽截断防止溢出警告
            wr <= wr + 1;
        end
    end

    // 读逻辑
    always @(posedge clk or posedge reset) begin
        if (reset)
            rd <= 0;
        else if (rd_en && wr > rd) begin
            expected_data_out <= exp_mem[rd[9:0]];
            rd <= rd + 1;
        end
    end

    // 覆盖率统计：只要出现过一次就置 1
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            hit_full  <= 0;
            hit_empty <= 0;
        end else begin
            if (full)  hit_full  <= 1;
            if (empty) hit_empty <= 1;
        end
    end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
        
        // 初始化
        clk = 0; reset = 1; wr_en = 0; rd_en = 0; data_in = 0; expected_data_out = 0;
        #15 reset = 0;

        repeat(100) begin // 增加次数以提高满/空概率
            check_step();
        end

        $display("\n================ TEST SUMMARY ================");
        $display("Coverage Results:");
        $display("Full  Status Reached: %s", hit_full  ? "YES" : "NO");
        $display("Empty Status Reached: %s", hit_empty ? "YES" : "NO");
        $display("================== TEST END ==================");
        $finish;
    end
    
    always #5 clk = ~clk;

    task check_step();
    begin
        @(posedge clk);
        wr_en <= $random % 2;
        rd_en <= $random % 2;
        data_in <= $random % (2**DATA_WIDTH);
        #1; // 避开时钟沿进行比对
        
        // 检查数据正确性
        if (rd_en && (wr > rd)) begin
            if (data_out !== expected_data_out)
                $display("ERROR!! Time:%0t | Expected:%h | Data_out:%h", $time, expected_data_out, data_out);
            else
                $display("PASS!!! Time:%0t | Data_out:%h", $time, data_out);
        end

        // 检查标志位逻辑
        if (wr - rd >= DEPTH && !full)
            $display("FULL FLAG ERROR!! Time:%0t", $time);
        if (wr <= rd && !empty)
            $display("EMPTY FLAG ERROR!! Time:%0t", $time);

    end
    endtask

endmodule