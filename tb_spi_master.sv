module tb_spi_master;

    localparam DATA_WIDTH = 8;
    localparam DIV_WIDTH  = 4;


    logic clk;
    logic rst_n;

    logic start;
    logic busy;
    logic done;

    logic cpol;
    logic cpha;

    logic [DATA_WIDTH-1:0] tx_data;
    logic [DATA_WIDTH-1:0] rx_data;

    logic sclk;
    logic cs_n;
    logic mosi;
    logic miso;


    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .DIV_WIDTH (DIV_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .start(start),
        .busy(busy),
        .done(done),

        .cpol(cpol),
        .cpha(cpha),

        .tx_data(tx_data),
        .rx_data(rx_data),

        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .miso(miso)
    );


    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    initial begin
        rst_n = 0;
        start = 0;
        cpol  = 0;
        cpha  = 0;
        tx_data = 0;

        #50;
        rst_n = 1;
    end

    logic [7:0] slave_tx;
    logic [7:0] slave_shift;
    logic [7:0] slave_rx;

    assign miso = slave_shift[7];

    always @(negedge sclk) begin
        if(!cs_n) begin
            slave_shift <= {slave_shift[6:0],1'b0};
        end
    end

    always @(posedge sclk) begin
        if(!cs_n) begin
            slave_rx <= {slave_rx[6:0],mosi};
        end
    end

    task automatic spi_transfer(
        input  [7:0] master_tx,
        input  [7:0] slave_data
    );
    begin

        tx_data     = master_tx;

        slave_tx    = slave_data;
        slave_shift = slave_data;
        slave_rx    = 0;

        @(posedge clk);
        start = 1;

        @(posedge clk);
        start = 0;

        wait(done);


        if(rx_data !== slave_data) begin
            $error("MASTER RX FAIL Expected=%h Actual=%h",
                    slave_data, rx_data);
        end
        else begin
            $display("MASTER RX PASS Expected=%h Actual=%h",
                      slave_data, rx_data);
        end

        if(slave_rx !== master_tx) begin
            $error("SLAVE RX FAIL Expected=%h Actual=%h",
                    master_tx, slave_rx);
        end
        else begin
            $display("SLAVE RX PASS Expected=%h Actual=%h",
                      master_tx, slave_rx);
        end

    end
    endtask

    initial begin

        wait(rst_n);

        spi_transfer(8'hA5, 8'h3C);

        spi_transfer(8'h55, 8'hAA);

        spi_transfer(8'hF0, 8'h0F);

        #100;


        $finish;
    end

endmodule