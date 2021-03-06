# API

---
## Crane and Claw


### `ent_crane()`

Access through `st.crane`

Moves and is `dead` after `ttl_when_no_battery` ticks after `ent_battery.amount` is depleted.

When "shooting", a new `ent_claw(crane)` is created and stored in `st.claw`. While `st.claw` exists, crane thinks to be in shooting state

    x,y,spd
    dead


### `ent_claw(crane)`

Moves up and down, when colliding with things tagged `t_consumable` it sets itself to `.grabbing=true` and adds the other to `st.consumer(...)`. When moving down, it's `.go_down=true`.


---
## Battery and energy


### `ent_battery()`

Counts down `amount`, marks itself `nearly_empty`, creates `ent_energy()` until empty.

    amount
    bar ={x,y,w,h}
    lose_energy
    full


### `ent_energy()`

Blue energy light moving to the crane. Gets red when battery `nearly_empty`


## `ent_energy_fillup`

"Reverse engergy", flowing from crane to battery, when sucking up an enemy.


---
## Consumer

### `ent_consumer()` (as `st.consumer`)

Handles consuming of caught entities. `.add(entity)` and. If crane shoots while consumer is `.busy`, it will launch the orb instead of it's claw. This is the only way to attack opponents.

    add(entity)

---
## Game State and Progression


### `st_game()`

Creates crane, claw, ... and **director**

Has `director`-entity that steps though the game - from tutorial to enemy creation to making everything more difficult.

### `director()`

Entity that handles the "game phases", from tutorial to gameover after `crane.dead`. `phases`-array holds function-links with args that return `{upd, ?drw}`objects and automatically steps to next phase-item whenever a `phase.upd()` returns `true`.