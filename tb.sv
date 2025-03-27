class transaction;
  rand bit [31:0] paddr;
  rand bit [7:0] pwdata;
  rand bit psel;
  rand bit penable;
  randc bit pwrite;
  bit[7:0] prdata;
  bit pready;
  bit pslverr;
  
  constraint addr_c {
  paddr>=0; paddr<=15;
  }
  
  constraint data_c{
  pwdata>00; pwdata<=255;
  }
  
  function void display(input string tag);
    $display("[%0s] : PAddress = %0d, Pwdata = %0d, Pwrite = %0d, Prdata = %0d, pslverr = %0d @time = %0t", tag,paddr,pwdata,pwrite,prdata,pslverr,$time);
  endfunction
  
endclass

class generator;
  transaction tr;
  mailbox #(transaction) mbx;
  int count = 0;
  
  event drvnext;
  event sconext;
  event done;
  
  function new(mailbox #(transaction) mbx);
    this.mbx=mbx;
    tr=new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(tr.randomize) else $error("Randomization Failed");
      mbx.put(tr);
      tr.display("GEN");
      @(drvnext);
      @(sconext);
    end
    ->done;
  endtask
 endclass

class driver;
  virtual apb_if vif;
  mailbox #(transaction) mbx;
  transaction dtr;
  
  event drvnext;
  
  function new(mailbox #(transaction) mbx);
    this.mbx=mbx;
  endfunction;
  
  task reset();
    vif.presetn<=1'b0;
    vif.psel<=0;
    vif.penable<=0;
    vif.pwdata<=0;
    vif.paddr<=0;
    vif.pwrite<=0;
    repeat(5) @(posedge vif.pclk);
    vif.presetn<=1;
    $display("[DRV] : Reset Done");
    $display("-------------------------------------");
  endtask
  
  task run();
    forever begin
      mbx.get(dtr);
      @(posedge vif.pclk);
      if(dtr.pwrite==1)
        begin
          vif.psel<=1;
          vif.penable<=0;
          vif.pwdata<=dtr.pwdata;
          vif.paddr<=dtr.paddr;
          vif.pwrite<=1;
          @(posedge vif.pclk);
          vif.penable<=1;
          @(posedge vif.pclk);
          vif.psel<=0;
          vif.penable<=0;
          vif.pwrite<=0;
          dtr.display("DRV");
          ->drvnext;
        end
      else if(dtr.pwrite==0) begin
        vif.psel<=1;
        vif.penable<=0;
        vif.pwdata<=0;
        vif.paddr<=dtr.paddr;
        vif.pwrite<=0;
        @(posedge vif.pclk);
        vif.penable<=1;
        @(posedge vif.pclk);
        vif.psel<=0;
        vif.penable<=0;
        vif.pwrite<=0;
        dtr.display("DRV");
        ->drvnext;
      end
    end
  endtask
endclass

class monitor;
  virtual apb_if vif;
  mailbox #(transaction) mbx;
  transaction tr;
  
  function new(mailbox #(transaction) mbx);
    this.mbx=mbx;
  endfunction
  
  task run();
    tr=new();
    forever begin
      @(posedge vif.pclk);
      if(vif.pready)begin
        tr.pwdata=vif.pwdata;
        tr.paddr=vif.paddr;
        tr.pwrite=vif.pwrite;
        tr.prdata=vif.prdata;
        tr.pslverr=vif.pslverr;
        @(posedge vif.pclk);
        tr.display("MON");
        mbx.put(tr);
      end
    end
  endtask
endclass

class scoreboard;
  mailbox #(transaction) mbx;
  transaction tr;
  event sconext;
  bit[7:0] pwdata[16]='{default:0};
  bit[7:0] rdata;
  int err=0;
  
  function new(mailbox #(transaction) mbx);
    this.mbx=mbx;
  endfunction
  
  task run();
    forever begin
      mbx.get(tr);
      tr.display("SCO");
      
      if((tr.pwrite)&&(!tr.pslverr))
        begin
          pwdata[tr.paddr]=tr.pwdata;
          $display("[SCO] : Data Stored, Data = %0d, Address = %0d",tr.pwdata,tr.paddr);
        end
      else if((!tr.pwrite)&&(!tr.pslverr))
        begin
          rdata=pwdata[tr.paddr];
          if(tr.prdata==rdata)
            $display("[SCO] : Data Matched");
          else begin
          err++;
            $display("[SCO] : Data Matched");
          end
         end
      else if(tr.pslverr) $display("[SCO] : SLV Error Detected");
    $display("-----------------------------------------");
    ->sconext;
    end
  endtask
endclass

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event nextgd;
  event nextgs;
  mailbox #(transaction) mbxgd,mbxms;
  
  virtual apb_if vif;
  
  function new(virtual apb_if vif);
    mbxgd=new();
    mbxms=new();
    
    gen=new(mbxgd);
    drv=new(mbxgd);
    mon=new(mbxms);
    sco=new(mbxms);
    
    this.vif=vif;
    drv.vif=this.vif;
    mon.vif=this.vif;
    
    gen.sconext=nextgs;
    sco.sconext=nextgs;
    
    gen.drvnext=nextgd;
    drv.drvnext=nextgd;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $display("Total Number of Mismatch = %0d", sco.err);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

module tb;
  apb_if vif();
  environment env;
  
  apb_slave dut(vif.pclk,vif.presetn,vif.psel,vif.penable,
vif.pwrite,vif.paddr,vif.pwdata,vif.pslverr,vif.prdata,vif.pready);
  
  initial begin
    vif.pclk<=0;
  end
  
  always #10 vif.pclk=~vif.pclk;
  
  initial begin
    env=new(vif);
    env.gen.count<=15;
    env.run();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
  
endmodule