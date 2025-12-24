//ID.v 译码
`include "lib/defines.vh"
module ID(
    input wire clk,//时钟
    input wire rst,//复位
    
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    output wire stallreq,
    output wire stallreq_for_ex,
output wire stallreq_for_load,

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,//fromIF pc和ce
    input wire [31:0] inst_sram_rdata,//from指令RAM 32位指令
    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,//fromWB 写回寄存器的信息
    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,//fromEX 执行所需的全部控制和数据
    output wire [`BR_WD-1:0] br_bus //fromIF 分支是否成立+跳转地址
);
    reg [31:0] inst_r;

    //IF
    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;//ID的流水线寄存器，把给IF的数据 存一拍
    wire [31:0] inst;//当前指令
    wire [31:0] id_pc;//当前指令对应的PC值
    wire ce;//

    //WB
    wire wb_rf_we;//WB是否写回寄存器
    wire [4:0] wb_rf_waddr;//写回寄存器地址
    wire [31:0] wb_rf_wdata;//写回数据
reg br_taken_d;
assign stallreq_for_ex = br_taken_d;
assign stallreq_for_load = 1'b0;

always @(posedge clk) begin
    if (rst) begin
        br_taken_d <= 1'b0;
    end else if (stall[1] == `NoStop) begin
        br_taken_d <=ce & br_e;
    end
end


    always @ (posedge clk) begin
        if (rst) begin//复位清空ID寄存器，pc和ce全设成0
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;     
            inst_r <= 32'b0;   
        end
        // else if (flush) begin//强制把当前流水级的指令作废，目前用不到
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin//ID 停了，但 EX 还在走, 为了避免同一条指令被 EX 用了两次
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;//往 ID→EX 方向塞一个“空指令”（bubble），插气泡
            inst_r <= 32'b0;
        end

        else if (stall[1]==`NoStop) begin//ID 级不需要停，那就把 IF 的输出接过来。
            if_to_id_bus_r <= if_to_id_bus;
            inst_r <= inst_sram_rdata;
        end
    end
    
    //拆包
    assign inst = inst_r;//向RAM 要指令
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;//接IF的控制信号
    
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;

    //指令字段拆分
    wire [5:0] opcode;//[31:26]指令大类
    wire [4:0] rs,rt,rd,sa;//[25:21][20:16][15:11][10:6]源寄存器 1，源/目的寄存器，目的寄存器，shift amount
    wire [5:0] func;//[5:0]R 型子操作
    wire [15:0] imm;//[15:0]立即数
    
    wire [25:0] instr_index;//[25:0]J 型目标
    wire [19:0] code;//[25:6]特权/异常用
    wire [4:0] base;//[25:21]load/store 基址
    wire [15:0] offset;//[15:0]load/store 偏移
    wire [2:0] sel;//[2:0]特权寄存器选择

    //one-hot 译码结果，储存上面拆分的译码结果
    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    //ALU 控制选择信号
    wire [2:0] sel_alu_src1;//ALU 第一个操作数来自哪 [2] sa（位移量） [1] pc [0] rs
    wire [3:0] sel_alu_src2;//ALU 第二个操作数来自哪 [3] zero-ext imm零扩展立即数 [2] 常数 8 pc+8 [1] sign-ext imm符号扩展立即数 [0] rt
    wire [11:0] alu_op;//ALU 做什么运算 {add, sub, slt, sltu, and, nor, or, xor, sll, srl, sra, lui}

    //访存相关控制（现在是占位）
    wire data_ram_en;//是否访问数据内存
    wire [3:0] data_ram_wen;//写内存字节使能
    
    //寄存器写回控制
    wire rf_we;//这一条指令最终是否写寄存器
    wire [4:0] rf_waddr;//根据 sel_rf_dst 拼出来的最终寄存器号。
    wire sel_rf_res;// 0 写 ALU 结果 1 写内存读取结果
    wire [2:0] sel_rf_dst;//写哪个寄存器 [2] $31 [1]rt [0] rd

    //寄存器堆读出的真实数据
    wire [31:0] rdata1, rdata2;//rs、rt 寄存器里当前存的 32 位值

    regfile u_regfile(
    	.clk    (clk    ),
    	//ID->EX
        .raddr1 (rs ),//指定要读哪个寄存器
        .rdata1 (rdata1 ),//第一个操作数
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        //ID->WB
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
    );
    
    //接线
    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];

    wire inst_ori, inst_lui, inst_addiu, inst_beq;
    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;

    //实例化解码器
    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );

    assign inst_ori     = op_d[6'b00_1101];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_beq     = op_d[6'b00_0100];


    //==============================处理控制信号==============================
    // rs to reg1
    assign sel_alu_src1[0] = inst_ori | inst_addiu;

    // pc to reg1
    assign sel_alu_src1[1] = 1'b0;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = 1'b0;

    
    // rt to reg2
    assign sel_alu_src2[0] = 1'b0;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = 1'b0;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori;

    assign op_add = inst_addiu;
    assign op_sub = 1'b0;
    assign op_slt = 1'b0;
    assign op_sltu = 1'b0;
    assign op_and = 1'b0;
    assign op_nor = 1'b0;
    assign op_or = inst_ori;
    assign op_xor = 1'b0;
    assign op_sll = 1'b0;
    assign op_srl = 1'b0;
    assign op_sra = 1'b0;
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};

    // load and store enable
    assign data_ram_en = 1'b0;

    // write enable
    assign data_ram_wen = 1'b0;

    // regfile store enable
    assign rf_we = ce&( inst_ori | inst_lui | inst_addiu);

    // store in [rd]
    assign sel_rf_dst[0] = 1'b0;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu;
    // store in [31]
    assign sel_rf_dst[2] = 1'b0;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = 1'b0; 
    
    //打包发给EX
    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rdata1,         // 63:32
        rdata2          // 31:0
    };

    //分支判断ID->IF
    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4;

    assign rs_eq_rt = (rdata1 == rdata2);

    assign br_e = ce &(inst_beq & rs_eq_rt);
    assign br_addr =(ce& inst_beq) ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) : 32'b0;

    assign br_bus = {
        br_e,
        br_addr
    };
    
endmodule