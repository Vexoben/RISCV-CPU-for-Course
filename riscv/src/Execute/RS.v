`include "define.v"

module RS(
   // control signal
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with Dispatcher
   input wire enable_from_dsp,
   input wire [`ADDR_WIDTH] pc_from_dsp,
   input wire [`DATA_WIDTH] Vj_from_dsp, Vk_from_dsp,
   input wire [`ROB_ID_TYPE] Qj_from_dsp, Qk_from_dsp, rob_id_from_dsp,
   input wire [`OPE_WIDTH] type_from_dsp,
   input wire [`DATA_WIDTH] imm_from_dsp,

   // interact with cdb
   input wire enable_cdb_lsb,
   input wire [`ROB_ID_TYPE] cdb_lsb_rob_id,
   input wire [`DATA_WIDTH] cdb_lsb_value,
   output reg enable_cdb_rs,
   output reg [`ROB_ID_TYPE] cdb_rs_rob_id,
   output reg [`DATA_WIDTH] cdb_rs_value,
   output reg cdb_rs_jump,
   output reg [`ADDR_WIDTH ] cdb_rs_pc_next,
   
   // interact with rob
   input wire mispredict,

   // global
   output wire full_rs
);

reg [`DATA_WIDTH] Vj[`RS_SIZE_ARR], Vk[`RS_SIZE_ARR];
reg [`ROB_ID_TYPE] Qj[`RS_SIZE_ARR], Qk[`RS_SIZE_ARR], rob_id[`RS_SIZE_ARR];
reg [`OPE_WIDTH] type[`RS_SIZE_ARR];
reg [`DATA_WIDTH] imm[`RS_SIZE_ARR];
reg [`ADDR_WIDTH] pc[`RS_SIZE_ARR];
reg [`RS_SIZE_ARR] busy;
wire [`RS_SIZE_ARR] ready_Q;
wire [`RS_ID_TYPE] free, ready;
wire [`RS_ID_TYPE] size;

// -------- debug wire ---------

wire [`OPE_WIDTH] type0 = type[0];
wire [`OPE_WIDTH] type1 = type[1];
wire [`OPE_WIDTH] type2 = type[2];
wire [`OPE_WIDTH] type3 = type[3];
wire [`ADDR_WIDTH] pc0 = pc[0];
wire [`ADDR_WIDTH] pc1 = pc[1];
wire [`ADDR_WIDTH] pc2 = pc[2];
wire [`ADDR_WIDTH] pc3 = pc[3];

// -----------------------------

wire [`DATA_WIDTH] real_Vj, real_Vk;
wire [`ROB_ID_TYPE] real_Qj, real_Qk;

assign real_Qj = (enable_cdb_rs && cdb_rs_rob_id == Qj_from_dsp) ? `NON_DEPENDENT : (enable_cdb_lsb && cdb_lsb_rob_id == Qj_from_dsp) ? `NON_DEPENDENT : Qj_from_dsp;
assign real_Qk = (enable_cdb_rs && cdb_rs_rob_id == Qk_from_dsp) ? `NON_DEPENDENT : (enable_cdb_lsb && cdb_lsb_rob_id == Qk_from_dsp) ? `NON_DEPENDENT : Qk_from_dsp;
assign real_Vj = (enable_cdb_rs && cdb_rs_rob_id == Qj_from_dsp) ? cdb_rs_value : (enable_cdb_lsb && cdb_lsb_rob_id == Qj_from_dsp) ? cdb_lsb_value : Vj_from_dsp;
assign real_Vk = (enable_cdb_rs && cdb_rs_rob_id == Qk_from_dsp) ? cdb_rs_value : (enable_cdb_lsb && cdb_lsb_rob_id == Qk_from_dsp) ? cdb_lsb_value : Vk_from_dsp;

assign free = !busy[0] ? 0 : !busy[1] ? 1 : !busy[2] ? 2 : !busy[3] ? 3 :
              !busy[4] ? 4 : !busy[5] ? 5 : !busy[6] ? 6 : !busy[7] ? 7 :
              !busy[8] ? 8 : !busy[9] ? 9 : !busy[10] ? 10 : !busy[11] ? 11 :
              !busy[12] ? 12 : !busy[13] ? 13 : !busy[14] ? 14 : !busy[15] ? 15 : `RS_SIZE;
assign ready_Q[0] = Qj[0] == `NON_DEPENDENT && Qk[0] == `NON_DEPENDENT && busy[0];
assign ready_Q[1] = Qj[1] == `NON_DEPENDENT && Qk[1] == `NON_DEPENDENT && busy[1];
assign ready_Q[2] = Qj[2] == `NON_DEPENDENT && Qk[2] == `NON_DEPENDENT && busy[2];
assign ready_Q[3] = Qj[3] == `NON_DEPENDENT && Qk[3] == `NON_DEPENDENT && busy[3];
assign ready_Q[4] = Qj[4] == `NON_DEPENDENT && Qk[4] == `NON_DEPENDENT && busy[4];
assign ready_Q[5] = Qj[5] == `NON_DEPENDENT && Qk[5] == `NON_DEPENDENT && busy[5];
assign ready_Q[6] = Qj[6] == `NON_DEPENDENT && Qk[6] == `NON_DEPENDENT && busy[6];
assign ready_Q[7] = Qj[7] == `NON_DEPENDENT && Qk[7] == `NON_DEPENDENT && busy[7];
assign ready_Q[8] = Qj[8] == `NON_DEPENDENT && Qk[8] == `NON_DEPENDENT && busy[8];
assign ready_Q[9] = Qj[9] == `NON_DEPENDENT && Qk[9] == `NON_DEPENDENT && busy[9];
assign ready_Q[10] = Qj[10] == `NON_DEPENDENT && Qk[10] == `NON_DEPENDENT && busy[10];
assign ready_Q[11] = Qj[11] == `NON_DEPENDENT && Qk[11] == `NON_DEPENDENT && busy[11];
assign ready_Q[12] = Qj[12] == `NON_DEPENDENT && Qk[12] == `NON_DEPENDENT && busy[12];
assign ready_Q[13] = Qj[13] == `NON_DEPENDENT && Qk[13] == `NON_DEPENDENT && busy[13];
assign ready_Q[14] = Qj[14] == `NON_DEPENDENT && Qk[14] == `NON_DEPENDENT && busy[14];
assign ready_Q[15] = Qj[15] == `NON_DEPENDENT && Qk[15] == `NON_DEPENDENT && busy[15];
assign ready = ready_Q[0] ? 0 : ready_Q[1] ? 1 : ready_Q[2] ? 2 : ready_Q[3] ? 3 :
               ready_Q[4] ? 4 : ready_Q[5] ? 5 : ready_Q[6] ? 6 : ready_Q[7] ? 7 :
               ready_Q[8] ? 8 : ready_Q[9] ? 9 : ready_Q[10] ? 10 : ready_Q[11] ? 11 :
               ready_Q[12] ? 12 : ready_Q[13] ? 13 : ready_Q[14] ? 14 : ready_Q[15] ? 15 : `RS_SIZE;

assign size = busy[0] + busy[1] + busy[2] + busy[3] + busy[4] + busy[5] + busy[6] + busy[7] 
               + busy[8] + busy[9] + busy[10] + busy[11] + busy[12] + busy[13] + busy[14] + busy[15];
assign full_rs = size + 1 >= `RS_SIZE;

reg [`DATA_WIDTH] result;
reg [`ADDR_WIDTH] pc_next;
reg if_jump;

integer i;

always @(posedge clk) begin
   if (rst || mispredict) begin
      enable_cdb_rs <= 0;
      cdb_rs_rob_id <= 0;
      cdb_rs_value <= 0;
      for (i = 0; i < `RS_SIZE; i = i + 1) begin
         busy[i] <= 0;
      end
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (enable_from_dsp) begin
         Vj[free] <= real_Vj;
         Vk[free] <= real_Vk;
         Qj[free] <= real_Qj;
         Qk[free] <= real_Qk;
         type[free] <= type_from_dsp;
         imm[free] <= imm_from_dsp;
         pc[free] <= pc_from_dsp;
         busy[free] <= 1;
         rob_id[free] <= rob_id_from_dsp;
      end
      if (ready != `RS_SIZE) begin
         enable_cdb_rs <= 1;
         cdb_rs_rob_id <= rob_id[ready];
         cdb_rs_value <= result;
         cdb_rs_jump <= if_jump;
         cdb_rs_pc_next <= pc_next;
         busy[ready] <= 0;
      end
      if (enable_cdb_rs) begin
         if (ready == `RS_SIZE) enable_cdb_rs <= 0;
         for (i = 0; i < `RS_SIZE; i = i + 1) begin
            if (Qj[i] != `NON_DEPENDENT && Qj[i] == cdb_rs_rob_id) begin
               Qj[i] <= `NON_DEPENDENT;
               Vj[i] <= cdb_rs_value;
            end
            if (Qk[i] != `NON_DEPENDENT && Qk[i] == cdb_rs_rob_id) begin
               Qk[i] <= `NON_DEPENDENT;
               Vk[i] <= cdb_rs_value;
            end
         end
      end
      if (enable_cdb_lsb) begin
         for (i = 0; i < `RS_SIZE; i = i + 1) begin
            if (Qj[i] != `NON_DEPENDENT && Qj[i] == cdb_lsb_rob_id) begin
               Qj[i] <= `NON_DEPENDENT;
               Vj[i] <= cdb_lsb_value;
            end
            if (Qk[i] != `NON_DEPENDENT && Qk[i] == cdb_lsb_rob_id) begin
               Qk[i] <= `NON_DEPENDENT;
               Vk[i] <= cdb_lsb_value;
            end
         end
      end
   end
end

always @(*) begin
   result = 0;
   pc_next = ready == `RS_SIZE ? 0 : pc[ready] + 4;
   if_jump = 0;
   case (type[ready]) 
      `EMPTY_INS : begin
         result = 0;
      end
      `LUI       : begin           // Load Upper Immediate
         result = imm[ready];
      end
      `AUIPC     : begin           // Add Upper Immediate to PC
         result = pc[ready] + imm[ready];
      end
      `JAL       : begin           // Jump and Link
         if_jump = 1;
         result = pc[ready] + 4;
         pc_next = pc[ready] + imm[ready];
      end
      `JALR      : begin           // Jump and Link Register
         if_jump = 1;
         pc_next = Vj[ready] + imm[ready];
         result = pc[ready] + 4;
      end
      `BEQ       : begin           // Branch if Equal
         pc_next = pc[ready] + ((Vj[ready] == Vk[ready]) ? imm[ready] : 4);
         if_jump = Vj[ready] == Vk[ready];
      end
      `BNE       : begin           // Branch if Not Equal
         pc_next = pc[ready] + ((Vj[ready] != Vk[ready]) ? imm[ready] : 4);
         if_jump = Vj[ready] != Vk[ready];
      end
      `BLT       : begin           // Branch if Less Than
         pc_next = pc[ready] + (($signed(Vj[ready]) < $signed(Vk[ready])) ? imm[ready] : 4);
         if_jump = $signed(Vj[ready]) < $signed(Vk[ready]);        
      end
      `BGE       : begin           // Branch if Greater Than or Equal
         pc_next = pc[ready] + ($signed(Vj[ready]) >= $signed(Vk[ready]) ? imm[ready] : 4);
         if_jump = $signed(Vj[ready]) >= $signed(Vk[ready]);
      end
      `BLTU      : begin           // Branch if Less Than, Unsigned
         pc_next = pc[ready] + ((Vj[ready] < Vk[ready]) ? imm[ready] : 4);
         if_jump = Vj[ready] < Vk[ready];
      end
      `BGEU      : begin           // Branch if Greater Than or Equal, Unsigned
         pc_next = pc[ready] + ((Vj[ready] >= Vk[ready]) ? imm[ready] : 4);
         if_jump = Vj[ready] >= Vk[ready];
      end
      `ADDI      : begin           // Add Immediate
         result = Vj[ready] + imm[ready];
      end
      `SLTI      : begin           // Set if Less Than Immediate
         result = $signed(Vj[ready]) < $signed(imm[ready]);
      end
      `SLTIU     : begin           // Set if Less Than Immediate, Unsigned
         result = Vj[ready] < imm[ready];
      end
      `XORI      : begin           // Exclusive-OR Immediate
         result = Vj[ready] ^ imm[ready];
      end
      `ORI       : begin           // OR Immediate
         result = Vj[ready] | imm[ready];
      end
      `ANDI      : begin           // And Immediate
         result = Vj[ready] & imm[ready];
      end
      `SLLI      : begin           // Shift Left Logical Immediate
         result = Vj[ready] << imm[ready];
      end
      `SRLI      : begin           // Shift Right Logical Immediate
         result = Vj[ready] >> imm[ready];
      end
      `SRAI      : begin           // Shift Right Arithmetic Immediate
         result = Vj[ready] >> imm[ready];
      end
      `ADD       : begin           // 
         result = Vj[ready] + Vk[ready];
      end
      `SUB       : begin           //
         result = Vj[ready] - Vk[ready];
      end
      `SLL       : begin           // Shift Left Logical
         result = Vj[ready] << Vk[ready];
      end
      `SLT       : begin           // Set if Less Than
         result = $signed(Vj[ready]) < $signed(Vk[ready]);
      end
      `SLTU      : begin           // Set if Less Than, Unsigned
         result = Vj[ready] < Vk[ready];
      end
      `XOR       : begin           // Exclusive-OR
         result = Vj[ready] ^ Vk[ready];
      end
      `SRL       : begin           // Shift Right Logical
         result = Vj[ready] >> Vk[ready];
      end
      `SRA       : begin           // Shift Right Arithmetic
         result = Vj[ready] >> Vk[ready];
      end
      `OR        : begin           // 
         result = Vj[ready] | Vk[ready];
      end
      `AND       : begin           //
         result = Vj[ready] & Vk[ready];
      end
      default: begin
         if (ready != `RS_SIZE) $display("ERROR!!!");   
      end
   endcase
end

// debug wire

wire [`ADDR_WIDTH] Qj0 = Qj[0];
wire [`ADDR_WIDTH] Qj1 = Qj[1];
wire [`ADDR_WIDTH] Qj2 = Qj[2];
wire [`ADDR_WIDTH] Qj3 = Qj[3];
wire [`ADDR_WIDTH] Qj4 = Qj[4];
wire [`ADDR_WIDTH] Qj5 = Qj[5];
wire [`ADDR_WIDTH] Qj6 = Qj[6];
wire [`ADDR_WIDTH] Qj7 = Qj[7];
wire [`ADDR_WIDTH] Qj8 = Qj[8];
wire [`ADDR_WIDTH] Qj9 = Qj[9];
wire [`ADDR_WIDTH] Qj10 = Qj[10];
wire [`ADDR_WIDTH] Qj11 = Qj[11];
wire [`ADDR_WIDTH] Qj12 = Qj[12];
wire [`ADDR_WIDTH] Qj13 = Qj[13];
wire [`ADDR_WIDTH] Qj14 = Qj[14];
wire [`ADDR_WIDTH] Qj15 = Qj[15];

wire [`ADDR_WIDTH] Vj0 = Vj[0];
wire [`ADDR_WIDTH] Vj1 = Vj[1];
wire [`ADDR_WIDTH] Vj2 = Vj[2];
wire [`ADDR_WIDTH] Vj3 = Vj[3];
wire [`ADDR_WIDTH] Vj4 = Vj[4];
wire [`ADDR_WIDTH] Vj5 = Vj[5];
wire [`ADDR_WIDTH] Vj6 = Vj[6];
wire [`ADDR_WIDTH] Vj7 = Vj[7];
wire [`ADDR_WIDTH] Vj8 = Vj[8];
wire [`ADDR_WIDTH] Vj9 = Vj[9];
wire [`ADDR_WIDTH] Vj10 = Vj[10];
wire [`ADDR_WIDTH] Vj11 = Vj[11];
wire [`ADDR_WIDTH] Vj12 = Vj[12];
wire [`ADDR_WIDTH] Vj13 = Vj[13];
wire [`ADDR_WIDTH] Vj14 = Vj[14];
wire [`ADDR_WIDTH] Vj15 = Vj[15];

endmodule