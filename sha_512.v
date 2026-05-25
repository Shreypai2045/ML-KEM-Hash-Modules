`timescale 1ns/1ps

module sha3_512 (
  input  wire          clk,
  input  wire          resetn,
  input  wire          start,
  input  wire [1087:0] data_in,
  output wire [511:0]  hash_out,
  output wire          done
);
  localparam RATE = 1088;

  reg  [1599:0] state;
  wire [1599:0] keccak_out;
  reg           keccak_start;
  wire          keccak_done;


  wire [1087:0] padded_block = {data_in[1087:1], 1'b1};

  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      state        <= 1600'b0;
      keccak_start <= 1'b0;
    end else if (start) begin
      state[RATE-1:0] <= state[RATE-1:0] ^ padded_block;
      keccak_start    <= 1'b1;
    end else begin
      keccak_start <= 1'b0;
    end
  end

  keccak uut_keccak (
    .clk    (clk),
    .resetn (resetn),
    .start  (keccak_start),
    .data_i (state),
    .data_o (keccak_out),
    .done   (keccak_done)
  );

  assign done     = keccak_done;
  assign hash_out = keccak_out[511:0];

endmodule

module sha_mux (
  input  wire          clk,
  input  wire          resetn,
  input  wire          start,
  input  wire          sel,
  input  wire [1087:0] data_in,
  output reg  [511:0]  digest_out,
  output reg           done
);


  wire [255:0] sha256_out;
  wire         sha256_done;
  reg          start256;


  wire [511:0] sha512_out;
  wire         sha512_done;
  reg          start512;


  sha_256 u_sha256 (
    .clk    (clk),
    .resetn (resetn),
    .start  (start256),
    .data_i (data_in),
    .data_o (sha256_out),
    .done   (sha256_done)
  );

  sha3_512 u_sha512 (
    .clk     (clk),
    .resetn  (resetn),
    .start   (start512),
    .data_in (data_in),
    .hash_out(sha512_out),
    .done    (sha512_done)
  );


  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      start256   <= 1'b0;
      start512   <= 1'b0;
      digest_out <= 512'b0;
      done       <= 1'b0;
    end else begin

      done     <= 1'b0;
      start256 <= 1'b0;
      start512 <= 1'b0;


      if (start) begin
        if (sel == 1'b0) start256 <= 1'b1;
        else             start512 <= 1'b1;
      end


      if (sha256_done && sel == 1'b0) begin
        digest_out[255:0]   <= sha256_out;
        digest_out[511:256] <= 256'b0;
        done                <= 1'b1;
      end


      if (sha512_done && sel == 1'b1) begin
        digest_out <= sha512_out;
        done       <= 1'b1;
      end
    end
  end

endmodule
