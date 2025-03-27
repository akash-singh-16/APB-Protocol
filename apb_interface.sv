interface apb_if;
  logic pclk;
  logic presetn;
  logic [31:0] paddr;
  logic psel;
  logic penable;
  logic [7:0] pwdata;
  logic pwrite;
  logic [7:0] prdata;
  logic pready;
  logic pslverr;
endinterface
