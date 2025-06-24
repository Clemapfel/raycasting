# Tutorial: Order of Operations

+ MOVE: learn to move, player has to move to the right to interact with greeting npc

+ SQUEEZE: learn to squeeze, player has to squeeze trhough a tight hole to exit the spawning area. squeeze is before jump to show the player the special properties of player character. Squeeze room should have semi-complex geometry while being convex, so player can learn how to apply blood to the surfces, walljumping should be impossible

+ **RESPAWN**: checkpoint right afterwards, when they die there respawn there instead of the initial area, teaching them how checkpoints work

+ JUMP: slippery wall angled away from the player forces them to jump up, make sure no wall up until this point is sticky. If player fails jump, they respawn right next to the starting area. This should be the only death area in the tutorial

+ SPRINT: long platform with jump that is impossible to make if not sprinting, not death barrier below, if dying twice, show sprint hint

+ COIN: put coin in impossible to miss spot like squeeze gate, increases coin counter, after this put coins into areas where 

+ WALLJUMP: sticky segments on a wall which is slippery at the bottom, forces the player to jumpa bove the slippery area, and realize they can walljump. It should be impossible to die in any of the following
    1. walljump is jump right, then left to higher ground
    2. wall jump is the same but with a limited sticky area
    3. wall jump is jump right, the steer right over the same platform
    4. wall jump is against an all-sticky wall, the player has to do multiple chained wall jumps to get up it
    5. again only one wall, but with slippery spots in between the sticky ones, add coins to slippery part to force player to slip down to get it
    6. final test, inside cavern where the player has to jump from one wall to the other, including onto the same wall again, with sticky patches in between, then checkpoint
    7. Jump from elevation into vertical tunnel, player has to hold against slippery wall which transitions into sticky wall to break their fall, bottom of tunnel is deathplane, but very right on the same wall as the sticky break area is small platform you cannot jump to directly
  
+ ROTATION: rotating anything
    1. long thin rectangular slippery platform rotating around center, player has to wait for the platform to align with the ground to jump to elevation
    2. long rectangular platform tiliting on it center without rotating, player has to jump when platform is on the floor left, wait for one cycle, then be on the right as it rises to reach platform. make it impossible to get below the platform
    3. three square rotating slippery platforms, player has to jump from one cube to another, timing with the rotations. Make the top most cube rotate fastest

+ HOOK: teach how to hook, release with down, skip down by holding down, and to hold jump to 
    1. all-slippery platform, player has to jump into hook, then jump onto elevation
    2. two hooks, player has to jump from hook to hook to elevation
    3. three hooks with the last too far to jump form previous hook directly, player has to jump from 2nd to wall, the walljump to 3rd
    4. many hooks in a line above, so many the player should discover instant jump
    5. from high platform jump down a tunnel of hooks, player discovers holding down to skip 
    6. hooks in horizontal line, player has to jump from one hook to another to cross distances 

+ BOUNCE PAD: 
    1. flat long recangular bouncepad instead of floor so player gets a feel for bouncing
    2. solid floor with slippery wall, player has to jump onto a bouncepad to reach elevation
    3. solid floor with slippery wall, player has to jump from one bouncepad to another to reach elevation 
    4. Poppable square bounce pad follow by poppable circular one, player has to travel over both without falling (no deaths)
    5. triangular bounce pad that rotates. Player has to jump on top, bounce up, wait for the pad to rotate, then release to jump to platform 
low horizontal tunnel, to and bottom are bounce pads, leadings into corner to thing vertical tunnel
    6. leads into room with complex polygonal platforms, player should have to move to the right, back to the left, back to right on different levels of platforms to reach final elevation

+ BUBBLE: teach float, entering / exiting bubble field in all directions
    1. open room with vertical slippery wall, only bubble field allows player to get to elevation
    2. open room with bounce pads at the top of bottom, and margin above and below bubble field, player discovers entering / exiting without being able to leave
    3. vertical shaft with sticky and slippery platforms, player has to walljump from sticky into bubble field, move up some amount, then get out to walljump again
    4. before checkpoint, horizontal impossible to die bubble field that has hooks in it, player discovers how hooks interact with bubble 
    5. he bottom, if jumping without pressing inputs, player will hit death plane as bubble. player has to understand to hold up when entering the field to slow down bubble
    6. same checkpoint as before, bubble field with various obstacles, first walls, then hooks, bouncepads, death barriers. checkpoint after this?

+ BOOST FIELD:
  1. slippery vertical tunnel, player has to use boost field to get up
  2. slippery vertical wall, player has to use boost field to go up right, move another mid-air boost field on the left, then back to the right to reach elevation
  3. long gap and bubble field, player jumps into boost, which sends them into long horizontal bubble field, velocity carries them against slippery wall with up boost field, which sends them up outside of the bubble field
  4. long horizontal boost field boosting up, player has to ride at the top, add certain down boostfields that will kill the player if not avoided. down boost fields do not reach all the way ot the top

+ DOUBLE JUMP TETHER:
  1. slippery wall, player can only get high enough with double jump
  2. slippery wall, again, but at the top player has to jump, double jump, into walljump
  3. 
  
