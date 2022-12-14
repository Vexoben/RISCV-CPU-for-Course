`include "define.v"

module Dispatcher(
   // control signal
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with instruction fetcher
   input enable_from_if,
   input predict_jump_from_if,
   input [`ADDR_WIDTH] pc_from_if,
   input [`INS_WIDTH] ins_from_if,
   input [`ADDR_WIDTH] pred_pc_from_if,
   output reg enable_to_if,

   // interact with decoder                           // combinational circuit
   output wire [`INS_WIDTH] code_to_decoder,
   output wire [`ADDR_WIDTH] pc_to_decoder,
   input wire [`OPE_WIDTH] ins_type,
   input wire [`EX_REG_NUMBER_WIDTH] ins_rd, ins_rs1, ins_rs2,  // reg destination, reg source1, reg source2
   input wire [`DATA_WIDTH] ins_imm,

   // interact with reg & rob to get Vj, Vk, Qj, Qk
   input wire [`DATA_WIDTH] Vj_from_reg, Vk_from_reg,
   input wire [`ROB_ID_TYPE] Qj_from_reg, Qk_from_reg,
   output reg enable_to_reg,
   output wire [`EX_REG_NUMBER_WIDTH] rs1_to_reg, rs2_to_reg,
   output reg [`EX_REG_NUMBER_WIDTH] rd_to_reg,
   output reg [`ROB_ID_TYPE] rob_id_to_reg, // renaming
   input wire [`DATA_WIDTH] Vj_from_rob, Vk_from_rob,
   input wire Qj_ready_from_rob, Qk_ready_from_rob,
   output wire [`ROB_ID_TYPE] Qj_to_rob, Qk_to_rob,

   // interact with RS 
   output reg enable_to_rs, 
   output reg [`DATA_WIDTH] Vj_to_rs, Vk_to_rs,
   output reg [`ROB_ID_TYPE] Qj_to_rs, Qk_to_rs,
   output reg [`OPE_WIDTH] type_to_rs,
   output reg [`DATA_WIDTH] imm_to_rs,
   output reg [`ROB_ID_TYPE] rob_id_to_rs,
   output reg [`ADDR_WIDTH] pc_to_rs,

   // interact with LSB
   output reg enable_to_lsb,
   output reg [`DATA_WIDTH] Vj_to_lsb, Vk_to_lsb,
   output reg [`ROB_ID_TYPE] Qj_to_lsb, Qk_to_lsb,
   output reg [`OPE_WIDTH] type_to_lsb,
   output reg [`ROB_ID_TYPE] rob_id_to_lsb,
   output reg [`DATA_WIDTH] imm_to_lsb,

   // interact with ROB
   input wire mispredict,
   input wire [`ROB_ID_TYPE] rob_id,   
   output reg enable_to_rob,
   output reg predict_jump_to_rob,
   output reg [`ADDR_WIDTH] pc_to_rob,
   output reg [`OPE_WIDTH] type_to_rob,
   output reg [`ADDR_WIDTH] pred_pc_to_rob,
   output reg [`EX_REG_NUMBER_WIDTH] rd_to_rob,
   output reg [`INS_WIDTH] code_to_rob,

   // interact with cdb
   input wire enable_cdb_rs,
   input wire [`ROB_ID_TYPE] cdb_rs_rob_id,
   input wire [`DATA_WIDTH] cdb_rs_value,
   input wire enable_cdb_lsb,
   input wire [`ROB_ID_TYPE] cdb_lsb_rob_id,
   input wire [`DATA_WIDTH] cdb_lsb_value,

   // global
   input wire full_any_component            // lsb, rs or rob is full
);

wire is_load, is_store, is_branch, maybe_change_reg;

assign is_load = ins_type == `LH || ins_type == `LB || ins_type == `LW || ins_type == `LBU || ins_type == `LHU;
assign is_store = ins_type == `SB || ins_type == `SH || ins_type == `SW;
assign is_branch = ins_type == `BEQ || ins_type == `BNE || ins_type == `BLT || ins_type == `BGE || ins_type == `BLTU || ins_type == `BGEU;
assign maybe_change_reg = !is_store && !is_branch;

reg [`ROB_ID_TYPE] Qj, Qk;
reg [`DATA_WIDTH] Vj, Vk;

always @(*) begin
   if (Qj_from_reg != `NON_DEPENDENT && !Qj_ready_from_rob && (!enable_cdb_lsb || cdb_lsb_rob_id != Qj_from_reg) && (!enable_cdb_rs || cdb_rs_rob_id != Qj_from_reg)) begin
         Qj = Qj_from_reg;
   end
   else Qj = `NON_DEPENDENT;
   if (Qk_from_reg != `NON_DEPENDENT && !Qk_ready_from_rob && (!enable_cdb_lsb || cdb_lsb_rob_id != Qk_from_reg) && (!enable_cdb_rs || cdb_rs_rob_id != Qk_from_reg)) begin
         Qk = Qk_from_reg;
   end
   else Qk = `NON_DEPENDENT;

   if (Qj_from_reg == `NON_DEPENDENT) Vj = Vj_from_reg;
   else if (enable_cdb_lsb && cdb_lsb_rob_id == Qj_from_reg) Vj = cdb_lsb_value;
   else if (enable_cdb_rs && cdb_rs_rob_id == Qj_from_reg) Vj = cdb_rs_value;
   else if (Qj_ready_from_rob) Vj = Vj_from_rob;
   else Vj = 0;
   if (Qk_from_reg == `NON_DEPENDENT) Vk = Vk_from_reg;
   else if (enable_cdb_lsb && cdb_lsb_rob_id == Qk_from_reg) Vk = cdb_lsb_value;
   else if (enable_cdb_rs && cdb_rs_rob_id == Qk_from_reg) Vk = cdb_rs_value;
   else if (Qk_ready_from_rob) Vk = Vk_from_rob;
   else Vk = 0;
end

assign Qj_to_rob = Qj_from_reg;
assign Qk_to_rob = Qk_from_reg;
assign rs1_to_reg = ins_rs1;
assign rs2_to_reg = ins_rs2;
assign code_to_decoder = ins_from_if;
assign pc_to_decoder = pc_from_if;

parameter
STALL = 0,
RECIEVE_FROM_IF = 1;

reg[2:0] work_statu;

always @(posedge clk) begin
   if (rst || mispredict) begin
      work_statu <= 0;
      enable_to_if <= 0;
      enable_to_rs <= 0;
      enable_to_lsb <= 0;
      enable_to_rob <= 0;
      enable_to_reg <= 0;
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (work_statu == STALL) begin
         if (!full_any_component) begin
            work_statu <= RECIEVE_FROM_IF;   
            enable_to_if <= 1;
         end
         else enable_to_if <= 0;
         enable_to_rs <= 0;
         enable_to_lsb <= 0;
         enable_to_rob <= 0;
         enable_to_reg <= 0;
      end
      else if (work_statu == RECIEVE_FROM_IF) begin
         if (enable_from_if) begin
            // if
            enable_to_if <= 0;
            if (ins_type == `EMPTY_INS) begin
               enable_to_rob <= 0;
               enable_to_reg <= 0;
               enable_to_rs <= 0;
               enable_to_lsb <= 0;
               work_statu <= STALL;
            end
            else begin
               // rob
               enable_to_rob <= 1;
               predict_jump_to_rob <= predict_jump_from_if;
               pred_pc_to_rob <= pred_pc_from_if;
               rd_to_rob <= ins_rd;
               type_to_rob <= ins_type;
               code_to_rob <= ins_from_if;
               pc_to_rob <= pc_from_if;
               // reg
               enable_to_reg <= maybe_change_reg;
               rd_to_reg <= ins_rd;
               rob_id_to_reg <= rob_id;
               // rs
               Vj_to_rs <= Vj;
               Vk_to_rs <= Vk;
               Qj_to_rs <= Qj;
               Qk_to_rs <= Qk;
               type_to_rs <= ins_type;
               imm_to_rs <= ins_imm;
               rob_id_to_rs <= rob_id;
               pc_to_rs <= pc_from_if;
               // lsb
               Vj_to_lsb <= Vj;
               Vk_to_lsb <= Vk;
               Qj_to_lsb <= Qj;
               Qk_to_lsb <= Qk;
               type_to_lsb <= ins_type;
               imm_to_lsb <= ins_imm;
               rob_id_to_lsb <= rob_id;

               if (is_load || is_store) begin
                  enable_to_rs <= 0;
                  enable_to_lsb <= 1;
                  work_statu <= STALL;
               end
               else begin
                  enable_to_rs <= 1;
                  enable_to_lsb <= 0;
                  work_statu <= STALL;
               end
            end
         end
      end
   end
end
endmodule