`timescale 1ns/1ps

module keccak(
    input  wire          clk,
    input  wire          resetn,
    input  wire          start,
    input  wire [1599:0] data_i,
    output wire [1599:0] data_o,
    output reg           done
);

  function [63:0] rot;
    input [63:0] A;
    input [5:0]  offset;
    begin
      rot = (A << offset) | (A >> (64 - offset));
    end
  endfunction

  reg [5:0] rot_offset [0:24];
  initial begin
    rot_offset[0]=6'd0;  rot_offset[1]=6'd1;  rot_offset[2]=6'd62;
    rot_offset[3]=6'd28; rot_offset[4]=6'd27; rot_offset[5]=6'd36;
    rot_offset[6]=6'd44; rot_offset[7]=6'd6;  rot_offset[8]=6'd55;
    rot_offset[9]=6'd20; rot_offset[10]=6'd3; rot_offset[11]=6'd10;
    rot_offset[12]=6'd43;rot_offset[13]=6'd25;rot_offset[14]=6'd39;
    rot_offset[15]=6'd41;rot_offset[16]=6'd45;rot_offset[17]=6'd15;
    rot_offset[18]=6'd21;rot_offset[19]=6'd8; rot_offset[20]=6'd18;
    rot_offset[21]=6'd2; rot_offset[22]=6'd61;rot_offset[23]=6'd56;
    rot_offset[24]=6'd14;
  end

  reg [63:0] RC [0:23];
  initial begin
    RC[0]=64'h0000000000000001; RC[1]=64'h0000000000008082;
    RC[2]=64'h800000000000808A; RC[3]=64'h8000000080008000;
    RC[4]=64'h000000000000808B; RC[5]=64'h0000000080000001;
    RC[6]=64'h8000000080008081; RC[7]=64'h8000000000008009;
    RC[8]=64'h000000000000008A; RC[9]=64'h0000000000000088;
    RC[10]=64'h0000000080008009;RC[11]=64'h000000008000000A;
    RC[12]=64'h000000008000808B;RC[13]=64'h800000000000008B;
    RC[14]=64'h8000000000008089;RC[15]=64'h8000000000008003;
    RC[16]=64'h8000000000008002;RC[17]=64'h8000000000000080;
    RC[18]=64'h000000000000800A;RC[19]=64'h800000008000000A;
    RC[20]=64'h8000000080008081;RC[21]=64'h8000000000008080;
    RC[22]=64'h0000000080000001;RC[23]=64'h8000000080008008;
  end



  reg [63:0] arr_A [0:24];
  reg [63:0] arr_B [0:24];
  reg [63:0] arr_C [0:4];
  reg [63:0] arr_D [0:4];

  reg [3:0]  state;
  reg [4:0]  round_index;
  reg [1599:0] data_o_reg;

  integer i, j, idx, tmp, newy;
  integer chi_ip1, chi_ip2;

  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      state       <= 4'd8;
      round_index <= 5'd0;
      done        <= 1'b0;
      data_o_reg  <= 1600'b0;
      for (i=0; i<5;  i=i+1) begin arr_C[i] <= 64'b0; arr_D[i] <= 64'b0; end
      for (i=0; i<25; i=i+1) begin arr_A[i] <= 64'b0; arr_B[i] <= 64'b0; end
    end else begin
      case (state)


        4'd8: begin
          done <= 1'b0;
          if (start) begin round_index <= 5'd0; state <= 4'd0; end
        end


        4'd0: begin
          for (i=0; i<25; i=i+1)
            arr_A[i] <= data_i[64*i +: 64];
          state <= 4'd1;
        end


        4'd1: begin
          for (i=0; i<5; i=i+1)
            arr_C[i] <= arr_A[5*i+0]^arr_A[5*i+1]^arr_A[5*i+2]
                       ^arr_A[5*i+3]^arr_A[5*i+4];
          state <= 4'd2;
        end


        4'd2: begin
          for (i=0; i<5; i=i+1) begin
            if (i==0) tmp = 4; else tmp = i-1;
            arr_D[i] <= arr_C[tmp] ^ rot(arr_C[(i==4 ? 0 : i+1)], 1);
          end
          state <= 4'd3;
        end


        4'd3: begin
          for (i=0; i<5; i=i+1)
            for (j=0; j<5; j=j+1)
              arr_A[5*i+j] <= arr_A[5*i+j] ^ arr_D[i];
          state <= 4'd4;
        end


        4'd4: begin
          for (i=0; i<5; i=i+1)
            for (j=0; j<5; j=j+1) begin
              idx  = 5*i + j;
              tmp  = 2*i + 3*j;
              if      (tmp >= 15) newy = tmp - 15;
              else if (tmp >= 10) newy = tmp - 10;
              else if (tmp >= 5)  newy = tmp - 5;
              else                newy = tmp;
              arr_B[5*j+newy] <= rot(arr_A[idx], rot_offset[idx]);
            end
          state <= 4'd5;
        end


        4'd5: begin
          for (i=0; i<5; i=i+1) begin
            chi_ip1 = (i==4) ? 0 : i+1;
            chi_ip2 = (i>=3) ? i-3 : i+2;
            for (j=0; j<5; j=j+1)
              arr_A[5*i+j] <= arr_B[5*i+j] ^
                              ((~arr_B[5*chi_ip1+j]) & arr_B[5*chi_ip2+j]);
          end
          state <= 4'd6;
        end


        4'd6: begin
          arr_A[0] <= arr_A[0] ^ RC[round_index];
          if (round_index == 5'd23) state <= 4'd7;
          else begin round_index <= round_index + 1; state <= 4'd1; end
        end


        4'd7: begin
          for (i=0; i<25; i=i+1)
            data_o_reg[64*i +: 64] <= arr_A[i];
          done  <= 1'b1;
          state <= 4'd8;
        end

        default: state <= 4'd8;
      endcase
    end
  end

  assign data_o = data_o_reg;


  always @(posedge clk)
    if (resetn)
      $display("T=%0t : keccak_state=%0d  round=%0d  done=%b",
               $time, state, round_index, done);


endmodule

module squeeze(
  input  wire          clk,
  input  wire          resetn,
  input  wire          start,
  input  wire [1599:0] state_i,
  output reg  [255:0]  data_o,
  output reg           done
);

  localparam SQ_IDLE    = 2'd0;
  localparam SQ_EXTRACT = 2'd1;
  localparam SQ_DONE    = 2'd2;

  reg [1:0] sq_state;

  always @(posedge clk) begin
    if (!resetn) begin
      sq_state <= SQ_IDLE;
      data_o   <= 256'b0;
      done     <= 1'b0;
    end else begin
      case (sq_state)
        SQ_IDLE:    begin done <= 1'b0; if (start) sq_state <= SQ_EXTRACT; end
        SQ_EXTRACT: begin data_o <= state_i[255:0]; sq_state <= SQ_DONE; end
        SQ_DONE:    begin done <= 1'b1; sq_state <= SQ_IDLE; end
        default:    sq_state <= SQ_IDLE;
      endcase
    end
  end

endmodule
