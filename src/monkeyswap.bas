100 poke198,0:w=0:a=0:p=0:z=0:rem init; hot loop variables first (found faster)
130 poke36879,8
150 t=rnd(-ti)
170 dimpg%(6),pc%(6),kg%(1,5)
180 fori=0to6:readpg%(i),pc%(i):next
190 data65,7,83,2,88,5,90,3,81,4,87,1,32,1:rem pieces 0-5, 6=empty: code, color
194 data85,73,74,75,64,93:rem box: 4 corners, -, |
196 forj=0to5:kg%(0,j)=32:readkg%(1,j):next
210 ba=7771:co=30720
212 bb=919:bm=983:bh=1012:rem board, match list, holes (cassette buffer)
220 print"{clr}{wht}{down}{down}":rem board area white
224 forj=1to17:print"                   ":next
230 gosub1000
240 gosub1100
260 cr=3:cc=3

300 km=1:gosub2100:rem play: wasd moves, shift+wasd swaps
330 poke198,0
340 geta$:ifa$=""then340
350 sw=asc(a$)>127
355 ifswthena$=chr$(asc(a$)and127)
360 ifa$="w"ora$="a"ora$="s"ora$="d"then390
370 end
390 r=cr-(a$="s"andcr<7)+(a$="w"andcr>0)
400 c=cc-(a$="d"andcc<7)+(a$="a"andcc>0)
420 ifr=crthenifc=ccthen340
430 ifswthengosub2200:goto330
440 km=0:gosub2100
450 cr=r:cc=c
460 km=1:gosub2100
470 goto340

1000 fori=0to63:rem fill, no runs of 3
1020 t=int(rnd(1)*6)
1040 if(iand7)>1thenift=peek(bb+i-1)andt=peek(bb+i-2)then1020
1060 ifi>15thenift=peek(bb+i-8)andt=peek(bb+i-16)then1020
1070 pokebb+i,t
1080 next
1090 return

1100 fori=0to63:rem draw board
1120 gosub1200
1130 next
1140 return

1200 p=ba+int(i/8)*44+(iand7)*2:rem draw cell i; marked (>7) reversed
1210 w=peek(bb+i)
1220 pokep,pg%(wand7)-128*(w>7)
1230 pokep+co,pc%(wand7)
1240 return

2000 e=ka+(kh-1)*22:rem box at ka, kw x kh; km=1 draw, 0 erase
2020 pokeka,kg%(km,0):pokeka+kw-1,kg%(km,1)
2030 pokee,kg%(km,2):pokee+kw-1,kg%(km,3)
2050 forj=1tokw-2:pokeka+j,kg%(km,4):pokee+j,kg%(km,4):next
2070 forj=22to(kh-2)*22step22:pokeka+j,kg%(km,5):pokeka+j+kw-1,kg%(km,5):next
2080 return

2100 ka=ba+cr*44+cc*2-23:rem cursor box at cr,cc
2120 kw=3:kh=3
2130 gosub2000
2140 return

2200 km=0:gosub2100:rem swap cr,cc with r,c: grow, swap, shrink
2220 x=cr*8+cc:y=r*8+c:m=x
2230 ify<xthenm=y
2240 ka=ba+int(m/8)*44+(mand7)*2-23
2250 kw=3-2*(r=cr):kh=3-2*(c=cc)
2260 km=1:gosub2000:n=5:gosub2900
2270 gosub2400:gosub2900
2275 mn=0:i=x:gosub3000:i=y:gosub3000
2280 ifmn=0thengosub2400:r=cr:c=cc:gosub2900
2290 km=0:gosub2000
2300 cr=r:cc=c:km=1:gosub2100
2305 ifmnthengosub3200:gosub3300
2310 return

2400 t=peek(bb+x):pokebb+x,peek(bb+y):pokebb+y,t:rem swap cells x,y, redraw
2420 i=x:gosub1200:i=y:gosub1200
2430 return

2900 t=ti+n:rem pause n jiffies
2920 ifti<tthen2920
2930 return

3000 u=iand7:v=int(i/8):rem check windows around cell i
3020 lo=u-2:iflo<0thenlo=0
3030 hi=u:ifhi>5thenhi=5
3040 fors=bb+i-u+lotobb+i-u+hi
3050 t=peek(s)and7:ift=(peek(s+1)and7)andt=(peek(s+2)and7)thenj=1:gosub3100
3060 next
3070 lo=v-2:iflo<0thenlo=0
3080 hi=v:ifhi>5thenhi=5
3090 fors=bb+lo*8+utobb+hi*8+ustep8
3092 t=peek(s)and7:ift=(peek(s+8)and7)andt=(peek(s+16)and7)thenj=8:gosub3100
3094 next
3096 return

3100 fork=0to2:q=s+k*j:rem mark addresses s,s+j,s+2j; list new ones
3120 ifpeek(q)<8thenpokeq,peek(q)or8:pokebm+mn,q-bb:mn=mn+1
3130 next
3140 return

3200 fork=0tomn-1:i=peek(bm+k):gosub1200:next:rem flash marks, then clear to empty
3220 n=30:gosub2900
3230 fork=0tomn-1:i=peek(bm+k):pokebb+i,6:gosub1200:next
3240 return

3300 forg=0to7:pokebh+g,0:next:rem gravity; bh+g: 128 + holes*8 + lowest hole row
3320 fork=0tomn-1:i=peek(bm+k):g=iand7:v=int(i/8):b=peek(bh+g)or128
3325 if(band7)>vthenv=band7
3327 pokebh+g,(band248)+8+v
3330 next
3340 f=0:forg=0to7:b=peek(bh+g):if(band120)thengosub3400
3350 next
3360 iffthenn=3:gosub2900:goto3340
3370 return

3400 q=band7:rem column g: drop above its lowest hole; one hole fewer
3420 ifpeek(bb+q*8+g)<>6thenq=q-1:goto3420
3440 a=bb+q*8+g:p=ba+q*44+g*2
3450 forz=qto1step-1:w=peek(a-8):pokea,w:pokep,pg%(w):pokep+co,pc%(w):a=a-8:p=p-44:next
3460 w=int(rnd(1)*6):pokea,w:pokep,pg%(w):pokep+co,pc%(w):f=1:pokebh+g,b-8
3470 return
