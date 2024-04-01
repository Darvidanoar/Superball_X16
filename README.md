# SuperBall
Continuing to learn 6502 assembly on the Commander X16.

I wanted to have a play around with a creating a sprite and to see if I could do something more interesting than having it follow the mouse.

## The algorithm
When the game loads a ball is tossed from the top of the screen.

The ball is given an initial horizontal velocity of %0F (15).
The vertical distance travelled per time unit is derived from a lookup table as I didn't want to do floationg point calculations for gravity.
As the ball loses altitude, the speed is also retarded to make it look slightly more natuaral as it approaches the bottom of the screen.
