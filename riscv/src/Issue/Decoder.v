`include "define.v"

module Decoder(
   input wire [`INS_WIDTH]code,
   input wire [`ADDR_WIDTH] pc,
   output reg [`OPE_WIDTH] ins_type,
   output reg [`REG_NUMBER_WIDTH] ins_rd, ins_rs1, ins_rs2,    // reg destination, reg source1, reg source2
   output reg [`DATA_WIDTH] ins_imm                            // ins immediate
);

function [`INS_WIDTH] signed_extend;
   input [`INS_WIDTH] c;
   input [`OPE_WIDTH] bit;
   signed_extend = (bit == 32) ? c : c >> (bit - 1) & 1 ? c | (32'hFFFFFFFF >> bit << bit) : c;
endfunction

always @(*) begin
   ins_type = `EMPTY_INS;
   ins_rd = (code >> 7) & 12'h1F;
   ins_rs1 = code >> 15 & 12'h1F;
   ins_rs2 = code >> 20 & 12'h1F;
   case (code & 12'h7F)
      12'h37: begin
         ins_type = `LUI;
         ins_imm = signed_extend(code >> 12, 20);
      end
      12'h17: begin
         ins_type = `AUIPC;
         ins_imm = signed_extend(code >> 12, 20);
      end
      12'h6F: begin
         ins_type = `JAL;
         ins_imm = signed_extend((code >> 31 & 1) << 20 | (code >> 21 & 12'h3FF) << 1 | (code >> 20 & 1) << 11 | (code >> 12 & 12'hFF) << 12, 21);
      end
      12'h67: begin
         ins_type = `JALR;
         ins_imm = signed_extend(code >> 20, 12);
      end
      12'h63: begin
         ins_imm = signed_extend((code >> 8 & 12'hF) << 1 | (code >> 25 & 12'h3F) << 5 | (code >> 7 & 1) << 11 | (code >> 31 & 1) << 12, 13);
         case (code >> 12 & 7) 
            0: ins_type = `BEQ;
            1: ins_type = `BNE;
            4: ins_type = `BLT;
            5: ins_type = `BGE;
            6: ins_type = `BLTU;
            7: ins_type = `BGEU;
         endcase
      end
      3: begin
         ins_imm = signed_extend(code >> 20, 12);
         case (code >> 12 & 7) 
            0: ins_type = `LB;
            1: ins_type = `LH;
            2: ins_type = `LW;
            4: ins_type = `LBU;
            5: ins_type = `LHU;
         endcase
      end
      12'h23: begin
         ins_imm = signed_extend((code >> 7 & 12'h1F) | (code >> 25) << 5, 12);
         case (code >> 12 & 7) 
            0: ins_type = `SB;
            1: ins_type = `SH;
            2: ins_type = `SW;
         endcase
      end
      12'h13: begin
         ins_imm = signed_extend(code >> 20, 12);
         case (code >> 12 & 7)
            0: ins_type = `ADDI;
            2: ins_type = `SLTI;
            3: ins_type = `SLTIU;
            4: ins_type = `XORI;
            6: ins_type = `ORI;
            7: ins_type = `ANDI;
            1: ins_type = `SLLI;
            5: ins_type = (code >> 30 & 1) ? `SRAI : `SRLI;
         endcase
      end
      12'h33: begin
         case (code >> 12 & 7) 
            0: ins_type = (code >> 30 & 1) ? `SUB : `ADD;
            1: ins_type = `SLL;
            2: ins_type = `SLT;
            3: ins_type = `SLTU;
            4: ins_type = `XOR;
            5: ins_type = (code >> 30 & 1) ? `SRA : `SRL;
            6: ins_type = `OR;
            7: ins_type = `AND;
         endcase
      end
   endcase
end
endmodule
