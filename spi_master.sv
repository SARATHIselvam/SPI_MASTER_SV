module spi_master #(
	parameter DATA_WIDTH = 8,
	parameter DIV_WIDTH = 8)
(

	input logic clk,
	input logic rst_n,
//control signals	
	input logic start,
	output logic busy,
	output logic done,
// config signals	
	input logic cpol,
	input logic cpha,
	
	input logic [DATA_WIDTH - 1: 0] tx_data,
	output logic [DATA_WIDTH - 1: 0] rx_data,
	
	output logic sclk,
	output logic cs_n,
	output logic mosi,
	input logic miso
	);
	
	logic [DIV_WIDTH -1:0] div_cnt;
	logic spi_tick;
	
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			div_cnt <= '0;
			spi_tick <= 1'b0;
		end
		else if (busy) begin
			if(div_cnt == '1)begin
				div_cnt <=0;
				spi_tick <= 1'b1;
			end else begin
				div_cnt <= div_cnt + 1'b1;
				spi_tick <=0;
				end
		end
		else begin
			div_cnt <= 0;
			spi_tick <= 0;
		end
	end
	
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			sclk <= 1'b0;
		end
		else if(!busy) begin
			sclk <= cpol;
		end
		else if(spi_tick) begin
			sclk <= ~sclk;
		end
	end
	
	typedef enum logic [1:0]{
		IDLE,
		TRANSFER,
		DONE
	} state_t;
	
	state_t current_state, next_state;
	
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			current_state <= IDLE;
		end
		else begin
			current_state <= next_state;
		end
	end
	
	logic sclk_d;
	
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			sclk_d<=0;
		end
		else begin
			sclk_d <= sclk;
		end
	end
	
	wire sclk_rise = (sclk && !sclk_d);
	wire sclk_fall = (!sclk && sclk_d);
	
	wire sample_en = (cpha == 1'b0)?sclk_rise: sclk_fall;
	wire shift_en = (cpha == 1'b0)? sclk_fall: sclk_rise;
	
	logic [DATA_WIDTH-1:0] tx_shift;
	logic [DATA_WIDTH-1:0]rx_shift;
	
	logic [$clog2(DATA_WIDTH+1)-1:0] bit_cnt;
	
	always_comb begin
		next_state = current_state;
		
		case(current_state)
		
		IDLE: begin
			if(start)
				next_state = TRANSFER;
			else
				next_state = IDLE;
		end
		TRANSFER: begin
			if(bit_cnt == 0)
				next_state = DONE;
			else
				next_state = TRANSFER;
		end
		DONE: begin
			next_state = IDLE;
		end
		endcase
	end
	
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			busy <= 1'b0;
			done <= 1'b0;
			cs_n <= 1'b1;
			mosi <= 1'b0;
			
			tx_shift <= '0;
			rx_shift <= '0;
			rx_data <= '0;
			bit_cnt <= '0;
		end
		else begin
			done <= 1'b0;
			case(current_state)
				IDLE: begin
					busy <= 1'b0;
					cs_n <= 1'b1;
					if(start) begin
						tx_shift <= tx_data;
						rx_shift <= 0;
						bit_cnt <= DATA_WIDTH;
						
						if(cpha == 1'b0)
							mosi <= tx_data[DATA_WIDTH-1];
					end
					
				end
				TRANSFER: begin
					busy <= 1'b1;
					if(sample_en) begin
						rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
					end
					if(shift_en)begin
						mosi <= tx_shift[DATA_WIDTH-1];
						tx_shift <= {tx_shift[DATA_WIDTH-2:0],1'b0};
					end
					if(shift_en && bit_cnt >0)
						bit_cnt <= bit_cnt - 1'b1;
				end
				DONE: begin
					busy <= 1'b0;
					done <= 1'b1;
					cs_n <= 1'b1;
					rx_data <= rx_shift;
				end
			endcase
		end
	end
endmodule
