module shake128 (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [7:0]   in_data,
    input  wire         in_valid,
    input  wire         in_last,
    input  wire [15:0]  d_out_bytes,
    input  wire         start,
    output reg  [7:0]   out_data,
    output reg          out_valid,
    output reg          ready,
    output reg          busy
);


    localparam integer KECCAK_RATE_BYTES_128 = 168;
    localparam integer RATE_BYTES = KECCAK_RATE_BYTES_128;
    localparam integer RATE_MAX_IDX = RATE_BYTES - 1;

    localparam S_IDLE            = 4'd0;
    localparam S_ABSORB_INPUT    = 4'd1;
    localparam S_PAD_SUFFIX      = 4'd2;
    localparam S_PAD_ZEROS       = 4'd3;
    localparam S_PAD_LAST_ONE    = 4'd4;
    localparam S_PERMUTE_WAIT    = 4'd5;
    localparam S_AFTER_PERMUTE   = 4'd6;
    localparam S_SQUEEZE_CHECK   = 4'd7;
    localparam S_SQUEEZE_BYTE    = 4'd8;
    localparam S_PERMUTE_FOR_SQ  = 4'd9;
    localparam S_DONE            = 4'd10;

    reg [3:0] state;

    reg [1599:0] state_reg;

    reg [7:0]  byte_in_block_counter;
    reg [15:0] output_byte_counter;
    reg [15:0] d_out_reg;

    reg need_suffix_after_permute;

    reg  keccak_start;
    wire keccak_done;
    wire [1599:0] keccak_data_o;

    keccak keccak (
        .clk(clk),
        .resetn(rst_n),
        .start(keccak_start),
        .data_i(state_reg),
        .data_o(keccak_data_o),
        .done(keccak_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            state_reg <= {1600{1'b0}};
            byte_in_block_counter <= 8'd0;
            output_byte_counter <= 16'd0;
            d_out_reg <= 16'd0;
            need_suffix_after_permute <= 1'b0;
            ready <= 1'b1;
            busy <= 1'b0;
            out_valid <= 1'b0;
            out_data <= 8'd0;
            keccak_start <= 1'b0;
        end else begin
            keccak_start <= 1'b0;
            out_valid <= 1'b0;
            out_data <= 8'd0;
            ready <= (state == S_IDLE);

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        state_reg <= {1600{1'b0}};
                        byte_in_block_counter <= 8'd0;
                        output_byte_counter <= 16'd0;
                        d_out_reg <= d_out_bytes;
                        need_suffix_after_permute <= 1'b0;
                        busy <= 1'b1;
                        state <= S_ABSORB_INPUT;
                    end
                end

                S_ABSORB_INPUT: begin
                    if (in_valid) begin
                        state_reg[byte_in_block_counter*8 +: 8] <= state_reg[byte_in_block_counter*8 +: 8] ^ in_data;

                        if (in_last) begin
                            if (byte_in_block_counter == RATE_MAX_IDX) begin
                                byte_in_block_counter <= 8'd0;
                                need_suffix_after_permute <= 1'b1;
                                keccak_start <= 1'b1;
                                state <= S_PERMUTE_WAIT;
                            end else begin
                                byte_in_block_counter <= byte_in_block_counter + 1'b1;
                                need_suffix_after_permute <= 1'b0;
                                state <= S_PAD_SUFFIX;
                            end
                        end else begin
                            if (byte_in_block_counter == RATE_MAX_IDX) begin
                                byte_in_block_counter <= 8'd0;
                                need_suffix_after_permute <= 1'b0;
                                keccak_start <= 1'b1;
                                state <= S_PERMUTE_WAIT;
                            end else begin
                                byte_in_block_counter <= byte_in_block_counter + 1'b1;
                                state <= S_ABSORB_INPUT;
                            end
                        end
                    end
                end

                S_PAD_SUFFIX: begin
                    state_reg[byte_in_block_counter*8 +: 8] <= state_reg[byte_in_block_counter*8 +: 8] ^ 8'h1F;

                    if (byte_in_block_counter == RATE_MAX_IDX) begin
                        byte_in_block_counter <= 8'd0;
                        keccak_start <= 1'b1;
                        state <= S_PERMUTE_WAIT;
                    end else begin
                        byte_in_block_counter <= byte_in_block_counter + 1'b1;
                        state <= S_PAD_ZEROS;
                    end
                end

                S_PAD_ZEROS: begin
                    if (byte_in_block_counter == RATE_MAX_IDX - 1) begin
                        state <= S_PAD_LAST_ONE;
                    end else begin
                        byte_in_block_counter <= byte_in_block_counter + 1'b1;
                        state <= S_PAD_ZEROS;
                    end
                end

                S_PAD_LAST_ONE: begin
                    state_reg[RATE_MAX_IDX*8 +: 8] <= state_reg[RATE_MAX_IDX*8 +: 8] ^ 8'h80;
                    byte_in_block_counter <= 8'd0;
                    keccak_start <= 1'b1;
                    state <= S_PERMUTE_WAIT;
                end

                S_PERMUTE_WAIT: begin
                    if (keccak_done) begin
                        state_reg <= keccak_data_o;
                        state <= S_AFTER_PERMUTE;
                    end else begin
                        state <= S_PERMUTE_WAIT;
                    end
                end

                S_AFTER_PERMUTE: begin
                    if (need_suffix_after_permute) begin
                        need_suffix_after_permute <= 1'b0;
                        state <= S_PAD_SUFFIX;
                    end else begin
                        if (d_out_reg == 16'd0) begin
                            state <= S_ABSORB_INPUT;
                        end else begin
                            byte_in_block_counter <= 8'd0;
                            state <= S_SQUEEZE_CHECK;
                        end
                    end
                end

                S_SQUEEZE_CHECK: begin
                    if (output_byte_counter >= d_out_reg) begin
                        state <= S_DONE;
                    end else if (byte_in_block_counter >= RATE_BYTES) begin
                        byte_in_block_counter <= 8'd0;
                        keccak_start <= 1'b1;
                        state <= S_PERMUTE_FOR_SQ;
                    end else begin
                        state <= S_SQUEEZE_BYTE;
                    end
                end

                S_SQUEEZE_BYTE: begin
                    out_data <= state_reg[byte_in_block_counter*8 +: 8];
                    out_valid <= 1'b1;
                    output_byte_counter <= output_byte_counter + 1'b1;
                    byte_in_block_counter <= byte_in_block_counter + 1'b1;
                    state <= S_SQUEEZE_CHECK;
                end

                S_PERMUTE_FOR_SQ: begin
                    if (keccak_done) begin
                        state_reg <= keccak_data_o;
                        byte_in_block_counter <= 8'd0;
                        state <= S_SQUEEZE_CHECK;
                    end else begin
                        state <= S_PERMUTE_FOR_SQ;
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    ready <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
