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
   output reg read_or_write_to_memctrl,          // read:0, write:1
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

reg [`LSB_ID_TYPE] head, tail, committed_tail;
reg [`LSB_ID_TYPE] size, push, pop;

reg [`DATA_WIDTH] Vj[`LSB_SIZE_ARR], Vk[`LSB_SIZE_ARR];
reg [`ROB_ID_TYPE] Qj[`LSB_SIZE_ARR], Qk[`LSB_SIZE_ARR], rob_id[`LSB_SIZE_ARR];
reg [`OPE_WIDTH] type[`LSB_SIZE_ARR];
reg [`DATA_WIDTH] imm[`LSB_SIZE_ARR];
reg [`LSB_SIZE_ARR] busy;
reg [`LSB_SIZE_ARR] committed;

wire [`DATA_WIDTH] real_Vj, real_Vk;
wire [`ROB_SIZE_ARR] real_Qj, real_Qk;

assign real_Qj = (enable_cdb_rs && cdb_rs_rob_id == Qj_from_dsp) ? `NON_DEPENDENT : (enable_cdb_lsb && cdb_lsb_rob_id == Qj_from_dsp) ? `NON_DEPENDENT : Qj_from_dsp;
assign real_Qk = (enable_cdb_rs && cdb_rs_rob_id == Qk_from_dsp) ? `NON_DEPENDENT : (enable_cdb_lsb && cdb_lsb_rob_id == Qk_from_dsp) ? `NON_DEPENDENT : Qk_from_dsp;
assign real_Vj = (enable_cdb_rs && cdb_rs_rob_id == Qj_from_dsp) ? cdb_rs_value : (enable_cdb_lsb && cdb_lsb_rob_id == Qj_from_dsp) ? cdb_lsb_value : Vj_from_dsp;
assign real_Vk = (enable_cdb_rs && cdb_rs_rob_id == Qk_from_dsp) ? cdb_rs_value : (enable_cdb_lsb && cdb_lsb_rob_id == Qk_from_dsp) ? cdb_lsb_value : Vk_from_dsp;
assign full_lsb = (size + 1 >= `LSB_SIZE);

wire head_is_load = busy[head] && (type[head] == `LB || type[head] == `LH || type[head] == `LBU || type[head] == `LHU || type[head] == `LW);
wire head_is_store = busy[head] && (type[head] == `SB || type[head] == `SH || type[head] == `SW);

integer i;

parameter
STALL = 0,
RECIEVE = 1,
READ_DATA = 2,
WRITE_DATA_WAIT_ROB = 3,
WRITE_DATA_MEM = 4;
reg [2:0] work_statu;

reg[`LSB_SIZE_ARR] ready;
always @(*) begin
   for (i = 0; i < `LSB_SIZE; i = i + 1) begin
      ready[i] = Qj[i] == `NON_DEPENDENT && Qk[i] == `NON_DEPENDENT;
   end
end

always @(posedge clk) begin

   // if (enable_cdb_lsb) begin // debug demo
   //    $display("read: %d", cdb_lsb_value);
   // end

   if (rst) begin
      head <= 0; tail <= 0; committed_tail <= 0;
      push <= 0; pop <= 0; size <= 0;
      enable_cdb_lsb <= 0;
      enable_to_memctrl <= 0;
      work_statu <= STALL;
      for (i = 0; i < `LSB_SIZE; i = i + 1) begin
         busy[i] <= 0;
         committed[i] <= 0;
      end
   end
   else if (!rdy) begin
      // do nothing
   end
   else if (mispredict) begin
      tail <= committed_tail;
      size <= (committed_tail >= head ? committed_tail - head : committed_tail + `LSB_SIZE - head);
      push <= 0; pop <= 0;
      enable_cdb_lsb <= 0;
      enable_to_memctrl <= 0;
      for (i = 0; i < `LSB_SIZE; i = i + 1) begin
         if (!committed[i]) begin
            busy[i] <= 0;
         end
      end
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
         committed[tail] <= 0;
         busy[tail] <= 1;
         tail <= (tail == `LSB_SIZE - 1) ? 0 : tail + 1;
      end
      else push <= 0;
      if (work_statu == STALL) begin
         pop <= 0;
         if (head_is_load && ready[head]) begin
            work_statu <= READ_DATA;
            enable_to_memctrl <= 1;
            read_or_write_to_memctrl <= 0;
            addr_to_memctrl <= Vj[head] + imm[head];
            // $display("load: %d, width = %d", Vj[head] + imm[head], (type[head] == `LB || type[head] == `LBU) ? 1 : type[head] == `LW ? 4 : 2);
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
            work_statu <= committed[head] ? WRITE_DATA_MEM : WRITE_DATA_WAIT_ROB;
            enable_to_memctrl <= committed[head];
            read_or_write_to_memctrl <= 1;
            addr_to_memctrl <= Vj[head] + imm[head];
            data_to_memctrl <= Vk[head];
            // $display("store: %d %d, width = %d", Vj[head] + imm[head], Vk[head], type[head] == `SB ? 1 : type[head] == `SH ? 2 : 4);
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
            enable_to_memctrl <= 0;
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
            head <= (head + 1 == `LSB_SIZE) ? 0 : head + 1;
            committed_tail <= (head + 1 == `LSB_SIZE) ? 0 : head + 1;
         end
         else pop <= 0;
      end
      else if (work_statu == WRITE_DATA_WAIT_ROB) begin
         pop <= 0;
         if (committed[head]) begin
            work_statu <= WRITE_DATA_MEM;
            enable_to_memctrl <= 1;            
         end
      end
      else if (work_statu == WRITE_DATA_MEM) begin
         if (ok_from_memctrl) begin
            enable_to_memctrl <= 0;
            pop <= 1;
            work_statu <= STALL;
            busy[head] <= 0;
            committed[head] <= 0;
            head = (head + 1 == `LSB_SIZE) ? 0 : head + 1;
         end
         else pop <= 0;
      end

      size <= size + push - pop;

      if (enable_cdb_lsb) begin
         for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            if (Qj[i] != `NON_DEPENDENT && Qj[i] == cdb_lsb_rob_id) begin
               Qj[i] <= `NON_DEPENDENT;
               Vj[i] <= cdb_lsb_value;
            end
            if (Qk[i] != `NON_DEPENDENT && Qk[i] == cdb_lsb_rob_id) begin
               Qk[i] <= `NON_DEPENDENT;
               Vj[i] <= cdb_lsb_value;
            end
         end
         if (!(work_statu == READ_DATA && ok_from_memctrl)) begin
            enable_cdb_lsb <= 0;
         end
      end
      if (enable_cdb_rs) begin
         for (i = 0; i < `LSB_SIZE; i = i + 1) begin
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
      if (commit_signal) begin
         for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            if (rob_id[i] == committed_from_rob && rob_id[i] != `NON_DEPENDENT) begin
               committed[i] = 1;
            end
         end
         committed_tail <= (committed_tail + 1 == `LSB_SIZE) ? 0 : committed_tail + 1;
      end
   end
end

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

wire [`ADDR_WIDTH] Qk0 = Qk[0];
wire [`ADDR_WIDTH] Qk1 = Qk[1];
wire [`ADDR_WIDTH] Qk2 = Qk[2];
wire [`ADDR_WIDTH] Qk3 = Qk[3];
wire [`ADDR_WIDTH] Qk4 = Qk[4];
wire [`ADDR_WIDTH] Qk5 = Qk[5];
wire [`ADDR_WIDTH] Qk6 = Qk[6];
wire [`ADDR_WIDTH] Qk7 = Qk[7];
wire [`ADDR_WIDTH] Qk8 = Qk[8];
wire [`ADDR_WIDTH] Qk9 = Qk[9];
wire [`ADDR_WIDTH] Qk10 = Qk[10];
wire [`ADDR_WIDTH] Qk11 = Qk[11];
wire [`ADDR_WIDTH] Qk12 = Qk[12];
wire [`ADDR_WIDTH] Qk13 = Qk[13];
wire [`ADDR_WIDTH] Qk14 = Qk[14];
wire [`ADDR_WIDTH] Qk15 = Qk[15];

wire ready0 = ready[0];

endmodule