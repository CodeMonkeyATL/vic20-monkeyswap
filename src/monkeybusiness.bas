100 rem init: empty the keyboard buffer (drops autostart's stray z)
110 poke198,0
120 print"{clr}hello world"

200 rem wait for a key, then end
210 geta$:ifa$=""then210
