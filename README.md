# Black Hole Simulation

A real-time black hole visualization for macOS, built with Metal. Rays are traced through curved spacetime using 4th-order Runge-Kutta integration of geodesic equations, producing gravitational lensing, photon orbits, and an event horizon. An accretion disk of 500,000 particles follows Keplerian orbits and is rendered via Gaussian splatting into a density texture sampled during ray marching. Relativistic Doppler shifting colors and brightens the approaching side of the disk. Post-processing applies multi-level bloom and ACES tone mapping, with EDR roll-off for HDR displays.

![screenshot](black_hole.jpg?raw=true "Black Hole")

## Controls

| Keys          | Actions                 |
| ------------- | ------------------------|
| ,             | reduce exposure         |
| .             | increase exposure       |
| /             | reset exposure          |
| Esc           | release mouse           |
