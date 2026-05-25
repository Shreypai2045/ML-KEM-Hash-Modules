`timescale 1ns/1ps

module tb_sha_combined;




  reg clk;
  initial clk = 0;
  always #5 clk = ~clk;




  integer pass_count;
  integer fail_count;
  integer test_num;




  reg          resetn;
  reg          sha_start;
  reg  [1087:0] sha_data_in;
  wire [255:0]  sha_digest_out;
  wire          sha_done;

  sha_256 u_sha256 (
    .clk    (clk),
    .resetn (resetn),
    .start  (sha_start),
    .data_i (sha_data_in),
    .data_o (sha_digest_out),
    .done   (sha_done)
  );




  reg        sk_rst_n;
  reg  [7:0] sk_in_data;
  reg        sk_in_valid;
  reg        sk_in_last;
  reg [15:0] sk_d_out_bytes;
  reg        sk_start;
  wire [7:0] sk_out_data;
  wire       sk_out_valid;
  wire       sk_ready;
  wire       sk_busy;

  shake128 u_shake128 (
    .clk        (clk),
    .rst_n      (sk_rst_n),
    .in_data    (sk_in_data),
    .in_valid   (sk_in_valid),
    .in_last    (sk_in_last),
    .d_out_bytes(sk_d_out_bytes),
    .start      (sk_start),
    .out_data   (sk_out_data),
    .out_valid  (sk_out_valid),
    .ready      (sk_ready),
    .busy       (sk_busy)
  );


  reg [7:0] sk_buf [0:63];
  integer   sk_collected;




  initial begin
    #500000;
    $display("ERROR: Timeout!  PASS=%0d FAIL=%0d", pass_count, fail_count);
    $finish;
  end




  initial begin
    $dumpfile("tb_sha_combined.vcd");
    $dumpvars(0, tb_sha_combined);

    pass_count = 0;
    fail_count = 0;


    resetn         = 0;
    sk_rst_n       = 0;
    sha_start      = 0;
    sha_data_in    = 1088'b0;
    sk_start       = 0;
    sk_in_valid    = 0;
    sk_in_last     = 0;
    sk_in_data     = 8'h00;
    sk_d_out_bytes = 16'd0;
    #20;
    resetn   = 1;
    sk_rst_n = 1;
    #20;






    test_num    = 1;
    sha_data_in = 1088'h0;
    sha256_run(
      256'h80acb2a6809132c0fdaa14303de3373818181d6f49fe10946d7961c32165296e
    );
    #50;


    test_num    = 2;
    sha_data_in = 1088'b0;
    sha_data_in[127:0] = 128'hDEADBEEFDEADBEEFDEADBEEFDEADBEEF;
    sha256_run(
      256'h380098054cc9ac62d7c42f9547590e320e5271f3b176aabaf7aa800eae7ff9b0
    );
    #50;






    test_num = 3;
    shake_run_and_check(
      8'hAB, 8'h00, 8'h00, 3'd1,
      16'd32,
      256'hccbdcd3c537250135b123702f9dd9b25c941ed75b36de1b3c2cc4ef08c2ca133
    );
    #50;


    test_num = 4;
    shake_run_and_check(
      8'h61, 8'h62, 8'h63, 3'd3,
      16'd32,
      256'h90f9b13ceea5b2ead0c0c28b267d742f8dc13f499f9f47e0d24fab4683df6d21
    );
    #50;




    test_num = 5;
    shake_run_and_check(
      8'hFF, 8'h00, 8'h00, 3'd1,
      16'd16,
      256'hb1f6fd67c3f62993d323475ce7350e7400000000000000000000000000000000
    );
    #50;


    test_num = 6;
    shake_run_and_check(
      8'hAB, 8'hCD, 8'hEF, 3'd3,
      16'd32,
      256'hf5d22cad2cdc34fe7f510953ee701e72f06780553d5ee23922f68ee0cf6d7678
    );
    #200;


    $display("---------------------------------------------");
    $display("Simulation complete.  PASS: %0d   FAIL: %0d",
             pass_count, fail_count);
    if (fail_count == 0)
      $display("ALL TESTS PASSED");
    else
      $display("SOME TESTS FAILED");
    $display("---------------------------------------------");
    $finish;
  end





  task sha256_run;
    input [255:0] expected;
    reg   [255:0] got;
    begin
      @(negedge clk); sha_start = 1;
      @(negedge clk); sha_start = 0;

      @(posedge clk);
      while (sha_done !== 1'b1) @(posedge clk);

      got = sha_digest_out;

      if (got === expected) begin
        pass_count = pass_count + 1;
        $display("TV%0d PASS | SHA3-256 | digest = %h", test_num, got);
      end else begin
        fail_count = fail_count + 1;
        $display("TV%0d FAIL | SHA3-256", test_num);
        $display("  expected = %h", expected);
        $display("  got      = %h", got);
      end
      @(posedge clk);
    end
  endtask










  task shake_run_and_check;
    input [7:0]  msg0, msg1, msg2;
    input [2:0]  msg_len;
    input [15:0] d_out;
    input [255:0] expected;

    integer i;
    reg [7:0]  msg_arr [0:2];
    reg [255:0] got;
    reg ok;
    begin
      msg_arr[0] = msg0;
      msg_arr[1] = msg1;
      msg_arr[2] = msg2;


      for (i = 0; i < 64; i = i+1) sk_buf[i] = 8'h00;
      sk_collected = 0;


      sk_d_out_bytes = d_out;
      @(negedge clk); sk_start = 1;
      @(negedge clk); sk_start = 0;


      for (i = 0; i < msg_len; i = i+1) begin
        @(negedge clk);
        sk_in_data  = msg_arr[i];
        sk_in_valid = 1'b1;
        sk_in_last  = (i == msg_len - 1) ? 1'b1 : 1'b0;
      end
      @(negedge clk);
      sk_in_valid = 1'b0;
      sk_in_last  = 1'b0;
      sk_in_data  = 8'h00;


      begin : collect
        forever begin
          @(posedge clk);
          if (sk_out_valid && sk_collected < 64) begin
            sk_buf[sk_collected] = sk_out_data;
            sk_collected         = sk_collected + 1;
          end
          if (sk_collected >= d_out) disable collect;
        end
      end
      @(posedge clk);


      got = 256'h0;
      for (i = 0; i < 32; i = i+1)
        got[255 - 8*i -: 8] = sk_buf[i];


      ok = 1'b1;
      for (i = 0; i < d_out && i < 32; i = i+1)
        if (got[255 - 8*i -: 8] !== expected[255 - 8*i -: 8])
          ok = 1'b0;

      if (ok) begin
        pass_count = pass_count + 1;
        $display("TV%0d PASS | SHAKE128 | %0d bytes | first8 = %h ...",
                 test_num, d_out, got[255:192]);
      end else begin
        fail_count = fail_count + 1;
        $display("TV%0d FAIL | SHAKE128 | %0d bytes", test_num, d_out);
        $display("  expected = %h", expected);
        $display("  got      = %h", got);
      end
    end
  endtask

endmodule
