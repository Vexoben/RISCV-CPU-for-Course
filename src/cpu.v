// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "define.v"
// `include "RegFile.v"
// `include "MemCtrl.v"
// `include "InsFetch/InsFetcher.v"
// `include "InsFetch/Predictor.v"
// `include "Issue/Dispatcher.v"
// `include "Issue/Decoder.v"
// `include "Execute/RS.v"
// `include "Execute/LSB.v"
// `include "ROB.v"

module cpu(
   input  wire                 clk_in,			// system clock signal
   input  wire                 rst_in,			// reset signal
   input  wire					    rdy_in,			// ready signal, pause cpu when low
   
   input  wire [ 7:0]          mem_din,		// data input bus
   output wire [ 7:0]          mem_dout,		// data output bus
   output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
   output wire                 mem_wr,			// write/read signal (1 for write)
     
   input  wire                 io_buffer_full, // 1 if uart buffer is full
     
   output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

wire full_rob, full_lsb, full_rs, full_any_component;
assign full_any_component = full_rob || full_rs || full_lsb;

// define 
// RegFile
wire enable_rob_to_reg;
wire [`EX_REG_NUMBER_WIDTH] rd_rob_to_reg;
wire [`DATA_WIDTH] V_rob_to_reg;
wire [`ROB_ID_TYPE] Q_rob_to_reg;

// Memctrl
wire ok_memctrl_to_if;
wire enable_if_to_memctrl;
wire [`ADDR_WIDTH] addr_if_to_memctrl;
wire [`INS_WIDTH] ins_memctrl_to_if;

wire enable_lsb_to_memctrl;
wire read_or_write_lsb_to_memctrl;
wire [2:0] width_lsb_to_memctrl;
wire [`ADDR_WIDTH] addr_lsb_to_memctrl;
wire [`DATA_WIDTH] data_memctrl_to_lsb;
wire [`DATA_WIDTH] data_lsb_to_memctrl;
wire ok_memctrl_to_lsb;

// InsFetcher
wire [`ADDR_WIDTH] pc_pred_pd_to_if;
wire predict_jump_pd_to_if;
wire [`INS_WIDTH] code_if_to_pd;
wire [`ADDR_WIDTH] pc_if_to_pd;

wire enable_dsp_to_if;
wire enable_if_to_dsp;
wire predict_jump_if_to_dsp;
wire [`ADDR_WIDTH] pc_if_to_dsp;
wire [`INS_WIDTH] ins_if_to_dsp;
wire [`ADDR_WIDTH] pc_pred_if_to_dsp;

wire enable_rob_to_if;
wire [`ADDR_WIDTH] pc_next_rob_to_if;

// Predictor
wire enable_rob_to_pd;
wire if_jump_rob_to_pd;
wire [`INS_WIDTH] code_rob_to_pd;

// Dispatcher
wire [`INS_WIDTH] code_dsp_to_dc;
wire [`OPE_WIDTH] ins_type_dc_to_dsp;
wire [`EX_REG_NUMBER_WIDTH] ins_rd_dc_to_dsp, ins_rs1_dc_to_dsp, ins_rs2_dc_to_dsp;
wire [`DATA_WIDTH] ins_imm_dc_to_dsp;

wire [`DATA_WIDTH] Vj_reg_to_dsp, Vk_reg_to_dsp;
wire [`ROB_ID_TYPE] Qj_reg_to_dsp, Qk_reg_to_dsp;
wire enable_dsp_to_reg;
wire [`EX_REG_NUMBER_WIDTH] rs1_dsp_to_reg, rs2_dsp_to_reg;
wire [`EX_REG_NUMBER_WIDTH] rd_dsp_to_reg;
wire [`ROB_ID_TYPE] rob_id_dsp_to_reg;
wire [`DATA_WIDTH] Vj_rob_to_dsp, Vk_rob_to_dsp;
wire Qj_ready_rob_to_dsp, Qk_ready_rob_to_dsp;
wire [`ROB_ID_TYPE] Qj_dsp_to_rob, Qk_dsp_to_rob;

wire enable_dsp_to_rs;
wire [`DATA_WIDTH] Vj_dsp_to_rs, Vk_dsp_to_rs;
wire [`ROB_ID_TYPE] Qj_dsp_to_rs, Qk_dsp_to_rs;
wire [`OPE_WIDTH] type_dsp_to_rs;
wire [`EX_REG_NUMBER_WIDTH] rd_dsp_to_rs, rs1_dsp_to_rs, rs2_dsp_to_rs;
wire [`DATA_WIDTH] imm_dsp_to_rs;
wire [`ADDR_WIDTH] pc_dsp_to_rs;
wire [`ROB_ID_TYPE] rob_id_dsp_to_rs;

wire enable_dsp_to_lsb;
wire [`DATA_WIDTH] Vj_dsp_to_lsb, Vk_dsp_to_lsb;
wire [`ROB_ID_TYPE] Qj_dsp_to_lsb, Qk_dsp_to_lsb;
wire [`OPE_WIDTH] type_dsp_to_lsb;
wire [`EX_REG_NUMBER_WIDTH] rd_dsp_to_lsb, rs1_dsp_to_lsb, rs2_dsp_to_lsb;
wire [`DATA_WIDTH] imm_dsp_to_lsb;
wire [`ADDR_WIDTH] pc_dsp_to_lsb;
wire [`ROB_ID_TYPE] rob_id_dsp_to_lsb;

wire [`ROB_ID_TYPE] rob_id_rob_to_dsp;
wire enable_dsp_to_rob;
wire predict_jump_dsp_to_rob;
wire [`ADDR_WIDTH] pc_dsp_to_rob;
wire [`OPE_WIDTH] type_dsp_to_rob;
wire [`EX_REG_NUMBER_WIDTH] rd_dsp_to_rob;
wire [`INS_WIDTH] code_dsp_to_rob;

// cdb
wire enable_cdb_rs;
wire [`ROB_ID_TYPE] cdb_rs_rob_id;
wire [`DATA_WIDTH] cdb_rs_value;
wire enable_cdb_lsb;
wire [`ROB_ID_TYPE] cdb_lsb_rob_id;
wire [`DATA_WIDTH] cdb_lsb_value;
wire cdb_rs_jump;
wire [`ADDR_WIDTH] cdb_rs_pc_next;

// LSB
wire commit_signal_rob_to_lsb;
wire [`ROB_ID_TYPE] commited_rob_to_lsb;

// ROB
wire mispredict;

RegFile regfile(
   .clk(clk_in),
   .rst(rst_in),
   .rdy(rdy_in),
 
   .enable_from_dsp(enable_dsp_to_reg),
   .rs1_from_dsp(rs1_dsp_to_reg),
   .rs2_from_dsp(rs2_dsp_to_reg),
   .rd_from_dsp(rd_dsp_to_reg),
   .rob_id_from_dsp(rob_id_dsp_to_reg),
   .Vj_to_dsp(Vj_reg_to_dsp),
   .Vk_to_dsp(Vk_reg_to_dsp),
   .Qj_to_dsp(Qj_reg_to_dsp),
   .Qk_to_dsp(Qk_reg_to_dsp),
 
   .mispredict(mispredict),
   .enable_from_rob(enable_rob_to_reg),
   .rd_from_rob(rd_rob_to_reg),
   .Q_from_rob(Q_rob_to_reg),
   .V_from_rob(V_rob_to_reg)
);

Memctrl memctrl(
   .clk(clk_in),
   .rst(rst_in),
   .rdy(rdy_in),

   .data_from_ram(mem_din),
   .uart_full_signal(io_buffer_full),
   .signal_to_ram(mem_wr),
   .data_to_ram(mem_dout),
   .addr_to_ram(mem_a),

   .enable_from_if(enable_if_to_memctrl),
   .addr_from_if(addr_if_to_memctrl),
   .enable_to_if(ok_memctrl_to_if),
   .ins_to_if(ins_memctrl_to_if),

   .enable_from_lsb(enable_lsb_to_memctrl),
   .read_or_write(read_or_write_lsb_to_memctrl),
   .width_from_lsb(width_lsb_to_memctrl),
   .addr_from_lsb(addr_lsb_to_memctrl),
   .data_from_lsb(data_lsb_to_memctrl),
   .data_to_lsb(data_memctrl_to_lsb),
   .ok_to_lsb(ok_memctrl_to_lsb)
);

InsFetcher insfetcher(
   .clk(clk_in),
   .rst(rst_in),
   .rdy(rdy_in),

   .pc_pred_from_predictor(pc_pred_pd_to_if),
   .predict_jump_from_predictor(predict_jump_pd_to_if),
   .code_to_predictor(code_if_to_pd),
   .pc_to_predictor(pc_if_to_pd),

   .ok_from_memctrl(ok_memctrl_to_if),
   .ins_from_memctrl(ins_memctrl_to_if),
   .enable_to_memctrl(enable_if_to_memctrl),
   .addr_to_memctrl(addr_if_to_memctrl),

   .enable_from_dispatcher(enable_dsp_to_if),
   .enable_to_dispatcher(enable_if_to_dsp),
   .predict_jump_to_dispatcher(predict_jump_if_to_dsp),
   .pc_to_dispatcher(pc_if_to_dsp),
   .ins_to_dispatcher(ins_if_to_dsp),
   .pc_pred_to_dispatcher(pc_pred_if_to_dsp),

   .enable_from_rob(enable_rob_to_if),
   .mispredict(mispredict),
   .pc_next(pc_next_rob_to_if)
);

Predictor predictor(
   .clk(clk_in),
   .rst(rst_in),
   .rdy(rdy_in),

   .pc_cur(pc_if_to_pd),
   .ins_cur(code_if_to_pd),
   .pc_pred(pc_pred_pd_to_if),
   .predict_jump_to_dispatcher(predict_jump_pd_to_if),

   .enable_from_rob(enable_rob_to_if),
   .if_jump(if_jump_rob_to_pd),
   .code(code_rob_to_pd)
);

Dispatcher dispatchar(
   .clk(clk_in),
   .rst(rst_in),
   .rdy(rdy_in),

   // if
   .enable_from_if(enable_if_to_dsp),
   .predict_jump_from_if(predict_jump_if_to_dsp),
   .pc_from_if(pc_if_to_dsp),
   .ins_from_if(ins_if_to_dsp),
   .pred_pc_from_if(pc_pred_if_to_dsp),
   .enable_to_if(enable_dsp_to_if),

   // decoder
   .code_to_decoder(code_dsp_to_dc),
   .ins_type(ins_type_dc_to_dsp),
   .ins_rd(ins_rd_dc_to_dsp),
   .ins_rs1(ins_rs1_dc_to_dsp),
   .ins_rs2(ins_rs2_dc_to_dsp),
   .ins_imm(ins_imm_dc_to_dsp),

   // interact with reg & rob to get Vj, Vk, Qj, Qk
   .Vj_from_reg(Vj_reg_to_dsp),
   .Vk_from_reg(Vk_reg_to_dsp),
   .Qj_from_reg(Qj_reg_to_dsp),
   .Qk_from_reg(Qk_reg_to_dsp),
   .enable_to_reg(enable_dsp_to_reg),
   .rs1_to_reg(rs1_dsp_to_reg),
   .rs2_to_reg(rs2_dsp_to_reg),
   .rd_to_reg(rd_dsp_to_reg),
   .rob_id_to_reg(rob_id_dsp_to_reg),
   .Vj_from_rob(Vj_rob_to_dsp),
   .Vk_from_rob(Vk_rob_to_dsp),
   .Qj_ready_from_rob(Qj_ready_rob_to_dsp),
   .Qk_ready_from_rob(Qk_ready_rob_to_dsp),
   .Qj_to_rob(Qj_dsp_to_rob),
   .Qk_to_rob(Qk_dsp_to_rob),

   // rs
   .enable_to_rs(enable_dsp_to_rs),
   .Vj_to_rs(Vj_dsp_to_rs),
   .Vk_to_rs(Vk_dsp_to_rs),
   .Qj_to_rs(Qj_dsp_to_rs),
   .Qk_to_rs(Qk_dsp_to_rs),
   .type_to_rs(type_dsp_to_rs),
   .pc_to_rs(pc_dsp_to_rs),
   .imm_to_rs(imm_dsp_to_rs),
   .rob_id_to_rs(rob_id_dsp_to_rs),

   // lsb
   .enable_to_lsb(enable_dsp_to_lsb),
   .Vj_to_lsb(Vj_dsp_to_lsb),
   .Vk_to_lsb(Vk_dsp_to_lsb),
   .Qj_to_lsb(Qj_dsp_to_lsb),
   .Qk_to_lsb(Qk_dsp_to_lsb),
   .type_to_lsb(type_dsp_to_lsb),
   .rob_id_to_lsb(rob_id_dsp_to_lsb),
   .imm_to_lsb(imm_dsp_to_lsb),

   // rob
   .mispredict(mispredict),
   .rob_id(rob_id_rob_to_dsp),
   .enable_to_rob(enable_dsp_to_rob),
   .predict_jump_to_rob(predict_jump_dsp_to_rob),
   .pc_to_rob(pc_dsp_to_rob),
   .type_to_rob(type_dsp_to_rob),
   .rd_to_rob(rd_dsp_to_rob),
   .code_to_rob(code_dsp_to_rob),

   // cdb
   .enable_cdb_rs(enable_cdb_rs),
   .cdb_rs_rob_id(cdb_rs_rob_id),
   .cdb_rs_value(cdb_rs_value),
   .enable_cdb_lsb(enable_cdb_lsb),
   .cdb_lsb_rob_id(cdb_lsb_rob_id),
   .cdb_lsb_value(cdb_lsb_value),

   // global
   .full_any_component(full_any_component)
);

Decoder decoder(
   .code(code_dsp_to_dc),
   .ins_type(ins_type_dc_to_dsp),
   .ins_rd(ins_rd_dc_to_dsp),
   .ins_rs1(ins_rs1_dc_to_dsp),
   .ins_rs2(ins_rs2_dc_to_dsp),
   .ins_imm(ins_imm_dc_to_dsp)
);

RS rs(
   .clk(clk_in),
   .rst(rst_in),
   .rdy(rdy_in),

   .enable_from_dsp(enable_dsp_to_rs),
   .Vj_from_dsp(Vj_dsp_to_rs),
   .Vk_from_dsp(Vk_dsp_to_rs),
   .Qj_from_dsp(Qj_dsp_to_rs),
   .Qk_from_dsp(Qk_dsp_to_rs),
   .type_from_dsp(type_dsp_to_rs),
   .imm_from_dsp(imm_dsp_to_rs),
   .pc_from_dsp(pc_dsp_to_rs),
   .rob_id_from_dsp(rob_id_dsp_to_rs),

   .enable_cdb_rs(enable_cdb_rs),
   .cdb_rs_rob_id(cdb_rs_rob_id),
   .cdb_rs_value(cdb_rs_value),
   .enable_cdb_lsb(enable_cdb_lsb),
   .cdb_lsb_rob_id(cdb_lsb_rob_id),
   .cdb_lsb_value(cdb_lsb_value),
   .cdb_rs_jump(cdb_rs_jump),
   .cdb_rs_pc_next(cdb_rs_pc_next),

   .mispredict(mispredict),

   .full_rs(full_rs)
);

LSB lsb(
   .clk(clk_in),
   .rst(rst_in),
   .rdy(rdy_in),

   .enable_from_dsp(enable_dsp_to_lsb),
   .Vj_from_dsp(Vj_dsp_to_lsb),
   .Vk_from_dsp(Vk_dsp_to_lsb),
   .Qj_from_dsp(Qj_dsp_to_lsb),
   .Qk_from_dsp(Qk_dsp_to_lsb),
   .type_from_dsp(type_dsp_to_lsb),
   .rob_id_from_dsp(rob_id_dsp_to_rs),
   .imm_from_dsp(imm_dsp_to_lsb),

   .ok_from_memctrl(ok_memctrl_to_lsb),
   .data_from_memctrl(data_memctrl_to_lsb),
   .enable_to_memctrl(enable_lsb_to_memctrl),
   .read_or_write_to_memctrl(read_or_write_lsb_to_memctrl),
   .addr_to_memctrl(addr_lsb_to_memctrl),
   .data_to_memctrl(data_lsb_to_memctrl),
   .width_to_memctrl(width_lsb_to_memctrl),

   .enable_cdb_rs(enable_cdb_rs),
   .cdb_rs_rob_id(cdb_rs_rob_id),
   .cdb_rs_value(cdb_rs_value),
   .enable_cdb_lsb(enable_cdb_lsb),
   .cdb_lsb_rob_id(cdb_lsb_rob_id),
   .cdb_lsb_value(cdb_lsb_value),

   .mispredict(mispredict),
   .commit_signal(commit_signal_rob_to_lsb),
   .committed_from_rob(commited_rob_to_lsb),

   .full_lsb(full_lsb)
);

ROB rob(
   .clk(clk_in),
   .rst(rst_in),
   .rdy(rdy_in),

   .enable_to_if(enable_rob_to_if),
   .pc_next_to_if(pc_next_rob_to_if),

   .Vj_to_dsp(Vj_rob_to_dsp),
   .Vk_to_dsp(Vk_rob_to_dsp),
   .Qj_ready_to_dsp(Qj_ready_rob_to_dsp),
   .Qk_ready_to_dsp(Qk_ready_rob_to_dsp),
   .Qj_from_dsp(Qj_dsp_to_rob),
   .Qk_from_dsp(Qk_dsp_to_rob),  
   .rob_id_to_dsp(rob_id_rob_to_dsp),
   .enable_from_dsp(enable_dsp_to_rob),
   .predict_jump_from_dsp(predict_jump_dsp_to_rob),
   .pc_from_dsp(pc_dsp_to_rob),
   .type_from_dsp(type_dsp_to_rob),
   .rd_from_dsp(rd_dsp_to_rob),
   .code_from_dsp(code_dsp_to_rob),

   .enable_to_predictor(enable_rob_to_pd),
   .if_jump_to_predictor(if_jump_rob_to_pd),
   .code_to_predictor(code_rob_to_pd),

   .commit_signal(commit_signal_rob_to_lsb),
   .committed_from_rob(commited_rob_to_lsb),

   .enable_cdb_rs(enable_cdb_rs),
   .cdb_rs_rob_id(cdb_rs_rob_id),
   .cdb_rs_value(cdb_rs_value),
   .enable_cdb_lsb(enable_cdb_lsb),
   .cdb_lsb_rob_id(cdb_lsb_rob_id),
   .cdb_lsb_value(cdb_lsb_value),
   .cdb_rs_jump(cdb_rs_jump),
   .cdb_rs_pc_next(cdb_rs_pc_next),

   .enable_to_reg(enable_rob_to_reg),
   .rd_to_reg(rd_rob_to_reg),
   .V_to_reg(V_rob_to_reg),
   .Q_to_reg(Q_rob_to_reg),

   .mispredict(mispredict),

   .full_rob(full_rob)
);

endmodule