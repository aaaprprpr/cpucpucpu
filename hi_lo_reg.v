`include "lib/defines.vh" 
// 高低位寄存器，存64位
// hi和lo属于协处理器，不在通用寄存器的范围内。
// 这两个寄存器主要是在用来处理乘法和除法。
// 以乘法作为示例，如果两个整数相乘，那么乘法的结果低位保存在lo寄存器，高位保存在hi寄存器。
// 当然，这两个寄存器也可以独立进行读取和写入。
// 读的时候，使用mfhi、mflo；写入的时候，用mthi、mtlo。
// 和通用寄存器不同，mfhi、mflo是在执行阶段才开始从hi、lo寄存器获取数值的。
// 写入则和通用寄存器一样，也是在写回的时候完成的。

module hi_lo_reg(
    input wire clk,                  // 时钟信号

    input wire hi_we,                // HI寄存器写使能信号
    input wire lo_we,                // LO寄存器写使能信号

    input wire [31:0] hi_wdata,      // HI寄存器写入数据
    input wire [31:0] lo_wdata,      // LO寄存器写入数据

    output wire [31:0] hi_rdata,     // HI寄存器读出数据
    output wire [31:0] lo_rdata      // LO寄存器读出数据
);

    // 内部寄存器，保存HI和LO的当前值
    reg [31:0] reg_hi;
    reg [31:0] reg_lo;

    always @ (posedge clk) begin
        // 如果同时使能HI和LO寄存器的写操作
        if (hi_we & lo_we) begin
            reg_hi <= hi_wdata;  // 更新HI寄存器
            reg_lo <= lo_wdata;  // 更新LO寄存器
        end
        // 如果仅使能LO寄存器的写操作
        else if (~hi_we & lo_we) begin
            reg_lo <= lo_wdata;  // 更新LO寄存器
        end
        // 如果仅使能HI寄存器的写操作
        else if (hi_we & ~lo_we) begin
            reg_hi <= hi_wdata;  // 更新HI寄存器
        end
        // 如果既不使能HI也不使能LO，则保持当前值
    end

    // 将HI和LO寄存器的当前值输出
    assign hi_rdata = reg_hi;
    assign lo_rdata = reg_lo;


endmodule
