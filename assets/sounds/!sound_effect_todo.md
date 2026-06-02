# Overworld

## AcceleratorSurface

accelerator_surface_velocity_ramp
    rainbow road sparkles raise in pitch as player accelerators
    sound of glass crystals being shaken in a glass
    
accelerator_surface_contact_start
    initial sound when touching the surface, overrides regular hitbox sound

accelerator_surface_contact_end
    only triggered when resolving a jump while touching
    undoes `accelerator_surface_contact_start`

accelerator_surface_particle_lifetime
    gaussian ramp with that decays in volume with particle lifetime


## AirDashNode

air_dash_node_current_start
    when manager assign node as current, as AirDashNodeParticle aligns to player position
    slow fade in confirmation noise
    if node becomes recommend, subtle noise, but if node becomes current, more aggressive 
    noise so player can use it as an audio queue for when they are in range
    
air_dash_node_current_end
    as AirDashNodeParticle realigns to default state

air_dash_node_dash
    when manager tethers
    sound goes on as long as player it tethered
    soft resets on chain, in a chain pitch to another note in the current scale

air_dash_node_dash_fade
    when manager untethers without it being a chain
    slow fade out, like a fireworks accelerating into the air

air_dash_node_particle_emission
    ramp in, then slow fizzle out that is synched with particle progress
    more fizz at the start, as particles are faster then
    fizz out as particles decelerate / dissappear
    similar to the foa of a fizzy soda or the post-explosion noise of firework particles burning out

## BoostField

boost_field_enter
    subtle confirmation noise once player enters new boostfield hitbox,
    not that necessary but should have some effect

boost_field_active
    fly-wheel like spin up, increasing in pitch as player accelerates towards target velocity. 
    Once player leaves field, continue playing flywheel sound as it fades out and goes back to low pitch
    each bootsfield should have a new note of the scale as a pitch, randomized

## BouncePad

bounce_pad_collision
    "boioing" synched with bounce velocity magnitude, sweep timed with shader animation
    each pad has it's own pre-determined pitch from level scale
    make sure that overlapping when quickly bouncing between two pads can't cause clipping

## Bubble

bubble_pop
    "blub" sound starting on frame player collides with bubble
    
bubble_respawn
    filter-sweep that is synched with bubble opacity





