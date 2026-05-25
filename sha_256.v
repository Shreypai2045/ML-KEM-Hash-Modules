`timescale 1ns/1ps

module sha_256(
  input  wire          clk,
  input  wire          resetn,
  input  wire          start,
  input  wire [1087:0] data_i,
  output wire [255:0]  data_o,
  output wire          done
);


  reg  [1599:0] pad_state;
  reg  [1599:0] keccak_i;
  wire [1599:0] keccak_o;
  reg           keccak_start;
  wire          keccak_done;


  reg  [1599:0] squeeze_state;
  reg           squeeze_start;
  wire          squeeze_done;
  wire [255:0]  squeeze_output;


  reg [3:0] state;
  localparam STATE_IDLE    = 4'd0;
  localparam STATE_ABSORB  = 4'd1;
  localparam STATE_KECCAK  = 4'd2;
  localparam STATE_WAIT    = 4'd3;
  localparam STATE_SQUEEZE = 4'd4;
  localparam STATE_DONE    = 4'd5;


  keccak keccak_func (
    .clk    (clk),
    .resetn (resetn),
    .start  (keccak_start),
    .data_i (keccak_i),
    .data_o (keccak_o),
    .done   (keccak_done)
  );

  squeeze squeeze_func (
    .clk     (clk),
    .resetn  (resetn),
    .start   (squeeze_start),
    .state_i (squeeze_state),
    .data_o  (squeeze_output),
    .done    (squeeze_done)
  );


  always @(posedge clk) begin
    if (!resetn) begin
      state         <= STATE_IDLE;
      keccak_start  <= 1'b0;
      squeeze_start <= 1'b0;
      pad_state     <= 1600'b0;
    end else begin
      case (state)

        STATE_IDLE: begin
          if (start) state <= STATE_ABSORB;
        end


        STATE_ABSORB: begin
          pad_state <= {pad_state[1599:1088], pad_state[1087:0] ^ data_i};
          state     <= STATE_KECCAK;
        end


        STATE_KECCAK: begin
          keccak_start <= 1'b1;
          keccak_i     <= pad_state;
          state        <= STATE_WAIT;
        end


        STATE_WAIT: begin
          keccak_start <= 1'b0;
          if (keccak_done) begin
            squeeze_state <= keccak_o;
            state         <= STATE_SQUEEZE;
          end
        end


        STATE_SQUEEZE: begin
          squeeze_start <= 1'b1;
          if (squeeze_done) begin
            squeeze_start <= 1'b0;
            state         <= STATE_DONE;
          end
        end

        STATE_DONE: begin
          state <= STATE_IDLE;
        end

        default: state <= STATE_IDLE;
      endcase
    end
  end

  assign data_o = squeeze_output;
  assign done   = (state == STATE_DONE);

endmodule
