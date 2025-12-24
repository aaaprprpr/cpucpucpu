//IF.v 取指
`include "lib/defines.vh"
module IF(
    input wire clk,         //时钟
    input wire rst,         //复位
    input wire [`StallBus-1:0] stall,           //流水线暂停信号总线
    // input wire flush,
    // input wire [31:0] new_pc,
    input wire [`BR_WD-1:0] br_bus,         //打包信号
    output wire [`IF_TO_ID_WD-1:0] if_to_id_bus,//IF到ID的流水线总线
    
    output wire inst_sram_en,//这四个是指令存储器接口，IF唯一的对外接口
    output wire [3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata
);
    reg [31:0] pc_reg;//当前pc寄存器
    reg ce_reg;//取指使能，cpu启动后为1
    wire [31:0] next_pc;//下一个pc
    wire br_e;//是否跳转
    wire [31:0] br_addr;//跳转目标地址
    
    //拆包
    assign {
        br_e,
        br_addr
    } = br_bus;

    //pc寄存器更新
    always @ (posedge clk) begin
        if (rst) begin
            pc_reg <= 32'hbfbf_fffc;//MIPS标准复位入口地址
        end
        else if (stall[0]==`NoStop) begin
            pc_reg <= next_pc;
        end
    end
    //cpu启动开关
    always @ (posedge clk) begin
        if (rst) begin//复位期间
            ce_reg <= 1'b0;
        end
        else if (stall[0]==`NoStop) begin
            ce_reg <= 1'b1;
        end
    end

    //下一pc，根据bre判断是否跳转，不跳就pc+4
    assign next_pc = br_e ? br_addr                   
                     : pc_reg + 32'h4;

    
    assign inst_sram_en = 1'b1;//ce_reg;//只要cpu启动就取指
    assign inst_sram_wen = 4'b0;//永远不写指令ram
    assign inst_sram_addr = pc_reg;//用pc取指
    assign inst_sram_wdata = 32'b0;//
    //IF到ID总线
    assign if_to_id_bus = {
        ce_reg,//是否有效，使能信号
        pc_reg//寄存器的pc值
    };

endmodule