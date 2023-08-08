`timescale 1ns / 1ps

module spi (
	inout wire spi_clk,
	inout wire spi_mosi,
	inout wire spi_str,
	inout wire spi_miso,

	output wire [15:0] d_rx,
	input wire [15:0] d_tx,
	input wire start,
	output reg ready = 0,
	input wire prog,

	input wire reset,
	input wire clk
);

parameter [4:0] P_LEN = 5'h0F ; 	// длина пакета
parameter [3:0] SPEED_DIV = 4'hC ;	// значение делителя частоты
parameter [1:0] CPOL_CPHA = 2'b0 ;	// настройка режима;[1]-cpol;[0]-cpha
parameter HL_BIT = 1'b0 ;		// передача со старшего или младшего бита
parameter MAST_SLAVE = 1'b1 ;	// ведущий или ведомый режим функционирования; 1-m;0-s;

reg [4:0] p_len = P_LEN ;
reg [3:0] speed_div = SPEED_DIV ;
reg [1:0] cpol_cpha = CPOL_CPHA ;
reg hl_bit = HL_BIT ;
reg mast_slave = MAST_SLAVE ;

wire spi_str_wire ;			// используются для режима slave
wire spi_clk_wire ;			// 
wire spi_miso_wire ;
wire spi_mosi_wire ;
wire spi_clk_reg = 1'b0 ;	// используются для master
reg spi_str_reg = 1'b0 ;	//
reg spi_miso_reg = 1'b0 ;
reg spi_mosi_reg = 1'b0 ;

assign spi_clk = (mast_slave) ? spi_clk_reg : 1'bz ;
assign spi_clk_wire = (!mast_slave) ? spi_clk : 1'bz ;

assign spi_str = (mast_slave) ? spi_str_reg : 1'bz ;
assign spi_str_wire = (!mast_slave) ? spi_str : 1'bz ;

assign spi_miso = (!mast_slave) ? spi_miso_reg : 1'bz ;
assign spi_miso_wire = (mast_slave) ? spi_miso : 1'bz ;

assign spi_mosi = (mast_slave) ? spi_mosi_reg : 1'bz ;
assign spi_mosi_wire = (!mast_slave) ? spi_mosi : 1'bz ;


parameter [2:0] WAIT = 0;
parameter [2:0] TX_RX = 1;
parameter [2:0] STROB_SET = 2;
reg [2:0] st_mach = WAIT;

reg [15:0] Temp_TX;
reg [15:0] Temp_RX;
reg [4:0] i = p_len;

reg [3:0] count_clk1 = speed_div;
reg clk_1MHz = 0;
reg clk_rst = 0;
reg flag_exeq = 0;

reg prev_posdg;

wire back_edge;
wire front_edge;

always @(posedge clk)		// этот регистр нужен для отлова фронтов новой, поделенной частоты 1МГц
	prev_posdg <= clk_1MHz;

assign back_edge = prev_posdg & ~clk_1MHz;	// ловим задний фронта
assign front_edge = ~prev_posdg & clk_1MHz;	// и передний

assign d_rx = Temp_RX;			// вывод данных
assign spi_clk_reg = (flag_exeq) ?  clk_1MHz : 1'b0 ;	//	вывод синхросигнала SPI





reg str_latch = 0;
reg flag_ready;

always @(posedge clk) begin		// синхронизируем входные сигналы
	clk_1MHz <= spi_clk ;
	str_latch <= spi_str ;
	prev_posdg <= clk_1MHz ;
	flag_ready <= str_latch ;
end

assign ready = ~flag_ready & str_latch;








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
			Temp_TX <= 0;
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
					Temp_TX <= d_tc[14:0];  // копируем данные во внутренний регистр
					flag_exeq <= 1'b1;		// флаг нужен для активации сигнала spi_clk(выше в блоке assign)
					spi_mosi <= d_tx[15];	// передача первого бита
					spi_str <= 0;		
					i <= P_LEN;   // если был дан старт, выставляем флаг и счетчик битов
					clk_rst <= 0;
					
					st_mach <= TX_RX;
				end
			end

			TX_RX : begin		// на самом деле тут только передающая часть, а RX описан внизу 
				if (back_edge) begin		// по заднему фронту синхросигнала 1МГц
					if (i) begin // если еще не все биты переданы
						Temp_TX <= Temp_TX << 1;
						spi_mosi <= Temp_TX[14];
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
			Temp_RX <= 16'b0;
		else
		//ПРИЕМ ПОСЫЛКИ------------>
			if ( flag_exeq & front_edge )
				Temp_RX[i] <= spi_miso;


endmodule

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

reg [15:0] Temp_RX = 16'h8912 ;		// регистр передающей линии
reg [15:0] Temp_TX = 16'h5678 ;		// регистр входящей линии
reg [3:0] i = 4'hf;

reg clk_1MHz = 0;
reg str_latch = 0;
reg flag_ready;
reg prev_posdg;
wire back_edge;
wire front_edge;

always @(posedge clk) begin		// синхронизируем входные сигналы
	clk_1MHz <= spi_clk ;
	str_latch <= spi_str;
	prev_posdg <= clk_1MHz;
	flag_ready <= str_latch;
end

assign back_edge = prev_posdg & ~clk_1MHz;
assign front_edge = ~prev_posdg & clk_1MHz;
assign ready = ~flag_ready & str_latch;
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	always @(negedge clk) begin
		if (reset) begin
			i <= 4'hF;
			spi_miso <= 1 ;
			Temp_RX <= 16'h0123 ;
			Temp_TX <= 16'h4567 ;
		end
		else begin

			//<RX line RX line RX line RX line RX line>

			if (front_edge == 1)
				Temp_RX[0] <= spi_mosi ;

			if ((back_edge == 1) && (i != 0 ) )
				Temp_RX <= Temp_RX << 1 ;

			// if (ready == 1 )
				d_rx <= Temp_RX;

			//<TX line TX line TX line TX line TX line>

			Temp_TX <= d_tx ;	// ну хз, как тут без строба в начале транзакции

			if (str_latch == 1)
				i <= 4'hF ;
			else begin
				if (i==4'hF)
					spi_miso <= Temp_TX[15] ;
				else
					spi_miso <= Temp_TX[i] ;

				if (back_edge == 1)
					i <= i-1'b1 ;
			end


		end
	end
