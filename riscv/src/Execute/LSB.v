`include "define.v"

module LSB(
   // control signal
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with Dispatcher
   input wire enable_from_dsp,
   input wire [`ADDR_WIDTH] pc_from_dsp,
   input wire [`DATA_WIDTH] Vj_from_dsp, Vk_from_dsp,
   input wire [`ROB_SIZE_ARR] Qj_from_dsp, Qk_from_dsp,
   input wire [`OPE_WIDTH] type_from_dsp,
   input wire [`REG_NUMBER_WIDTH] rd_from_dsp, rs1_from_dsp, rs2_from_dsp,
   input wire [`DATA_WIDTH] imm_from_dsp,

   // interact with cdb
   output reg enable_cdb_lsb,
   output reg [`ROB_SIZE_ARR] cdb_lsb_rob_id,
   output reg [`DATA_WIDTH] cdb_lsb_value,
   input wire enable_cdb_rs,
   input wire [`ROB_SIZE_ARR] cdb_rs_rob_id,
   input wire [`DATA_WIDTH] cdb_rs_value,
   
   // interact with rob
   input wire mispredict,

   // global
   output reg full_lsb
);

reg [`LSB_ID_TYPE] head, tail;

reg [`DATA_WIDTH] Vj, Vk[`LSB_SIZE_ARR];
reg [`ROB_SIZE_ARR] Qj[`LSB_SIZE_ARR], Qk[`LSB_SIZE_ARR], rob_id[`LSB_SIZE_ARR];
reg [`OPE_WIDTH] type[`LSB_SIZE_ARR];
reg [`DATA_WIDTH] imm[`LSB_SIZE_ARR];
reg [`ADDR_WIDTH] pc[`LSB_SIZE_ARR];
reg [`LSB_ID_TYPE] busy;
wire [`LSB_ID_TYPE] ready_Q;
wire [`LSB_ID_TYPE] ready;

wire [`DATA_WIDTH] real_Vj, real_Vk;
wire [`ROB_SIZE_ARR] real_Qj, real_Qk;

assign real_Qj = (enable_cdb_rs && cdb_rs_rob_id == Qj_from_dsp) ? `NON_DEPENDENT : (enable_cdb_lsb && cdb_lsb_rob_id == Qj_from_dsp) ? `NON_DEPENDENT : Qj_from_dsp;
assign real_Qk = (enable_cdb_rs && cdb_rs_rob_id == Qk_from_dsp) ? `NON_DEPENDENT : (enable_cdb_lsb && cdb_lsb_rob_id == Qk_from_dsp) ? `NON_DEPENDENT : Qk_from_dsp;
assign real_Vj = (enable_cdb_rs && cdb_rs_rob_id == Qj_from_dsp) ? cdb_rs_value : (enable_cdb_lsb && cdb_lsb_rob_id == Qj_from_dsp) ? cdb_lsb_value : Vj_from_dsp;
assign real_Vk = (enable_cdb_rs && cdb_rs_rob_id == Qk_from_dsp) ? cdb_rs_value : (enable_cdb_lsb && cdb_lsb_rob_id == Qk_from_dsp) ? cdb_lsb_value : Vk_from_dsp;

always @(posedge clk) begin
   if (rst) begin
      enable_cdb_lsb <= 0;
      cdb_lsb_rob_id <= 0;
      cdb_lsb_value <= 0;
      full_lsb <= 0;
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      
   end
end

endmodule

