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
   input wire [`EX_REG_NUMBER_WIDTH] rd_from_dsp,
   input wire [`ROB_ID_TYPE] rob_id_from_dsp,
   output wire [`DATA_WIDTH] Vj_to_dsp, Vk_to_dsp,
   output wire [`ROB_ID_TYPE] Qj_to_dsp, Qk_to_dsp,

   // interact with rob
   input wire mispredict,
   input wire enable_from_rob,
   input wire [`EX_REG_NUMBER_WIDTH] rd_from_rob,
   input wire [`ROB_ID_TYPE] Q_from_rob,
   input wire [`DATA_WIDTH] V_from_rob
);

reg [`DATA_WIDTH] V[`REG_SIZE_ARR];
reg [`ROB_ID_TYPE] Q[`REG_SIZE_ARR];

assign Qj_to_dsp = (mispredict || rs1_from_dsp == `REG_NUMBER || rs1_from_dsp == 0) ? `NON_DEPENDENT : (enable_from_rob && rd_from_rob == rs1_from_dsp && Q_from_rob == Q[rs1_from_dsp]) ? `NON_DEPENDENT : Q[rs1_from_dsp];
assign Qk_to_dsp = (mispredict || rs2_from_dsp == `REG_NUMBER || rs2_from_dsp == 0) ? `NON_DEPENDENT : (enable_from_rob && rd_from_rob == rs2_from_dsp && Q_from_rob == Q[rs2_from_dsp]) ? `NON_DEPENDENT : Q[rs2_from_dsp];
assign Vj_to_dsp = rs1_from_dsp == `REG_NUMBER || rs1_from_dsp == 0 ? 0 : mispredict ? V[rs1_from_dsp] : (enable_from_rob && rd_from_rob == rs1_from_dsp && Q_from_rob == Q[rs1_from_dsp]) ? V_from_rob : V[rs1_from_dsp];
assign Vk_to_dsp = rs2_from_dsp == `REG_NUMBER || rs2_from_dsp == 0 ? 0 : mispredict ? V[rs2_from_dsp] : (enable_from_rob && rd_from_rob == rs2_from_dsp && Q_from_rob == Q[rs2_from_dsp]) ? V_from_rob : V[rs2_from_dsp];

integer i;

// always @(V[0], V[1], V[2], V[3], V[4], V[5], V[6], V[7], V[8], V[9], V[10], V[11], V[12], V[13], V[14], V[15], V[16], V[17], V[18], V[19], V[20], V[21], V[22], V[23], V[24], V[25], V[26], V[27], V[28], V[29], V[30], V[31]) begin
//    for (i = 0; i < `REG_NUMBER; i = i + 1) begin
//       $display("reg%d: %d", i, V[i]);
//    end
//    $display("--------------------------");
// end

always @(posedge clk) begin
   if (rst) begin
      for (i = 0; i < `REG_NUMBER; i = i + 1) begin
         Q[i] <= `NON_DEPENDENT;
         V[i] <= 0;
      end
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (mispredict) begin
         for (i = 0; i < `REG_NUMBER; i = i + 1) begin
            Q[i] <= `NON_DEPENDENT;
         end
      end
      else if (enable_from_dsp && !mispredict) begin
         if (rd_from_dsp != 0) Q[rd_from_dsp] <= rob_id_from_dsp;
      end
      if (enable_from_rob) begin
         if (rd_from_rob != 0) begin
            V[rd_from_rob] <= V_from_rob;
            if ((!enable_from_dsp || rd_from_dsp != rd_from_rob) && Q_from_rob == Q[rd_from_rob] && !mispredict) begin
               Q[rd_from_rob] <= `NON_DEPENDENT;
            end
         end
      end
   end
end

wire [`ADDR_WIDTH] V0 = V[0];
wire [`ADDR_WIDTH] V1 = V[1];
wire [`ADDR_WIDTH] V2 = V[2];
wire [`ADDR_WIDTH] V3 = V[3];
wire [`ADDR_WIDTH] V4 = V[4];
wire [`ADDR_WIDTH] V5 = V[5];
wire [`ADDR_WIDTH] V6 = V[6];
wire [`ADDR_WIDTH] V7 = V[7];
wire [`ADDR_WIDTH] V8 = V[8];
wire [`ADDR_WIDTH] V9 = V[9];
wire [`ADDR_WIDTH] V10 = V[10];
wire [`ADDR_WIDTH] V11 = V[11];
wire [`ADDR_WIDTH] V12 = V[12];
wire [`ADDR_WIDTH] V13 = V[13];
wire [`ADDR_WIDTH] V14 = V[14];
wire [`ADDR_WIDTH] V15 = V[15];

wire [`ADDR_WIDTH] Q0 = Q[0];
wire [`ADDR_WIDTH] Q1 = Q[1];
wire [`ADDR_WIDTH] Q2 = Q[2];
wire [`ADDR_WIDTH] Q3 = Q[3];
wire [`ADDR_WIDTH] Q4 = Q[4];
wire [`ADDR_WIDTH] Q5 = Q[5];
wire [`ADDR_WIDTH] Q6 = Q[6];
wire [`ADDR_WIDTH] Q7 = Q[7];
wire [`ADDR_WIDTH] Q8 = Q[8];
wire [`ADDR_WIDTH] Q9 = Q[9];
wire [`ADDR_WIDTH] Q10 = Q[10];
wire [`ADDR_WIDTH] Q11 = Q[11];
wire [`ADDR_WIDTH] Q12 = Q[12];
wire [`ADDR_WIDTH] Q13 = Q[13];
wire [`ADDR_WIDTH] Q14 = Q[14];
wire [`ADDR_WIDTH] Q15 = Q[15];

endmodule