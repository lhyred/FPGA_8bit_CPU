module digital_show(
	clk,
	rst,
	dataout,
	en,
    showdata,
    SW
	);
    input [31:0] showdata;
	input clk,rst;
    input [4:0]SW;
	output[6:0] dataout;
	output[7:0] en;//COM使能输出

	reg[6:0] dataout;//各段数据输出
	reg[7:0] en;

	reg[15:0] cnt_scan;//扫描频率计数器
	reg[3:0] dataout_buf;
    
	always@(posedge clk or negedge  rst)
		begin
			if(!rst) 
				begin //低电平复位
					cnt_scan<=0;
				end
			else 
				begin
					cnt_scan<=cnt_scan+1'b1;
				end
		end

	always @(cnt_scan)//段码扫描频率
		begin 
		  case(cnt_scan[15:13])
				3'b000 :
					en = 8'b1111_1110;	
				3'b001 :
					en = 8'b1111_1101;
				3'b010 :
					en = 8'b1111_1011;
				3'b011 :
					en = 8'b1111_0111;
				3'b100 :
					en = 8'b1110_1111;
				3'b101 :
					en = 8'b1101_1111;
				3'b110 :
					en = 8'b1011_1111;
				3'b111 :
					en = 8'b0111_1111;
			default :
				en = 8'b0000_0000;
			endcase
		end
		
	always@(en) //对应COM信号给出各段数据，段码
		begin
            if(SW[2:0] != 3'b010)
            begin
    			case(en)
    				8'b1111_1110:
    					dataout_buf=showdata[3:0];//输入将要显示的数字
    				8'b1111_1101:
    					dataout_buf=showdata[7:4];
    				8'b1111_1011:
    					dataout_buf=showdata[11:8];
    				8'b1111_0111:
    					dataout_buf=showdata[15:12];   
    				8'b1110_1111:
    					dataout_buf=showdata[19:16];   
    				8'b1101_1111:
    					dataout_buf=showdata[23:20];   
    				8'b1011_1111:
    					dataout_buf=showdata[27:24];   
    				8'b0111_1111:
    					dataout_buf=showdata[31:28];   
    				default:
    					dataout_buf=0;
    			 endcase
             end
             
             else
             begin
                 case(en)
    				8'b1111_1110:
    					dataout_buf=showdata%10;//输入将要显示的数字
    				8'b1111_1101:
    					dataout_buf=showdata/ 32'd10 %10;
    				8'b1111_1011:
    					dataout_buf=showdata/ 32'd100 %10;
    				8'b1111_0111:
    					dataout_buf=showdata/ 32'd1000 %10;   
    				8'b1110_1111:
    					dataout_buf=showdata/ 32'd10000 %10;   
    				8'b1101_1111:
    					dataout_buf=showdata/ 32'd100000 %10;   
    				8'b1011_1111:
    					dataout_buf=showdata/ 32'd1000000 %10;   
    				8'b0111_1111:
    					dataout_buf=showdata/ 32'd10000000 %10;   
    				default:
    					dataout_buf=0;
    			 endcase
             end
             
		end

	always@(dataout_buf)	
		begin
			case(dataout_buf)  //将要显示的数字译成段码
					4'b0000	:	dataout	<=	7'b1000_000;//7'b0111_111;
					4'b0001	:	dataout	<=	7'b1111_001;//7'b0000_110;
					4'b0010	:	dataout	<=	7'b0100_100;//7'b1011_011;
					4'b0011	:	dataout	<=	7'b0110_000;//7'b1001_111;
					4'b0100	:	dataout	<=	7'b0011_001;//7'b1100_110;
					4'b0101	:	dataout	<=	7'b0010_010;//7'b1101_101;
					4'b0110	:	dataout	<=  7'b0000_010;//7'b1111_101;
					4'b0111	:	dataout	<=	7'b1111_000;//7'b0000_111;
					4'b1000	:	dataout	<=	7'b0000_000;//7'b1111_111;
					4'b1001	:	dataout	<=	7'b0010_000;//7'b1101_111;
					4'b1010	:	dataout	<=	7'b0001_000;//7'b1110_111;
					4'b1011	:	dataout	<=	7'b0000_011;//7'b1111_100;
					4'b1100	:	dataout	<=	7'b1000_110;//7'b0111_001;
					4'b1101	:	dataout	<=	7'b0100_001;//7'b1011_110;
					4'b1110	:	dataout	<=	7'b0000_110;//7'b1111_001;
					4'b1111	:	dataout	<=	7'b0001_110;//7'b1110_001;
					default	:	dataout	<=	7'b1000_000;//7'b0111_111;	
			 endcase
		end
endmodule