100 rem init
110 poke198,0
130 poke36879,8
150 t=rnd(-ti)
170 dimb%(63),pg%(5),pc%(5),kg%(1,5)
180 fori=0to5:readpg%(i),pc%(i):next
190 rem pieces: screen code, color
192 data65,7,83,2,88,5,90,3,81,4,87,1
194 rem box: 4 corners, -, |
195 data85,73,74,75,64,93
196 forj=0to5:kg%(0,j)=32:readkg%(1,j):next
210 ba=7771:co=30720
220 rem board area white
222 print"{clr}{wht}{down}{down}"
224 forj=1to17:print"                   ":next
230 gosub1000
240 gosub1100
260 cr=3:cc=3

300 rem play: wasd moves
310 km=1:gosub2100
330 poke198,0
340 geta$:ifa$=""then340
360 ifa$="w"ora$="a"ora$="s"ora$="d"then390
370 end
390 r=cr-(a$="s"andcr<7)+(a$="w"andcr>0)
400 c=cc-(a$="d"andcc<7)+(a$="a"andcc>0)
420 ifr=crthenifc=ccthen340
440 km=0:gosub2100
450 cr=r:cc=c
460 km=1:gosub2100
470 goto340

1000 rem fill, no runs of 3
1010 fori=0to63
1020 t=int(rnd(1)*6)
1040 if(iand7)>1thenift=b%(i-1)andt=b%(i-2)then1020
1060 ifi>15thenift=b%(i-8)andt=b%(i-16)then1020
1070 b%(i)=t
1080 next
1090 return

1100 rem draw board
1110 fori=0to63
1120 p=ba+int(i/8)*44+(iand7)*2
1130 pokep,pg%(b%(i))
1140 pokep+co,pc%(b%(i))
1150 next
1160 return

2000 rem box at ka, kw x kh; km=1 draw, 0 erase
2010 e=ka+(kh-1)*22
2020 pokeka,kg%(km,0):pokeka+kw-1,kg%(km,1)
2030 pokee,kg%(km,2):pokee+kw-1,kg%(km,3)
2050 forj=1tokw-2:pokeka+j,kg%(km,4):pokee+j,kg%(km,4):next
2070 forj=22to(kh-2)*22step22:pokeka+j,kg%(km,5):pokeka+j+kw-1,kg%(km,5):next
2080 return

2100 rem cursor box at cr,cc
2110 ka=ba+cr*44+cc*2-23
2120 kw=3:kh=3
2130 gosub2000
2140 return
