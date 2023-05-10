//========================================================================
// Accumulator Unit
//========================================================================
// Accumulates values in a vector in memory. Note that a user must make
// sure the base_addr and size are valid on the same cycle that the go
// signal is set high. Then the user must lower the go signal on the next
// cycle. The result is only valid for a single cycle when the done
// signal is high.

`ifndef ACCUM_ACCUM_UNIT_V
`define ACCUM_ACCUM_UNIT_V

`include "vc/trace.v"

`include "vc/mem-msgs.v"
`include "vc/queues.v"

module accum_AccumUnit
(
  input  logic         clk,
  input  logic         reset,

  input  logic         go,
  input  logic [31:0]  base_addr,
  input  logic [31:0]  size,
  output logic         done,
  output logic [31:0]  result,

  output mem_req_4B_t  mem_reqstream_msg,
  output logic         mem_reqstream_val,
  input  logic         mem_reqstream_rdy,

  input  mem_resp_4B_t mem_respstream_msg,
  input  logic         mem_respstream_val,
  output logic         mem_respstream_rdy
);

  // 4-state sim fix: force outputs to be zero if invalid

  mem_req_4B_t mem_reqstream_msg_raw;
  assign mem_reqstream_msg = mem_reqstream_msg_raw & {78{mem_reqstream_val}};

  // Memory ports and queues

  logic         memresp_deq_val;
  logic         memresp_deq_rdy;
  mem_resp_4B_t memresp_deq_msg;

  vc_Queue#(`VC_QUEUE_PIPE,$bits(mem_resp_4B_t),1) memresp_q
  (
    .clk     (clk),
    .reset   (reset),
    .num_free_entries(),

    .enq_val (mem_respstream_val),
    .enq_rdy (mem_respstream_rdy),
    .enq_msg (mem_respstream_msg),

    .deq_val (memresp_deq_val),
    .deq_rdy (memresp_deq_rdy),
    .deq_msg (memresp_deq_msg)
  );

  // Extra state registers

  logic [31:0] idx,    idx_next;
  logic [31:0]         result_next;

  always_ff @(posedge clk) begin
    if (reset) begin
      idx    <= 0;
      result <= 0;
    end
    else begin
      idx    <= idx_next;
      result <= result_next;
    end
  end

  //======================================================================
  // State Update
  //======================================================================

  localparam STATE_IDLE = 3'd0;
  localparam STATE_M_RD = 3'd1;
  localparam STATE_CALC = 3'd2;
  localparam STATE_DONE = 3'd3;

  logic [2:0] state_reg;

  always_ff @(posedge clk) begin

    if ( reset )
      state_reg <= STATE_IDLE;
    else begin
      state_reg <= state_reg;

      case ( state_reg )

        STATE_IDLE:
          if ( go )
            state_reg <= STATE_M_RD;

        STATE_M_RD:
          if ( mem_reqstream_rdy )
            state_reg <= STATE_CALC;

        STATE_CALC:
          if ( memresp_deq_val )
            if ( idx < size - 1 )
              state_reg <= STATE_M_RD;
            else
              state_reg <= STATE_DONE;

        STATE_DONE:
          state_reg <= STATE_IDLE;

        default:
          state_reg <= STATE_IDLE;

      endcase
    end
  end

  //======================================================================
  // State Outputs
  //======================================================================

  always_comb begin

    mem_reqstream_val = 0;
    memresp_deq_rdy   = 0;
    done              = 0;

    idx_next          = idx;
    result_next       = result;

    //--------------------------------------------------------------------
    // STATE: IDLE
    //--------------------------------------------------------------------
    // In this state we wait for the go signal.

    if ( state_reg == STATE_IDLE ) begin
      // ... nothing to do ...
    end

    //--------------------------------------------------------------------
    // STATE: M_RD
    //--------------------------------------------------------------------
    // Memory read stage. Send memory request to read src[i].

    else if ( state_reg == STATE_M_RD )
    begin
      mem_reqstream_val = 1;

      mem_reqstream_msg_raw.type_  = `VC_MEM_REQ_MSG_TYPE_READ;
      mem_reqstream_msg_raw.opaque = 0;
      mem_reqstream_msg_raw.addr   = base_addr + (idx << 2);
      mem_reqstream_msg_raw.len    = 0;
      mem_reqstream_msg_raw.data   = 0;

    end

    //--------------------------------------------------------------------
    // STATE: CALC
    //--------------------------------------------------------------------
    // Wait for memory response to come back, then do accumulate.

    else if ( state_reg == STATE_CALC )
    begin
      memresp_deq_rdy = 1;
      if ( memresp_deq_val ) begin
        result_next = result + memresp_deq_msg.data;

        // if idx < size - 1, still not through entire vector
        if ( idx < size - 1 )
          idx_next = idx + 1;
        else
          idx_next = 0;
      end
    end

    //--------------------------------------------------------------------
    // STATE: DONE
    //--------------------------------------------------------------------
    // Set the done signal for one cycle.

    else if ( state_reg == STATE_DONE )
    begin
      done = 1;
    end

  end

  //======================================================================
  // Line Tracing
  //======================================================================

  `ifndef SYNTHESIS

  logic [`VC_TRACE_NBITS-1:0] str;
  `VC_TRACE_BEGIN
  begin

    $sformat( str, "%x", go );
    vc_trace.append_str( trace_str, str );

    vc_trace.append_str( trace_str, "(" );

    case ( state_reg )
      STATE_IDLE:      vc_trace.append_str( trace_str, "I " );
      STATE_M_RD:      vc_trace.append_str( trace_str, "RD" );
      STATE_CALC:      vc_trace.append_str( trace_str, "C " );
      STATE_DONE:      vc_trace.append_str( trace_str, "D " );
      default:         vc_trace.append_str( trace_str, "? " );
    endcase
    vc_trace.append_str( trace_str, " " );

    $sformat( str, "%x", result  );
    vc_trace.append_str( trace_str, str );

    vc_trace.append_str( trace_str, "|" );

    $sformat( str, "%x", mem_respstream_msg.data );
    vc_trace.append_val_rdy_str( trace_str, mem_respstream_val, mem_respstream_rdy, str );

    vc_trace.append_str( trace_str, ")" );

    $sformat( str, "%x", done );
    vc_trace.append_str( trace_str, str );

  end
  `VC_TRACE_END

  `endif /* SYNTHESIS */

endmodule

`endif /* ACCUM_ACCUM_UNIT_V */

