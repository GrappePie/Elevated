# Elevated Project

This repository contains the assets and code for a Roblox experience split across two places:

## places/elevated
* **Lobby hub** where multiple elevators queue players.
* After a countdown, players in an elevator are teleported to a game server.
* Includes utilities such as animation handlers, timers, tweening helpers and DataStore profile management.

## places/game
* **Procedural map** that players enter inside an elevator.
* Players must complete objectives to reactivate the elevator and move to another map.
* Features monster AI with patrol states, perception (vision & hearing) and attacks.
* Uses shared modules for flow control, object pooling, randomization and more.

### Shared Modules
Common helper functions live under `places/game/src/ReplicatedStorage/Modules/combinedFunctions` and drive conventions for the project.

---
Built with [Rojo](https://github.com/rojo-rbx/rojo) and managed via [Rokit](https://github.com/rojo-rbx/rokit).
