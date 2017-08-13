# API

---
## Crane and Claw


### `ent_crane()`

Access through `st.crane`

Moves and is `dead` after `ttl_when_no_battery` ticks after `ent_battery.amount` is depleted.

When "shooting", a new `ent_claw(crane)` is created and stored in `st.claw`. While `st.claw` exists, crane thinks to be in shooting state


### `ent_claw(crane)`

Moves up and down, when colliding with things tagged `t_consumable` it sets itself to `.grabbing=true` and adds the other to `st.consumer(...)`. When moving down, it's `.go_down=true`.


---
## Battery and energy


### `ent_battery()`

Counts down `amount`, marks itself `nearly_empty`, creates `ent_energy()` until empty.


### `ent_energy()`

Blue energy light moving to the crane. Gets red when battery `nearly_empty`


## `ent_energy_fillup`

"Reverse engergy", flowing from crane to battery, when sucking up an enemy.


---
## Consumer

### `ent_consumer()` (as `st.consumer`)

Handles consuming of caught entities. `.add(entity)` and. Crane can only shoot again if consumer is not `.busy`


---
## Game State and Progression


### `st_game()`

Has `director`-function that steps though the game - from tutorial to enemy creation to making everything more difficult.

In `upd` waits some sec for `crane.dead_since` until switching to `sc_cameover()`