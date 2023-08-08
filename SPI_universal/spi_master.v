`timescale 1 ns / 1 ps
module spi_master (

	// output wire clk_1MHz_test,
	output wire spi_clk,
	output reg spi_mosi,
	output reg spi_str = 0,
	input wire spi_miso,

	output wire [15:0] dout,
	input wire [15:0] data,

	input wire start,
	output reg ready = 0,
	input wire reset,
	input wire clk
);

parameter [4:0] P_LEN = 5'h0F ; // длина пакета
parameter [3:0] SPEED_DIV = 4'hC ;	// значение делителя частоты

parameter [2:0] WAIT = 0;
parameter [2:0] TX_RX = 1;
parameter [2:0] STROB_SET = 2;


reg [14:0] Temp_OUT;
reg [15:0] Temp_IN;
reg [4:0] i = P_LEN;

reg [3:0] count_clk1 = SPEED_DIV;
reg clk_1MHz = 0;
reg clk_rst = 0;
reg flag_exeq = 0;

reg [2:0] st_mach = WAIT;

reg prev_posdg;
wire back_edge;
wire front_edge;

always @(posedge clk)		// этот регистр нужен для отлова фронтов новой, поделенной частоты 1МГц
	prev_posdg <= clk_1MHz;

// assign clk_1MHz_test = clk_1MHz ;

assign back_edge = prev_posdg & ~clk_1MHz;	// ловим задний фронта
assign front_edge = ~prev_posdg & clk_1MHz;	// и передний

assign dout = Temp_IN;			// вывод данных
assign spi_clk = (flag_exeq) ?  clk_1MHz : 1'b0 ;	//	вывод синхросигнала SPI
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
		//	при использовании каждого фронта синхросигнала(posedge & negedge), можно было бы получить
		//	четкий 1МГц, но синтезатор ISE ругается на триггер-защелку
	always @(posedge clk) begin		// блок делителя частоты. до ~1.04 МГц
		if (clk_rst || reset) begin	//	если сброс глобальный или "местный", то обнуляем
			count_clk1 <= SPEED_DIV;
			clk_1MHz <= 0;	// сброс в 0 обязателен, т.к. при передаче есть шанс попасть на 1 и тогда вся времянка к чертям
		end
		else begin					//	иначе счетчик делителя отсчитывает 12 тактов (25/12 =~1.04)
			if ( !count_clk1 ) begin
				count_clk1 <= SPEED_DIV ;
				clk_1MHz <= ~clk_1MHz ;
			end
			else
				count_clk1 <= count_clk1 - 1;	// обычный декремент, че тут описывать :/
		end
	end

	always @(negedge clk) begin
		if (reset) begin		// сброс
			spi_mosi <= 0;
			spi_str  <= 0;
			Temp_OUT <= 0;
			flag_exeq <= 0;
			ready <= 0;
			i <= P_LEN;
			st_mach <= WAIT;
		end
		else begin
			//		автомат приемопередатчика мастера
			case (st_mach)
			WAIT : begin	// состояние ожидания сигнала старта, при активации выдает первый бит посылки
				clk_rst <= 1;

				if (start) begin
					Temp_OUT <= data[14:0];  // копируем данные во внутренний регистр
					flag_exeq <= 1'b1;		// флаг нужен для активации сигнала spi_clk(выше в блоке assign)
					spi_mosi <= data[15];	// передача первого бита
					spi_str <= 0;
					i <= P_LEN;   // если был дан старт, выставляем флаг и счетчик битов
					clk_rst <= 0;

					st_mach <= TX_RX;
				end
			end

			TX_RX : begin		// на самом деле тут только передающая часть, а RX описан внизу
				if (back_edge) begin		// по заднему фронту синхросигнала 1МГц
					if (i) begin // если еще не все биты переданы
						Temp_OUT <= Temp_OUT << 1;
						spi_mosi <= Temp_OUT[14];
						i <= i-1;
					end
					else begin	// когда слово отправлено
						flag_exeq <= 1'b0;		// отключаем SPI_CLK
						i <= P_LEN;
						spi_mosi <= 1'b0;
						st_mach <= STROB_SET;
					end
				end
			end

			STROB_SET : begin	// состояние для выставления сигнала строба,

				ready <= front_edge;
				if (front_edge)		// по переднему фронту 1МГц выставляем в 1
					spi_str <= 1;
				else if (back_edge) begin	// по заднему в 0, и возврат к состоянию ожидания
					spi_str <= 0;
					st_mach <= WAIT;
				end
			end

			default : begin		// а суда попасть не должен никогда, но сбои и заряженые частицы могут все
				spi_str  <= 0;
				st_mach <= WAIT;
			end
			endcase
		end
	end

	always @(posedge clk)	// блок приема данных, все просто
		if (reset)
			Temp_IN <= 16'b0;
		else
		//ПРИЕМ ПОСЫЛКИ------------>
			if ( flag_exeq & front_edge )
				Temp_IN[i] <= spi_miso;


endmodule



















