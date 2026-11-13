100 poke36878,15:t=rnd(-ti):rem once: volume, seed; a new game starts at 110 and keeps the mute
110 z=36874:pokez+5,8:bh=1012:print"{clr}{yel}monkey swap":poke8152,42:poke38872,0:rem init: z sound base, colors, title, spinner (*) in black
180 dimpg%(14):bb=919:fori=0to13:readpg%(i):next:data65,83,88,90,81,87,32,,7,2,5,3,4,1:rem pieces 0-5, 6=empty: codes at 0-6, colors at 8-13

200 fori=0to63:a=bb+i:rem fill, no runs of 3, drawing as it goes
210 t=int(rnd(1)*6):if(t=peek(a-1)andt=peek(a-2))or(t=peek(a-8)andt=peek(a-16))then210
230 pokea,t:gosub1200:next:ho=rnd(1)*128:gosub3800:cr=3:cc=3:e=peek(841):rem ho: random first trial; e: launcher's device

330 gosub1980:poke198,0:kt=ti:rd=0:rem play: wasd moves, shift+wasd swaps
340 geta$:ifa$=""thengosub5000:goto340
345 poke38872,0:kt=ti:k=asc(a$)and127:hw=(k=72):ifk=81thenifl=81then5530:rem h hint (72), qq quits (81)
347 ifk=77thenpokez+4,15-peek(z+4):rem m mutes (77): the volume register is 15 or 0
350 l=k:r=cr-(k=83andcr<7)+(k=87andcr>0):c=cc-(k=68andcc<7)+(k=65andcc>0):rem 83 s, 87 w, 68 d, 65 a
420 ifr=crthenifc=ccthen340
430 ifasc(a$)>127thengosub2200:goto330
440 km=0:gosub1990:cr=r:cc=c:gosub1980
450 ifpeek(z+4)thenpokez+3,250:fori=11to0step-1.5:pokez+4,i:next:pokez+3,0:pokez+4,15:rem woosh, unless muted
460 goto340

1200 p=7771+i*2+int(i/8)*28:w=peek(bb+i):pokep,pg%(wand7)-128*(w>7):rem draw cell i; marked (>7) reversed
1230 pokep+30720,pg%(wor8):return

1980 km=1:rem draw the cursor
1990 ka=7748+cr*44+cc*2:kw=2:kh=44:rem cursor box at cr,cc, mode km; falls into the box
2000 w=ka+kh:pokeka,32+km*53:pokeka+kw,32+km*41:pokew,32+km*42:pokew+kw,32+km*43:rem box at ka, kw right, kh down; km=1 draw, 0 erase
2050 t=32+km*32:forj=1tokw-1:pokeka+j,t:pokew+j,t:next
2070 t=32+km*61:forj=22tokh-22step22:pokeka+j,t:pokeka+j+kw,t:next:return

2200 km=0:gosub1990:x=cr*8+cc:y=r*8+c:ka=ka+2*(c<cc)+44*(r<cr):kw=2-2*(r=cr):rem swap cr,cc with r,c: grow, swap, shrink
2260 kh=44-44*(c=cc):km=1:gosub2000:fori=200to240step4:pokez+1,i:next:pokez+1,0:rem grow; ring up
2270 n=5:gosub2900:gosub2400:gosub2900:mn=0:gosub2990
2280 ifmnthen2290:rem a match: the cascade's ding is its sound
2285 fori=150to130step-1:pokez,i:next:pokez,0:gosub2400:r=cr:c=cc:gosub2900:rem none: buzz, back
2290 km=0:gosub2000:cr=r:cc=c:ifmnthenhc=0:ho=rnd(1)*128:gosub3500
2310 return

2400 t=peek(bb+x):pokebb+x,peek(bb+y):pokebb+y,t:ifhtthenreturn:rem swap cells x,y, redraw (not in a trial)
2410 i=x:gosub1200:i=y:goto1200

2900 t=ti+n:rem pause n jiffies
2920 ifti<tthen2920
2930 return

2990 i=x:gosub3000:i=y:rem check around cells x and y
3000 j=1:u=iand7:gosub3020:j=8:u=int(i/8):rem windows through cell i: across, then down
3020 ford=u-2tou:ifd>=0thenifd<6thens=bb+i+(d-u)*j:gosub3100
3030 next:return

3100 t=peek(s)and7:ift<>(peek(s+j)and7)ort<>(peek(s+2*j)and7)thenreturn:rem window at s, step j: a run?
3110 ifhtthenmn=1:return:rem a trial only needs to know
3120 forq=stos+2*jstepj:t=peek(q):ift<8thenifmn<29thenpokeq,8ort:poke983+mn,q-bb:mn=mn+1:rem mark; list new ones at 983 (max 29)
3130 next:return

3200 fork=0tomn-1:i=peek(983+k):gosub1200:next:n=30:gosub2900:rem flash marks, then clear and fall
3300 forg=0to7:pokebh+g,0:next:fork=0tomn-1:i=peek(983+k):pokebb+i,6:gosub1200:g=iand7:rem bh+g: 128 + holes*8 + lowest hole row
3320 v=int(i/8):b=peek(bh+g)or128:if(band7)>vthenv=band7
3327 pokebh+g,(band248)+8+v:next
3340 forg=0to7:b=peek(bh+g):ifband120thenq=band7:gosub3420
3350 next:ifmnthenn=3:gosub2900:gosub5900:goto3340
3370 return

3420 a=bb+q*8+g:ifpeek(a)<>6thenq=q-1:goto3420:rem column g: drop above its lowest hole; one hole fewer
3440 p=7771+q*44+g*2:fora=atobb+gstep-8:w=peek(a-8):ifa<bb+8thenw=int(rnd(1)*6)
3460 pokea,w:pokep,pg%(w):pokep+30720,pg%(w+8):p=p-44:next:mn=mn-1:pokebh+g,b-8:return

3500 rd=rd+1:sc=sc+mn*10*rd:gosub3800:gosub6000:gosub3200:cl=8:lm=0:rem cascade round rd: score, clear, fall, check
3520 forg=0to7:b=peek(bh+g):ifb>127thengosub3600
3530 next:j=1:forr=0tolm:ford=cl-2toch:ifd>=0thenifd<6thens=bb+r*8+d:gosub3100
3560 next:next:ifmnthen3500
3580 return

3600 ch=g:ifg<clthencl=g:rem changed column g: widen the range, check its column
3620 q=band7:ifq>lmthenlm=q
3630 ifq>5thenq=5
3640 j=8:fors=bb+gtobb+q*8+gstep8:gosub3100:next:return

3800 print"{home}{wht}"tab(14)sc;:return:rem show the score

5000 ifhc<0thenifhwthenhw=0:km=0:gosub1990:x=-1-hc:cr=int(x/8):cc=xand7:gosub1980:rem hint: cursor to the found cell
5005 ifhc<0orti-kt<120thenreturn:rem idle 2 s: try one swap (hc: cell*2+direction; -1-x found at x); none works: game over
5010 ifhc>127then5500
5020 k=(hc+ho)and127:x=int(k/2):w=kand1:y=x+1+7*w:hc=hc+1:mn=0:gosub5900:rem from a random start, wrapping
5030 if(xand7)-w>6ory>63thenreturn:rem off the board
5040 ht=1:gosub2400:gosub2990:gosub2400:ht=0:ifmnthenhc=-1-x:poke38872,0
5050 return

5500 poke214,20:print:printtab(6)"{wht}game over";:gosub5600:rem no move left
5510 ifethenprint:printtab(5)"{red}l{wht}eaderboard";:rem from a launcher: offer l
5515 fori=200to140step-.5:pokez,i:next:pokez,0:rem falling tone
5520 poke198,0:wait198,1:geta$:ifa$="l"thenifethen5540:rem l back to a launcher; any other key plays again
5525 run110

5530 ifethenifsc>0thengosub5600:rem qq: a launched game leaves its score so far
5540 pokez+4,0:pokez+5,27:print"{clr}{blu}";:ife=0thenend:rem leave: started alone, just end
5550 print"{down}{down}load"chr$(34);:fori=1topeek(842):printchr$(peek(842+i));:next:rem load the launcher (name at 843, device 841)
5560 printchr$(34)","e"{home}";:poke631,13:poke632,82:poke633,85
5570 poke634,78:poke635,13:poke198,5:end

5600 poke900,2:poke901,253:poke902,2:poke903,1:v=sc:rem result for the launcher: game 2, endless, 1 field (pts)
5610 fori=904to906:t=int(v/256):pokei,v-256*t:v=t:next:return

5900 sp=(sp+2)and7:poke38872,spor1:return:rem spinner: one step, cycling white, cyan, green, yellow


6000 n=175+3*mn+6*rd:ifn>254thenn=254:rem match ding: pitch from the pieces (mn) and the round (rd)
6010 pokez+2,n:forj=1to12:next:pokez+2,64+.75*n:forj=1to40:next:pokez+2,0:return
