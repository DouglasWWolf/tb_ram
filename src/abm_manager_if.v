//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 21-Mar-24  DWW     1  Initial creation
//====================================================================================


/*
    This is an AXI slave-interface to a pair of SDP (Simple Dual Port) RAM
    blocks.

    The AXI interface is read-only and doesn't not support narrow reads
*/

module abm_manager_if # (parameter DW = 512, AW=10)
(
    input clk, resetn,

    output reg [AW-1:0] ram_addr,
    input      [DW-1:0] ram0_data,

    //=================  This is the main AXI4-slave interface  ================

    // "Specify write address"              -- Master --    -- Slave --
    input[31:0]                             S_AXI_AWADDR,
    input                                   S_AXI_AWVALID,
    input[3:0]                              S_AXI_AWID,
    input[7:0]                              S_AXI_AWLEN,
    input[2:0]                              S_AXI_AWSIZE,
    input[1:0]                              S_AXI_AWBURST,
    input                                   S_AXI_AWLOCK,
    input[3:0]                              S_AXI_AWCACHE,
    input[3:0]                              S_AXI_AWQOS,
    input[2:0]                              S_AXI_AWPROT,
    output reg                                              S_AXI_AWREADY,

    // "Write Data"                         -- Master --    -- Slave --
    input[DW-1:0]                           S_AXI_WDATA,
    input[DW/8-1:0]                         S_AXI_WSTRB,
    input                                   S_AXI_WVALID,
    input                                   S_AXI_WLAST,
    output reg                                              S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output[1:0]                                             S_AXI_BRESP,
    output                                                  S_AXI_BVALID,
    input                                   S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input[31:0]                             S_AXI_ARADDR,
    input                                   S_AXI_ARVALID,
    input[2:0]                              S_AXI_ARPROT,
    input                                   S_AXI_ARLOCK,
    input[3:0]                              S_AXI_ARID,
    input[7:0]                              S_AXI_ARLEN,
    input[1:0]                              S_AXI_ARBURST,
    input[3:0]                              S_AXI_ARCACHE,
    input[3:0]                              S_AXI_ARQOS,
    output reg                                              S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output reg [DW-1:0]                                     S_AXI_RDATA,
    output reg                                              S_AXI_RVALID,
    output     [1:0]                                        S_AXI_RRESP,
    output                                                  S_AXI_RLAST,
    input                                   S_AXI_RREADY

    //==========================================================================
);

reg [2:0] fsm_state;
reg [7:0] burst_length, beat;
reg [1:0] latency_cycles;

assign S_AXI_RLAST = (beat == burst_length);
assign S_AXI_RRESP = 0;


always @(posedge clk) begin
    
    // This counter always counts down to zero
    if (latency_cycles) latency_cycles <= latency_cycles - 1;
    
    if (resetn == 0) begin
        fsm_state     <= 0;
        S_AXI_ARREADY <= 0;
    end else case (fsm_state)

        0:  begin
                S_AXI_ARREADY <= 1;
                fsm_state     <= fsm_state + 1;
            end

        1:  if (S_AXI_ARVALID & S_AXI_ARREADY) begin
                burst_length   <= S_AXI_ARLEN;
                beat           <= 0;
                ram_addr       <= S_AXI_ARADDR >> $clog2(DW/8);
                latency_cycles <= 1;
                S_AXI_ARREADY  <= 0;
                fsm_state      <= fsm_state + 1;
            end

        2:  if (latency_cycles == 0) begin
                S_AXI_RDATA    <= ram0_data;
                S_AXI_RVALID   <= 1;
                ram_addr       <= ram_addr + 1;
                latency_cycles <= 0;
                fsm_state      <= fsm_state + 1;
            end

        3:  if (S_AXI_RREADY & S_AXI_RVALID) begin
                S_AXI_RVALID <= 0;
                if (S_AXI_RLAST) begin
                    S_AXI_ARREADY <= 1;
                    fsm_state     <= 1;
                end else begin
                    beat          <= beat + 1;
                    fsm_state     <= fsm_state - 1;
                end
            end

    endcase
end



endmodule
