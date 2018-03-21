`timescale 1ns/10ps
module CLE ( clk, reset, rom_q, rom_a, sram_q, sram_a, sram_d, sram_wen, finish);
input            clk;
input            reset;
input    [ 7:0]  rom_q;
output   [ 6:0]  rom_a;
input    [ 7:0]  sram_q;
output   [ 9:0]  sram_a;
output   [ 7:0]  sram_d;
output           sram_wen;
output           finish;

//------ Addr send -----
//reg      [ 9:0]  read_addr;
wire     [ 9:0]  write_addr;
wire     [ 9:0]  read_addr;
reg      [40:0]  rd_buffer;
reg      [ 3:0]  cnt;
reg      [ 7:0]  index_cnt;
reg      [ 7:0]  index_buffer [0:32];
wire     [ 7:0]  current_index;
wire             en_rd;
reg              add_index_cnt;
reg              rw;
reg              high_reverse;
reg              low_reverse;
reg              rever_rst;
reg              rd_sram;
reg              w_rd_sram;
reg      [20:0]  times;
wire             hit_without_ref;

reg              cs;
reg              ns;

reg      [ 4:0]  rom_a_high;
reg      [ 1:0]  rom_a_low;
reg      [ 4:0]  write_addr_high;
reg      [ 4:0]  write_addr_low;
reg      [ 4:0]  read_addr_high;
reg      [ 4:0]  read_addr_low;
reg      [ 2:0]  re_cs;
reg      [ 2:0]  re_ns;

parameter        NO_REF_HIT       = 1'b0,
                 REF_HIT_OR_MISS  = 1'b1;

parameter [ 2:0] TOP_FORWARD      = 3'b000,
                 TOP_FORWARD2     = 3'b001,
                 TOP_BACKWARD     = 3'b010,
                 TOP_BACKWARD2    = 3'b011,
                 BOTTOM_FORWARD   = 3'b100,
                 BOTTOM_FORWARD2  = 3'b101,
                 BOTTOM_BACKWARD  = 3'b110,
                 BOTTOM_BACKWARD2 = 3'b111;

integer i;

assign en_rd = &cnt[3:1];
assign sram_d = index_buffer[0];
assign sram_a = rw ? write_addr : read_addr;
assign sram_wen = ~rw;
assign current_index = rd_buffer[ 7] & rd_sram ? sram_q : index_cnt;
assign finish = times == 7;
assign rom_a[6:2]      = high_reverse ? ~rom_a_high      : rom_a_high;
assign rom_a[1:0]      =  low_reverse ? ~rom_a_low       : rom_a_low;
assign read_addr[9:5]  = high_reverse ? ~read_addr_high  : read_addr_high;
assign read_addr[4:0]  =  low_reverse ? ~read_addr_low   : read_addr_low;
assign write_addr[9:5] = high_reverse ? ~write_addr_high : write_addr_high;
assign write_addr[4:0] =  low_reverse ? ~write_addr_low  : write_addr_low;


always @(posedge clk/* or posedge reset*/) begin
  if (reset)          times <= 'b0;
  else begin
    if (rever_rst) times <= times +'b1;
  end
end

always @(posedge clk) begin
  if (reset | rever_rst) {rom_a_high, rom_a_low, cnt} <= 'b0;
  else begin
    {rom_a_high, rom_a_low, cnt} <= {rom_a_high, rom_a_low, cnt} + 'b1;
  end
end

always @(posedge clk) begin
  if (reset | rever_rst) begin
    {write_addr_high, write_addr_low} <= 'h3D7;
    {read_addr_high, read_addr_low}   <= 'b0;
    rw                                <= 'b0;
  end
  else begin
    {write_addr_high, write_addr_low, rw} <= {write_addr_high, write_addr_low, rw} + 'b1;
    {read_addr_high, read_addr_low} <= {write_addr_high, write_addr_low} + 'h22;
  end
end

always @(posedge clk/* or posedge reset*/) begin
  if (reset) re_cs <= TOP_FORWARD;
  else       re_cs <= re_ns;
end

always @(*) begin
  re_ns = re_cs;
  case (re_cs)
    TOP_FORWARD: begin
      if (&write_addr & rw)
        re_ns = TOP_FORWARD2;
    end
    TOP_FORWARD2: begin
      if (&write_addr & rw)
        re_ns = TOP_BACKWARD;
    end
    TOP_BACKWARD: begin
      if (&write_addr[9:5] & ~|write_addr[4:0] & rw)
        re_ns = TOP_BACKWARD2;
    end
    TOP_BACKWARD2: begin
      if (&write_addr[9:5] & ~|write_addr[4:0] & rw)
        re_ns = BOTTOM_FORWARD;
    end
    BOTTOM_FORWARD: begin
      if (~|write_addr & rw)
        re_ns = BOTTOM_FORWARD2;
    end
    BOTTOM_FORWARD2: begin
      if (~|write_addr & rw)
        re_ns = BOTTOM_BACKWARD;
    end
    BOTTOM_BACKWARD: begin
      if (~|write_addr[9:5] & (&write_addr[4:0]) & rw)
        re_ns = BOTTOM_BACKWARD2;
    end
    BOTTOM_BACKWARD2: begin
      if (~|write_addr[9:5] & (&write_addr[4:0]) & rw)
        re_ns = TOP_FORWARD;
    end
  endcase
end

always @(*) begin
  high_reverse = 'b0;
  low_reverse  = 'b0;
  rever_rst    = 'b0;
  w_rd_sram    = 'b0;
  case (re_cs)
    TOP_FORWARD: begin
      high_reverse = 'b0;
      low_reverse  = 'b0;
    end
    TOP_FORWARD2: begin
      high_reverse = 'b0;
      low_reverse  = 'b0;
      if (&write_addr & rw) rever_rst = 'b1;
    end
    TOP_BACKWARD: begin
      w_rd_sram = 'b1;
      high_reverse = 'b0;
      low_reverse  = 'b1;
    end
    TOP_BACKWARD2: begin
      high_reverse = 'b0;
      low_reverse  = 'b1;
      if (&write_addr[9:5] & ~|write_addr[4:0] & rw) rever_rst = 'b1;
    end
    BOTTOM_FORWARD: begin
      high_reverse = 'b1;
      low_reverse  = 'b0;
    end
    BOTTOM_FORWARD2: begin
      high_reverse = 'b1;
      low_reverse  = 'b0;
      if (~|write_addr & rw) rever_rst = 'b1;
    end
    BOTTOM_BACKWARD: begin
      high_reverse = 'b1;
      low_reverse  = 'b1;
    end
    BOTTOM_BACKWARD2: begin
      high_reverse = 'b1;
      low_reverse  = 'b1;
      if (~|write_addr[9:5] & (&write_addr[4:0]) & rw) rever_rst = 'b1;
    end
  endcase
end

always @(posedge clk) begin
  if (reset)          rd_sram <= 'b0;
  else if (w_rd_sram) rd_sram <= 'b1;
end

// --- FSM ---
always @(posedge clk/* or posedge reset*/) begin
  if (reset) cs <= NO_REF_HIT;
  else       cs <= ns;
end

assign hit_without_ref = ~(rd_buffer[8] | rd_buffer[40] | rd_buffer[39] | rd_buffer[38]) & rd_buffer[7];

always @(*) begin
  ns = cs;
  case (cs)
    NO_REF_HIT: begin
      ns = REF_HIT_OR_MISS;
    end
    REF_HIT_OR_MISS: begin
      if (hit_without_ref) ns = NO_REF_HIT;
    end
  endcase
end

always @(*) begin
  add_index_cnt = 'b0;
  case (cs)
    NO_REF_HIT: begin
      add_index_cnt = 'b1;
    end
    REF_HIT_OR_MISS: begin
    end
  endcase
end

// -----------



always @(posedge clk/* or posedge reset*/) begin
  if (reset)   rd_buffer <= 'b0;
  else begin
    if (cnt[0]) begin
      if (en_rd) rd_buffer[7:0] <= low_reverse ? {rom_q[0], rom_q[1], rom_q[2], rom_q[3], rom_q[4], rom_q[5], rom_q[6], rom_q[7]}: rom_q;
      else begin
        for (i = 1; i < 8; i = i + 1) begin
          rd_buffer[i] <= rd_buffer[i - 1];
        end
      end
      for (i = 8; i < 41; i = i + 1) begin
        rd_buffer[i] <= rd_buffer[i - 1];
      end
    end
  end
end


always @(posedge clk/* or posedge reset*/) begin
  if (reset)           index_cnt <= 'b0;
  else begin
    if (add_index_cnt) index_cnt <= index_cnt + 'b1;
  end
end

always @(posedge clk/* or posedge reset*/) begin
  if (reset) begin
    for (i = 0; i < 33; i = i + 1) begin
      index_buffer[i] <= 'b0;
    end
  end
  else begin
    if (cnt[0]) begin
      index_buffer[32] <= (rd_buffer[7]) ? current_index : 'b0;
      index_buffer[31] <= (rd_buffer[40] & index_buffer[ 0] < index_buffer[32]) ? index_buffer[ 0] : index_buffer[32];
      index_buffer[30] <= (rd_buffer[40] & index_buffer[ 0] < index_buffer[31]) ? index_buffer[ 0] : index_buffer[31];
      index_buffer[29] <= (rd_buffer[40] & index_buffer[ 0] < index_buffer[30]) ? index_buffer[ 0] : index_buffer[30];
      index_buffer[28] <= (rd_buffer[12] & index_buffer[28] < index_buffer[29]) ? index_buffer[28] : index_buffer[29];
      for (i = 0; i < 28; i = i + 1) begin
        index_buffer[i] <= index_buffer[i + 1];
      end
    end
  end
end



endmodule
