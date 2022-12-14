// Dispatcher: 1.ask for Qj, Qk, Qj, Qk(rs1, rs2); 2.modify Qj(rd, renaming)
// ROB: 3.modify Qj, Vj(commit and write back); 4. mispredict 
// conflict may occur when requests are sent at the same time
// misrpedict: clear all Qj
// ask: 3. may affect 1.
// modify: 2. may affect 3.
// mispredict: set all Q to `NON_DEPENDENT, allow 3. to modify V

`include "define.v"

module RegFile(
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with dispatcher
   input wire enable_from_dsp,
   input wire [`EX_REG_NUMBER_WIDTH] rs1_from_dsp, rs2_from_dsp,
   input wire [`REG_NUMBER_WIDTH] rd_from_dsp,
   input wire [`ROB_ID_TYPE] Q_from_dsp,
   output wire [`DATA_WIDTH] Vj_to_dsp, Vk_to_dsp,
   output wire [`ROB_ID_TYPE] Qj_to_dsp, Qk_to_dsp,

   // interact with rob
   input wire mispredict,
   input wire enable_from_rob,
   input wire [`REG_NUMBER_WIDTH] rd_from_rob,
   input wire [`ROB_ID_TYPE] Q_from_rob,
   input wire [`DATA_WIDTH] V_from_rob
);

reg [`DATA_WIDTH] V[`REG_SIZE_ARR];
reg [`ROB_ID_TYPE] Q[`REG_SIZE_ARR];

assign Qj_to_dsp = (mispredict || rs1_from_dsp == `REG_NUMBER) ? `NON_DEPENDENT : (enable_from_rob && rd_from_rob == rs1_from_dsp && Q_from_rob == Q[rs1_from_dsp]) ? `NON_DEPENDENT : Q[rs1_from_dsp];
assign Qk_to_dsp = (mispredict || rs2_from_dsp == `REG_NUMBER) ? `NON_DEPENDENT : (enable_from_rob && rd_from_rob == rs2_from_dsp && Q_from_rob == Q[rs2_from_dsp]) ? `NON_DEPENDENT : Q[rs2_from_dsp];
assign Vj_to_dsp = rs1_from_dsp == `REG_NUMBER ? 0 : mispredict ? V[rs1_from_dsp] : (enable_from_rob && rd_from_rob == rs1_from_dsp && Q_from_rob == Q[rs1_from_dsp]) ? V_from_rob : V[rs1_from_dsp];
assign Vk_to_dsp = rs2_from_dsp == `REG_NUMBER ? 0 : mispredict ? V[rs2_from_dsp] : (enable_from_rob && rd_from_rob == rs2_from_dsp && Q_from_rob == Q[rs2_from_dsp]) ? V_from_rob : V[rs2_from_dsp];

integer i;

always @(posedge clk) begin
   if (rst) begin
      for (i = 0; i < `REG_NUMBER; i = i + 1) begin
         Q[i] <= 0;
         V[i] <= 0;
      end
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (mispredict) begin
         for (i = 0; i < `REG_NUMBER; i = i + 1) begin
            Q[i] <= 0;
         end
      end
      else if (enable_from_dsp && !mispredict) begin
         Q[rd_from_dsp] <= Q_from_dsp;
      end
      if (enable_from_rob) begin
         V[rd_from_rob] <= V_from_rob;
         if ((!enable_from_dsp || rd_from_dsp != rd_from_rob) && Q_from_rob == Q[rd_from_rob] && !mispredict) begin
            Q[rd_from_dsp] <= 0;
         end
      end
   end
end

endmodule