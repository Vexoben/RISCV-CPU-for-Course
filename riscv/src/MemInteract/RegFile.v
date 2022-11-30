// Dispatcher: 1.ask for Qj, Qk, Qj, Qk(rs1, rs2); 2.modify Qj(rd, renaming)
// ROB: 3.modify Qj, Vj(commit and write back); 4. mispredict 
// conflict may occur when requests are sent at the same time
// misrpedict: clear all Qj
// ask: 3. may affect 1.
// modify: 2. may affect 3.

`include "define.v"

module RegFile(
   input wire clk,
   input wire rst,
   input wire rdy
);

endmodule