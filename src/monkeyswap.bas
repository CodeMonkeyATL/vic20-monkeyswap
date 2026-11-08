100 rem init: empty the keyboard buffer (drops autostart's stray z)
110 poke198,0
120 rem black screen and border
130 poke36879,8
140 rem seed the random numbers from the clock, so each run differs
150 t=rnd(-ti)
160 rem b%=board (64 cells), pg%=piece glyph, pc%=piece color
170 dimb%(63),pg%(5),pc%(5)
180 fori=0to5:readpg%(i),pc%(i):next
190 rem screen code and color per piece: spade yellow, heart red,
191 rem club green, diamond cyan, ball purple, circle white
192 data65,7,83,2,88,5,90,3,81,4,87,1
200 rem ba=screen address of the top-left piece, co=color ram offset
210 ba=7771:co=30720
220 print"{clr}"
230 gosub1000
240 gosub1100

300 rem wait for a key, then end; first drop keys typed during setup
305 poke198,0
310 geta$:ifa$=""then310
320 end

1000 rem fill the board with random pieces 0-5, without runs of three
1010 fori=0to63
1020 t=int(rnd(1)*6)
1030 rem same as the two cells to the left? (only from column 2 on)
1040 if(iand7)>1thenift=b%(i-1)andt=b%(i-2)then1020
1050 rem same as the two cells above? (only from row 2 on)
1060 ifi>15thenift=b%(i-8)andt=b%(i-16)then1020
1070 b%(i)=t
1080 next
1090 return

1100 rem draw the board: cell i is row int(i/8), column iand7
1110 fori=0to63
1120 p=ba+int(i/8)*44+(iand7)*2
1130 pokep,pg%(b%(i))
1140 pokep+co,pc%(b%(i))
1150 next
1160 return
