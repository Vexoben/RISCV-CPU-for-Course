`include "define.v"

module LSB(
   // control signal
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with Dispatcher
   input wire enable_from_dsp,
   input wire [`DATA_WIDTH] Vj_from_dsp, Vk_from_dsp,
   input wire [`ROB_ID_TYPE] Qj_from_dsp, Qk_from_dsp, rob_id_from_dsp,
   input wire [`OPE_WIDTH] type_from_dsp,
   input wire [`DATA_WIDTH] imm_from_dsp,

   // interact with cdb
   output reg enable_cdb_lsb,
   output reg [`ROB_ID_TYPE] cdb_lsb_rob_id,
   output reg [`DATA_WIDTH] cdb_lsb_value,
   input wire enable_cdb_rs,
   input wire [`ROB_ID_TYPE] cdb_rs_rob_id,
   input wire [`DATA_WIDTH] cdb_rs_value,
   
   // interact with memctrl
   input ok_from_memctrl,
   input [`DATA_WIDTH] data_from_memctrl,
   output reg enable_to_memctrl,
   output reg read_or_write_to_memctrl,          // read:1, write:0
   output reg [`ADDR_WIDTH] addr_to_memctrl,
   output reg [`DATA_WIDTH] data_to_memctrl,
   output reg [2:0] width_to_memctrl,

   // interact with rob
   input wire mispredict,
   input wire commit_signal,
   input wire [`ROB_ID_TYPE] committed_from_rob,

   // global
   output wire full_lsb
);

reg [`LSB_ID_TYPE] head, tail;
reg [`LSB_ID_TYPE] size, push, pop;

reg [`DATA_WIDTH] Vj[`LSB_SIZE_ARR], Vk[`LSB_SIZE_ARR];
reg [`ROB_SIZE_ARR] Qj[`LSB_SIZE_ARR], Qk[`LSB_SIZE_ARR], rob_id[`LSB_SIZE_ARR];
reg [`OPE_WIDTH] type[`LSB_SIZE_ARR];
reg [`DATA_WIDTH] imm[`LSB_SIZE_ARR];
reg [`LSB_SIZE_ARR] busy;
reg [`LSB_SIZE_ARR] commited;

wire [`DATA_WIDTH] real_Vj, real_Vk;
wire [`ROB_SIZE_ARR] real_Qj, real_Qk;

assign real_Qj = (enable_cdb_rs && cdb_rs_rob_id == Qj_from_dsp) ? `NON_DEPENDENT : (enable_cdb_lsb && cdb_lsb_rob_id == Qj_from_dsp) ? `NON_DEPENDENT : Qj_from_dsp;
assign real_Qk = (enable_cdb_rs && cdb_rs_rob_id == Qk_from_dsp) ? `NON_DEPENDENT : (enable_cdb_lsb && cdb_lsb_rob_id == Qk_from_dsp) ? `NON_DEPENDENT : Qk_from_dsp;
assign real_Vj = (enable_cdb_rs && cdb_rs_rob_id == Qj_from_dsp) ? cdb_rs_value : (enable_cdb_lsb && cdb_lsb_rob_id == Qj_from_dsp) ? cdb_lsb_value : Vj_from_dsp;
assign real_Vk = (enable_cdb_rs && cdb_rs_rob_id == Qk_from_dsp) ? cdb_rs_value : (enable_cdb_lsb && cdb_lsb_rob_id == Qk_from_dsp) ? cdb_lsb_value : Vk_from_dsp;
assign full_lsb = size == `LSB_SIZE;

wire head_is_load = busy[head] && (type[head] == `LB || type[head] == `LH || type[head] == `LBU || type[head] == `LHU || type[head] == `LW);
wire head_is_store = busy[head] && (type[head] == `SB || type[head] == `SH || type[head] == `SW);


parameter
STALL = 0,
RECIEVE = 1,
READ_DATA = 2,
WRITE_DATA_WAIT_ROB = 3,
WRITE_DATA_MEM = 4;
reg [2:0] work_statu;

reg[`LSB_SIZE_ARR] ready;
always @(*) begin
   for (integer i = 0; i < `LSB_SIZE; ++i) begin
      ready[i] = Qj[i] == `NON_DEPENDENT && Qk[i] == `NON_DEPENDENT;
   end
end

always @(posedge clk) begin
   if (rst || mispredict) begin
      head <= 0;
      tail <= 0;
      push <= 0;
      pop <= 0;
      size <= 0;
      enable_cdb_lsb <= 0;
      enable_to_memctrl <= 0;
      for (integer i = 0; i < `LSB_SIZE; ++i) begin
         busy[i] <= 0;
         commited[i] <= 0;
      end
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (enable_from_dsp) begin
         push <= 1;
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
      else push <= 0;
      if (work_statu == STALL) begin
         pop <= 0;
         if (head_is_load && ready[head]) begin
            work_statu <= READ_DATA;
            enable_to_memctrl <= 1;
            read_or_write_to_memctrl <= 1;
            addr_to_memctrl <= Vj[head] + imm[head];
            head = (head + 1 == `LSB_SIZE) ? 0 : head + 1;
            case (type[head])
               `LB: begin
                  width_to_memctrl <= 1;
               end
               `LH: begin
                  width_to_memctrl <= 2;
               end
               `LBU: begin
                  width_to_memctrl <= 1;
               end
               `LHU: begin
                  width_to_memctrl <= 2;
               end
               `LW: begin
                  width_to_memctrl <= 4;
               end
            endcase
         end 
         if (head_is_store && ready[head]) begin
            work_statu <= commited[head] ? WRITE_DATA_MEM : WRITE_DATA_WAIT_ROB;
            enable_to_memctrl <= commited[head];
            read_or_write_to_memctrl <= 1;
            addr_to_memctrl <= Vj[head] + imm[head];
            data_to_memctrl <= Vk[head];
            case (type[head])
               `SB: begin
                  width_to_memctrl <= 1;
               end
               `SH: begin
                  width_to_memctrl <= 2;
               end
               `SW: begin
                  width_to_memctrl <= 4;
               end
            endcase
         end
      end
      else if (work_statu == READ_DATA) begin
         if (ok_from_memctrl) begin
            pop <= 1;
            work_statu <= STALL;
            enable_cdb_lsb <= 1;
            cdb_lsb_rob_id <= rob_id[head];
            cdb_lsb_value <= data_from_memctrl;
            case (type[head])
               `LB: cdb_lsb_value <= {{25{data_from_memctrl[7]}}, data_from_memctrl[6:0]};
               `LH: cdb_lsb_value <= {{17{data_from_memctrl[15]}}, data_from_memctrl[14:0]};
               `LW: cdb_lsb_value <= data_from_memctrl;
               `LBU: cdb_lsb_value <= {24'b0, data_from_memctrl[7:0]};
               `LHU: cdb_lsb_value <= {16'b0, data_from_memctrl[15:0]};
            endcase
            busy[head] <= 0;
            head = (head + 1 == `LSB_SIZE) ? 0 : head + 1;
         end
         else pop <= 0;
      end
      else if (work_statu == WRITE_DATA_WAIT_ROB) begin
         pop <= 0;
         if (commited[head]) begin
            work_statu <= WRITE_DATA_MEM;
            enable_to_memctrl <= 1;            
         end
      end
      else if (work_statu == WRITE_DATA_MEM) begin
         if (ok_from_memctrl) begin
            pop <= 1;
            work_statu <= STALL;
            busy[head] <= 0;
            commited[head] <= 0;
            head = (head + 1 == `LSB_SIZE) ? 0 : head + 1;
         end
         else pop <= 0;
      end
   end

   size <= size + push - pop;

   if (enable_cdb_lsb) begin
      for (integer i = 0; i < `LSB_SIZE; ++i) begin
         if (Qj[i] == cdb_lsb_rob_id) begin
            Qj[i] <= `NON_DEPENDENT;
         end
         if (Qk[i] == cdb_lsb_rob_id) begin
            Qk[i] <= `NON_DEPENDENT;
         end
      end
      enable_cdb_lsb <= 0;
   end
   if (enable_cdb_rs) begin
      for (integer i = 0; i < `LSB_SIZE; ++i) begin
         if (Qj[i] == cdb_rs_rob_id) begin
            Qj[i] <= `NON_DEPENDENT;
         end
         if (Qk[i] == cdb_rs_rob_id) begin
            Qk[i] <= `NON_DEPENDENT;
         end
      end      
   end
   if (commit_signal) begin
      for (integer i = 0; i < `LSB_SIZE; ++i) begin
         if (rob_id[i] == committed_from_rob) begin
            commited[i] = 1;
         end
      end
   end
end

endmodule