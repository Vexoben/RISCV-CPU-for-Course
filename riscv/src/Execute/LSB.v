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
   input wire [`ROB_SIZE_ARR] Qj_from_dsp, Qk_from_dsp, rob_id_from_dsp,
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
   
   // interact with memctrl
   input ok_from_memctrl,
   input [`DATA_WIDTH] data_from_memctrl,
   output reg enable_to_memctrl,
   output reg read_or_write_to_memctrl,
   output reg [`ADDR_WIDTH] addr_to_memctrl,
   output reg [`DATA_WIDTH] data_to_memctrl,
   output reg [2:0] size_to_memctrl,

   // interact with rob
   input wire mispredict,

   // global
   output reg full_lsb
);

reg [`LSB_ID_TYPE] head, tail;

reg [`DATA_WIDTH] Vj[`LSB_SIZE_ARR], Vk[`LSB_SIZE_ARR];
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

wire head_is_load = busy[head] && (type[head] == `LB || type[head] == `LH || type[head] == `LBU || type[head] == `LHU || type[head] == `LW);
wire head_is_store = busy[head] && (type[head] == `SB || type[head] == `SH || type[head] == `SW);
wire head_is_ready = Qj[head] == `NON_DEPENDENT && Qk[head] == `NON_DEPENDENT;

parameter
STALL = 0,
RECIEVE = 1,
READ_DATA = 2,
WRITE_DATA = 3;
reg [2:0] work_statu;

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
   else if (mispredict) begin
      
   end
   else begin
      if (enable_from_dsp) begin
         pc[tail] <= pc_from_dsp;
         Vj[tail] <= real_Vj;
         Vk[tail] <= real_Vk;
         Qj[tail] <= real_Qj;
         Qk[tail] <= real_Qk;
         imm[tail] <= imm_from_dsp;
         type[tail] <= type_from_dsp;
         rob_id[tail] <= rob_id_from_dsp;
         busy[tail] <= 1;
         tail <= (tail == `LSB_SIZE - 1) ? 0 : tail + 1;
      end
      if (work_statu == STALL) begin
         if (head_is_load) begin
            work_statu <= READ_DATA;
            enable_to_memctrl <= 1;
            case (type[head])
               `LB: begin
                  
               end
               `LH: begin
                  
               end
               `LBU: begin
                  
               end
               `LHU: begin
                  
               end
               `LW: begin
                  
               end
            endcase
         end 
         if (head_is_store) work_statu <= WRITE_DATA;
      end
      else if (work_statu == READ_DATA) begin
         if (head_is_ready) begin
            if (ok_from_memctrl) begin
               
            end
         end
      end
      else if (work_statu == WRITE_DATA) begin
         
      end
   end
end

endmodule

