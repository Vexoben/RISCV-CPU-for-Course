`include "define.v"

module ROB(
   // control signal
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with Instruction Fetcher
   output reg enable_to_if,
   output reg [`ADDR_WIDTH] pc_next_to_if,

   // interact with Dispatcher
   input wire enable_from_dsp,
   input wire predict_jump_from_dsp,
   input wire [`ADDR_WIDTH] pc_from_dsp,
   input wire [`ADDR_WIDTH] pred_pc_from_dsp,
   input wire [`EX_REG_NUMBER_WIDTH] rd_from_dsp,
   input wire [`OPE_WIDTH] type_from_dsp,
   input wire [`INS_WIDTH] code_from_dsp,
   output wire [`ROB_ID_TYPE] rob_id_to_dsp,
   input wire [`ROB_ID_TYPE] Qj_from_dsp, Qk_from_dsp,
   output wire [`DATA_WIDTH] Vj_to_dsp, Vk_to_dsp,
   output wire Qj_ready_to_dsp, Qk_ready_to_dsp,

   // interact with predictor
   output reg enable_to_predictor,
   output reg if_jump_to_predictor,
   output reg [`INS_WIDTH] code_to_predictor,

   // interact with LSB
   output reg commit_signal,
   output reg [`ROB_ID_TYPE] committed_from_rob,

   // interact with cdb
   input wire enable_cdb_lsb,
   input wire [`ROB_ID_TYPE] cdb_lsb_rob_id,
   input wire [`DATA_WIDTH] cdb_lsb_value,
   input wire enable_cdb_rs,
   input wire [`ROB_ID_TYPE] cdb_rs_rob_id,
   input wire [`DATA_WIDTH] cdb_rs_value,
   input wire cdb_rs_jump,
   input wire [`ADDR_WIDTH] cdb_rs_pc_next,

   // interact with regFile
   output reg enable_to_reg,
   output reg [`EX_REG_NUMBER_WIDTH] rd_to_reg,
   output reg [`DATA_WIDTH] V_to_reg,
   output reg [`ROB_ID_TYPE] Q_to_reg,

   // to stall CPU when mispredict
   output reg mispredict,

   // to global 
   output wire full_rob
);

reg [`INS_WIDTH] code[`ROB_SIZE_ARR];
reg [`OPE_WIDTH] type[`ROB_SIZE_ARR];
reg [`ADDR_WIDTH] pc[`ROB_SIZE_ARR], pred_pc[`ROB_SIZE_ARR], pc_next[`ROB_SIZE_ARR];
reg [`EX_REG_NUMBER_WIDTH] rd[`REG_SIZE_ARR];
reg [`ROB_SIZE_ARR] predict_jump, actu_jump;
reg [`ROB_SIZE_ARR] busy, ready;
reg [`DATA_WIDTH] result[`ROB_SIZE_ARR];

reg [`ROB_ID_TYPE] head, tail, size;
reg push, pop;

assign rob_id_to_dsp = tail;
assign Vj_to_dsp = Qj_from_dsp != `NON_DEPENDENT ? result[Qj_from_dsp] : 0;
assign Vk_to_dsp = Qk_from_dsp != `NON_DEPENDENT ? result[Qk_from_dsp] : 0;
assign Qj_ready_to_dsp = Qj_from_dsp != `NON_DEPENDENT ? ready[Qj_from_dsp] : 1;
assign Qk_ready_to_dsp = Qk_from_dsp != `NON_DEPENDENT ? ready[Qk_from_dsp] : 1;
assign full_rob = size + 1 >= `ROB_SIZE;

wire head_is_load = busy[head] && (type[head] == `LB || type[head] == `LH || type[head] == `LBU || type[head] == `LHU || type[head] == `LW);
wire head_is_store = busy[head] && (type[head] == `SB || type[head] == `SH || type[head] == `SW);
wire head_is_branch = busy[head] && (type[head] == `BEQ || type[head] == `BNE || type[head] == `BLT || type[head] == `BGE || type[head] == `BLTU || type[head] == `BGEU);
wire head_maybe_change_reg = busy[head] && (!head_is_branch && !head_is_store);
wire head_is_jump = busy[head] && (head_is_branch || type[head] == `JAL || type[head] == `JALR);

integer i;

always @(posedge clk) begin
   // $display(head);
   // $display(tail);
   // $display(head_maybe_change_reg);
   if (rst || mispredict) begin // clear all
      head <= 0;
      tail <= 0;
      size <= 0;
      push <= 0;
      pop <= 0;
      mispredict <= 0;
      enable_to_if <= 0;
      pc_next_to_if <= 0;
      predict_jump <= 0;
      actu_jump <= 0;
      enable_to_predictor <= 0;
      enable_to_reg <= 0;
      commit_signal <= 0;
      for (i = 0; i < `ROB_SIZE; i = i + 1) begin
         type[i] <= 0;
         pc[i] <= 0; pred_pc[i] <= 0; pc_next[i] <= 0;
         rd[i] <= 0; 
         busy[i] <= 0; ready[i] <= 0;
         result[i] <= 0;
      end
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (enable_from_dsp) begin
         push <= 1;
         tail <= tail == (`ROB_SIZE - 1) ? 0 : tail + 1;
         busy[tail] <= 1;
         ready[tail] <= 0;
         type[tail] <= type_from_dsp;
         pc[tail] <= pc_from_dsp;
         pred_pc[tail] <= pred_pc_from_dsp;
         rd[tail] <= rd_from_dsp;
         code[tail] <= code_from_dsp;
         predict_jump[tail] <= predict_jump_from_dsp;
         actu_jump[tail] <= 0;
         result[tail] <= 0;
      end
      else push <= 0;
      if (enable_cdb_lsb && busy[cdb_lsb_rob_id]) begin
         ready[cdb_lsb_rob_id] <= 1;
         result[cdb_lsb_rob_id] <= cdb_lsb_value;
      end
      if (enable_cdb_rs && busy[cdb_rs_rob_id]) begin
         ready[cdb_rs_rob_id] <= 1;
         result[cdb_rs_rob_id] <= cdb_rs_value;
         actu_jump[cdb_rs_rob_id] <= cdb_rs_jump;
         pc_next[cdb_rs_rob_id] <= cdb_rs_pc_next;
      end
      if (ready[head] || head_is_store) begin   // commit
         head <= head == (`ROB_SIZE - 1) ? 0 : head + 1;
         pop <= 1;
         enable_to_reg <= head_maybe_change_reg;
         rd_to_reg <= rd[head];
         V_to_reg <= result[head];
         Q_to_reg <= head;
         ready[head] <= 0;
         busy[head] <= 0;
         enable_to_if <= 1;
         if (head_is_store || head_is_load) begin
            pc_next_to_if <= pc[head] + 4;
         end
         else pc_next_to_if <= pc_next[head];
         if (head_is_jump) begin
            // train predictor
            enable_to_predictor <= 1;
            if_jump_to_predictor <= actu_jump[head];
            code_to_predictor <= code[head];

            // mispredict
            if (predict_jump[head] != actu_jump[head]) begin
               mispredict <= 1;
            end
         end
         else begin
            enable_to_predictor <= 0;
         end
         if (head_is_store) begin
            commit_signal <= 1;
            committed_from_rob <= head;
         end
         else commit_signal <= 0;
      end
      else begin
         pop <= 0;
         enable_to_reg <= 0;
         enable_to_if <= 0;
         enable_to_predictor <= 0;
         commit_signal <= 0;
      end

      size <= size + push - pop;

   end
end

// --------- debug wire  ----------
// array can't be supervised in GTKwave
wire [`ADDR_WIDTH] pc_next0 = pc_next[0];
wire [`ADDR_WIDTH] pc_next1 = pc_next[1];
wire [`ADDR_WIDTH] pc_next2 = pc_next[2];
wire [`ADDR_WIDTH] pc_next3 = pc_next[3];
wire [`ADDR_WIDTH] pc_next4 = pc_next[4];
wire [`ADDR_WIDTH] pc_next5 = pc_next[5];
wire [`ADDR_WIDTH] pc_next6 = pc_next[6];
wire [`ADDR_WIDTH] pc_next7 = pc_next[7];
wire [`ADDR_WIDTH] pc_next8 = pc_next[8];
wire [`ADDR_WIDTH] pc_next9 = pc_next[9];
wire [`ADDR_WIDTH] pc_next10 = pc_next[10];
wire [`ADDR_WIDTH] pc_next11 = pc_next[11];
wire [`ADDR_WIDTH] pc_next12 = pc_next[12];
wire [`ADDR_WIDTH] pc_next13 = pc_next[13];
wire [`ADDR_WIDTH] pc_next14 = pc_next[14];
wire [`ADDR_WIDTH] pc_next15 = pc_next[15];

wire [`DATA_WIDTH] result0 = result[0];
wire [`DATA_WIDTH] result1 = result[1];
wire [`DATA_WIDTH] result2 = result[2];
wire [`DATA_WIDTH] result3 = result[3];
wire [`DATA_WIDTH] result4 = result[4];
wire [`DATA_WIDTH] result5 = result[5];
wire [`DATA_WIDTH] result6 = result[6];
wire [`DATA_WIDTH] result7 = result[7];
wire [`DATA_WIDTH] result8 = result[8];
wire [`DATA_WIDTH] result9 = result[9];
wire [`DATA_WIDTH] result10 = result[10];
wire [`DATA_WIDTH] result11 = result[11];
wire [`DATA_WIDTH] result12 = result[12];
wire [`DATA_WIDTH] result13 = result[13];
wire [`DATA_WIDTH] result14 = result[14];
wire [`DATA_WIDTH] result15 = result[15];

wire [`OPE_WIDTH] type0 = type[0];
wire [`OPE_WIDTH] type1 = type[1];
wire [`OPE_WIDTH] type2 = type[2];
wire [`OPE_WIDTH] type3 = type[3];
wire [`OPE_WIDTH] type4 = type[4];
wire [`OPE_WIDTH] type5 = type[5];
wire [`OPE_WIDTH] type6 = type[6];
wire [`OPE_WIDTH] type7 = type[7];
wire [`OPE_WIDTH] type8 = type[8];
wire [`OPE_WIDTH] type9 = type[9];
wire [`OPE_WIDTH] type10 = type[10];
wire [`OPE_WIDTH] type11 = type[11];
wire [`OPE_WIDTH] type12 = type[12];
wire [`OPE_WIDTH] type13 = type[13];
wire [`OPE_WIDTH] type14 = type[14];
wire [`OPE_WIDTH] type15 = type[15];

wire [`ADDR_WIDTH] pc0 = pc[0];
wire [`ADDR_WIDTH] pc1 = pc[1];
wire [`ADDR_WIDTH] pc2 = pc[2];
wire [`ADDR_WIDTH] pc3 = pc[3];
wire [`ADDR_WIDTH] pc4 = pc[4];
wire [`ADDR_WIDTH] pc5 = pc[5];
wire [`ADDR_WIDTH] pc6 = pc[6];
wire [`ADDR_WIDTH] pc7 = pc[7];
wire [`ADDR_WIDTH] pc8 = pc[8];
wire [`ADDR_WIDTH] pc9 = pc[9];
wire [`ADDR_WIDTH] pc10 = pc[10];
wire [`ADDR_WIDTH] pc11 = pc[11];
wire [`ADDR_WIDTH] pc12 = pc[12];
wire [`ADDR_WIDTH] pc13 = pc[13];
wire [`ADDR_WIDTH] pc14 = pc[14];
wire [`ADDR_WIDTH] pc15 = pc[15];

wire [`ADDR_WIDTH] code0 = code[0];
wire [`ADDR_WIDTH] code1 = code[1];
wire [`ADDR_WIDTH] code2 = code[2];
wire [`ADDR_WIDTH] code3 = code[3];
wire [`ADDR_WIDTH] code4 = code[4];
wire [`ADDR_WIDTH] code5 = code[5];
wire [`ADDR_WIDTH] code6 = code[6];
wire [`ADDR_WIDTH] code7 = code[7];
wire [`ADDR_WIDTH] code8 = code[8];
wire [`ADDR_WIDTH] code9 = code[9];
wire [`ADDR_WIDTH] code10 = code[10];
wire [`ADDR_WIDTH] code11 = code[11];
wire [`ADDR_WIDTH] code12 = code[12];
wire [`ADDR_WIDTH] code13 = code[13];
wire [`ADDR_WIDTH] code14 = code[14];
wire [`ADDR_WIDTH] code15 = code[15];

// ---------------------------------


endmodule