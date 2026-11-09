100 poke198,0:poke36879,8:t=rnd(-ti):dimpg%(6),pc%(6),kg%(1,5):rem init
180 fori=0to6:readpg%(i),pc%(i):next:data65,7,83,2,88,5,90,3,81,4,87,1,32,1:rem pieces 0-5, 6=empty: code, color
194 data85,73,74,75,64,93:forj=0to5:kg%(0,j)=32:readkg%(1,j):next:ba=7771:co=30720:rem box: 4 corners, -, |
212 bb=919:bm=983:bh=1012:print"{clr}{wht}{down}{down}":forj=1to17:print"                   ":next:rem board, match list, holes (cassette buffer); board area white
230 gosub1000:gosub1100:ho=rnd(1)*128:sx=8152:pokesx+co,7:rem ho: random first trial; sx: spinner
250 gosub3800:cr=3:cc=3

300 km=1:gosub2100:rem play: wasd moves, shift+wasd swaps
330 poke198,0:kt=ti:rd=0
340 geta$:ifa$=""thengosub5000:goto340
345 pokesx,32:kt=ti:ifa$="q"thenifp$="q"then5540:rem qq quits
347 p$=a$
350 sw=asc(a$)>127:ifswthena$=chr$(asc(a$)and127)
360 ifa$="w"ora$="a"ora$="s"ora$="d"then390
370 goto340
390 r=cr-(a$="s"andcr<7)+(a$="w"andcr>0):c=cc-(a$="d"andcc<7)+(a$="a"andcc>0)
420 ifr=crthenifc=ccthen340
430 ifswthengosub2200:goto330
440 km=0:gosub2100:cr=r:cc=c:km=1:gosub2100:goto340

1000 fori=0to63:rem fill, no runs of 3
1020 t=int(rnd(1)*6):if(iand7)>1thenift=peek(bb+i-1)andt=peek(bb+i-2)then1020
1060 ifi>15thenift=peek(bb+i-8)andt=peek(bb+i-16)then1020
1070 pokebb+i,t:next:return

1100 fori=0to63:gosub1200:next:return:rem draw board

1200 p=ba+int(i/8)*44+(iand7)*2:w=peek(bb+i):pokep,pg%(wand7)-128*(w>7):rem draw cell i; marked (>7) reversed
1230 pokep+co,pc%(wand7):return

2000 w=ka+(kh-1)*22:pokeka,kg%(km,0):pokeka+kw-1,kg%(km,1):rem box at ka, kw x kh; km=1 draw, 0 erase
2030 pokew,kg%(km,2):pokew+kw-1,kg%(km,3)
2050 forj=1tokw-2:pokeka+j,kg%(km,4):pokew+j,kg%(km,4):next
2070 forj=22to(kh-2)*22step22:pokeka+j,kg%(km,5):pokeka+j+kw-1,kg%(km,5):next:return

2100 ka=ba+cr*44+cc*2-23:kw=3:kh=3:gosub2000:return:rem cursor box at cr,cc

2200 km=0:gosub2100:x=cr*8+cc:y=r*8+c:w=x:ify<xthenw=y:rem swap cr,cc with r,c: grow, swap, shrink
2240 ka=ba+int(w/8)*44+(wand7)*2-23:kw=3-2*(r=cr):kh=3-2*(c=cc)
2260 km=1:gosub2000:n=5:gosub2900:gosub2400:gosub2900:mn=0:i=x:gosub3000:i=y:gosub3000
2280 ifmn=0thengosub2400:r=cr:c=cc:gosub2900
2290 km=0:gosub2000:cr=r:cc=c:km=1:gosub2100:ifmnthenhm=0:hc=0:ho=rnd(1)*128:gosub3500
2310 return

2400 t=peek(bb+x):pokebb+x,peek(bb+y):pokebb+y,t:ifhtthenreturn:rem swap cells x,y, redraw (not in a trial)
2410 i=x:gosub1200:i=y:gosub1200:return

2900 t=ti+n:rem pause n jiffies
2920 ifti<tthen2920
2930 return

3000 u=iand7:v=int(i/8):lo=u-2:iflo<0thenlo=0:rem check windows around cell i
3030 hi=u:ifhi>5thenhi=5
3040 j=1:fors=bb+i-u+lotobb+i-u+hi:gosub3150:next:lo=v-2:iflo<0thenlo=0
3080 hi=v:ifhi>5thenhi=5
3090 j=8:fors=bb+lo*8+utobb+hi*8+ustep8:gosub3150:next:return

3100 ifhtthenfo=1:return:rem a trial only needs to know
3110 fork=0to2:q=s+k*j:ifpeek(q)<8thenifmn<29thenpokeq,peek(q)or8:pokebm+mn,q-bb:mn=mn+1:rem mark addresses s,s+j,s+2j; list new ones (max 29)
3130 next:return

3150 t=peek(s)and7:ift=(peek(s+j)and7)andt=(peek(s+2*j)and7)thengosub3100:rem window: a run?
3160 return

3200 fork=0tomn-1:i=peek(bm+k):gosub1200:next:n=30:gosub2900:rem flash marks, then clear to empty
3230 fork=0tomn-1:i=peek(bm+k):pokebb+i,6:gosub1200:next:return

3300 forg=0to7:pokebh+g,0:next:rem gravity; bh+g: 128 + holes*8 + lowest hole row
3320 fork=0tomn-1:i=peek(bm+k):g=iand7:v=int(i/8):b=peek(bh+g)or128
3325 if(band7)>vthenv=band7
3327 pokebh+g,(band248)+8+v:next
3340 f=0:forg=0to7:b=peek(bh+g):if(band120)thengosub3400
3350 next:iffthenn=3:gosub2900:gosub5900:goto3340
3370 return

3400 q=band7:rem column g: drop above its lowest hole; one hole fewer
3420 ifpeek(bb+q*8+g)<>6thenq=q-1:goto3420
3440 a=bb+q*8+g:p=ba+q*44+g*2:ifq=0then3460:rem a for loop always runs once
3450 forz=qto1step-1:w=peek(a-8):pokea,w:pokep,pg%(w):pokep+co,pc%(w):a=a-8:p=p-44:next
3460 w=int(rnd(1)*6):pokea,w:pokep,pg%(w):pokep+co,pc%(w):f=1:pokebh+g,b-8:return

3500 rd=rd+1:sc=sc+mn*10*rd:gosub3800:gosub3200:gosub3300:mn=0:cl=8:ch=-1:lm=-1:rem cascade round rd: score, clear, fall, check
3520 forg=0to7:b=peek(bh+g):ifb>127thengosub3600
3530 next:lo=cl-2:iflo<0thenlo=0
3550 hi=ch:ifhi>5thenhi=5
3560 j=1:forr=0tolm:fors=bb+r*8+lotobb+r*8+hi:gosub3150:next:next:ifmnthen3500
3580 return

3600 ifg<clthencl=g:rem changed column g: widen the range, check its column
3610 ifg>chthench=g
3620 q=band7:ifq>lmthenlm=q
3630 ifq>5thenq=5
3640 j=8:fors=bb+gtobb+q*8+gstep8:gosub3150:next:return

3800 ty=1:tx=1:gosub4100:print"{yel}"sc;:return:rem show the score

4100 poke781,ty:poke782,tx:poke783,0:sys65520:return:rem print position: row ty, column tx

5000 ifhmorti-kt<120thenreturn:rem idle 2 s: try one swap (hc: cell*2+direction); none works: game over
5010 ifhc>127then5500
5020 k=(hc+ho)and127:x=int(k/2):w=kand1:y=x+1+7*w:hc=hc+1:fo=0:gosub5900:rem from a random start, wrapping
5030 if(xand7)+1-w>7ory>63thenreturn:rem off the board
5040 ht=1:gosub2400:i=x:gosub3000:i=y:gosub3000:gosub2400:ht=0:iffothenhm=1:pokesx,32
5050 return

5500 ty=21:tx=6:gosub4100:print"{wht}game over";:gosub5700:poke198,0:rem no move left
5510 geta$:ifa$=""then5510
5520 run:rem result written; any key plays again (the launcher posts the result when it next runs)
5540 poke36879,27:print"{clr}{blu}";:end

5700 poke900,2:poke901,253:poke902,2:poke903,1:v=sc:rem result: game 2, endless, 1 field (pts)
5710 fori=904to906:pokei,v-256*int(v/256):v=int(v/256):next:return

5900 sp=sp+1:pokesx,asc(mid$("{$60}{$6e}{$7d}{$6d}",(spand3)+1))-32:return:rem spinner: one step
