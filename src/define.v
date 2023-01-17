// vector length
`define OPE_WIDTH 5:0
`define INS_WIDTH 31:0
`define ADDR_WIDTH 31:0
`define REG_NUMBER 32
`define REG_NUMBER_WIDTH 5:0
`define EX_REG_NUMBER_WIDTH 6:0
`define REG_SIZE_ARR 31:0
`define DATA_WIDTH 31:0
`define MEM_WIDTH 31:0

// cpu para
// instruction cache parameters
`define TAG_RANGE 17:8
`define INDEX_RANGE 7:2
`define BLOCK_RANGE 1:0
`define IC_BLOCK_SIZE 4
`define IC_BLOCK_SIZE_ARR 3:0
`define ICACHE_SIZE 64
`define ICACHE_SIZE_ARR 63:0
// rob parameters
`define ROB_SIZE 8
`define ROB_SIZE_ARR 7:0
`define ROB_ID_TYPE 3:0
`define NON_DEPENDENT 8
`define RS_SIZE 8
`define RS_SIZE_ARR 7:0
`define RS_ID_TYPE 3:0
`define LSB_SIZE 8
`define LSB_SIZE_ARR 7:0
`define LSB_ID_TYPE 3:0

// ins number
`define EMPTY_INS 6'd0
`define LUI 6'd1
`define AUIPC 6'd2
`define JAL 6'd3
`define JALR 6'd4
`define BEQ 6'd5
`define BNE 6'd6
`define BLT 6'd7
`define BGE 6'd8
`define BLTU 6'd9
`define BGEU 6'd10
`define LB 6'd11
`define LH 6'd12
`define LW 6'd13
`define LBU 6'd14
`define LHU 6'd15
`define SB 6'd16
`define SH 6'd17
`define SW 6'd18
`define ADDI 6'd19
`define SLTI 6'd20
`define SLTIU 6'd21
`define XORI 6'd22
`define ORI 6'd23
`define ANDI 6'd24
`define SLLI 6'd25
`define SRLI 6'd26
`define SRAI 6'd27
`define ADD 6'd28
`define SUB 6'd29
`define SLL 6'd30
`define SLT 6'd31
`define SLTU 6'd32
`define XOR 6'd33
`define SRL 6'd34
`define SRA 6'd35
`define OR 6'd36
`define AND 6'd37

