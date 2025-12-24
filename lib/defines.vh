//defines.vh
//定义位宽


`define IF_TO_ID_WD 33//
`define ID_TO_EX_WD 159//
`define EX_TO_MEM_WD 76//
`define MEM_TO_WB_WD 70//
`define BR_WD 33//branch width 分支总线位宽
`define DATA_SRAM_WD 69//数据RAM接口相关总线位宽
`define WB_TO_RF_WD 38//WB到RegFile 写回 到 寄存器堆的总线位宽

`define StallBus 6//流水线暂停信号总线
`define NoStop 1'b0//不停止，正常流动
`define Stop 1'b1//停止该流水节点

`define ZeroWord 32'b0//32位全0

//除法div
`define DivFree 2'b00//除法器空闲
`define DivByZero 2'b01//除0
`define DivOn 2'b10//正在除
`define DivEnd 2'b11//除法结束
`define DivResultReady 1'b1//结果准备好了
`define DivResultNotReady 1'b0//没准备好
`define DivStart 1'b1//启动除法
`define DivStop 1'b0//停止除法