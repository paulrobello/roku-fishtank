| Probe | Kind | Expected | Measured | Error | Verdict |
|---|---|---|---|---|---|
| 1 blendColor white x 0x00FF00 | color | 0x00FF00 | 0x00FF00 | max channel diff 0 | PASS |
| 1 blendColor grey x 0xFF8000 | color | 0x804000 | 0x804000 | max channel diff 0 | PASS |
| 2 group 0.5 x poster 0.5 | color | 0x404040 | 0x404040 | max channel diff 0 | PASS |
| 2 reference poster 0.25 | color | 0x404040 | 0x404040 | max channel diff 0 | PASS |
| 3 rotate+scale red corner | position | (858.2, 300.0) | (858.0, 300.0) | 0.2 px (0.01% W) | PASS |
| 3 rotate+scale blue corner | position | (960.0, 198.2) | (960.0, 198.0) | 0.2 px (0.01% W) | PASS |
| 3 rotate+scale green bar | position | (1019.4, 359.4) | (1019.5, 359.5) | 0.1 px (0.01% W) | PASS |
| 4 reference red | position | (1208.0, 252.0) | (1208.0, 252.0) | 0.0 px (0.00% W) | PASS |
| 4 scale -1 red (unmirrored) | position | (1384.0, 252.0) | (1384.0, 252.0) | 0.0 px (0.00% W) | PASS |
| 4 scale -1 blue (unmirrored) | position | (1480.0, 252.0) | (1480.0, 252.0) | 0.0 px (0.00% W) | PASS |
| 5 pivot A (white) | position | (1616.0, 440.0) | (1616.0, 440.0) | 0.0 px (0.00% W) | PASS |
| 5 group B origin (yellow) | position | (1685.3, 400.0) | (1685.3, 400.0) | 0.0 px (0.00% W) | PASS |
| 5 group C origin (cyan) | position | (1725.3, 330.7) | (1725.4, 330.6) | 0.2 px (0.01% W) | PASS |
| 5 arm tip (magenta) | position | (1725.3, 250.7) | (1725.5, 250.6) | 0.2 px (0.01% W) | PASS |
| 6 lane io16 (nominal t=4 s) | position | (287.0, 592.0) | (286.5, 592.0) | 0.5 px (0.03% W) | PASS |
| 6 lane io8 (nominal t=4 s) | position | (812.0, 652.0) | (809.5, 652.0) | 2.5 px (0.13% W) | PASS |
| 6 lane io5 (nominal t=4 s) | position | (1337.0, 712.0) | (1336.0, 712.0) | 1.0 px (0.05% W) | PASS |
| 6 lane li16 (nominal t=4 s) | position | (512.0, 792.0) | (511.5, 792.0) | 0.5 px (0.03% W) | PASS |
| 6 lane li8 (nominal t=4 s) | position | (812.0, 852.0) | (811.0, 852.0) | 1.0 px (0.05% W) | PASS |
| 6 lane li5 (nominal t=4 s) | position | (1112.0, 912.0) | (1111.0, 912.0) | 1.0 px (0.05% W) | PASS |
| 7 swatch c16 f=0.25 | color | 0xFFFF00 (HSV no wrap; shortest hue path would be 0xFF0080) | 0xFFFF00 | max channel diff 0 | PASS |
| 7 swatch c8 f=0.5 | color | 0x00FF00 (HSV no wrap; shortest hue path would be 0xFF00FF) | 0x01FF00 | max channel diff 1 | PASS |
| 7 swatch c5 f=0.75 | color | 0x00FFFF (HSV no wrap; shortest hue path would be 0x8000FF) | 0x00FFFE | max channel diff 1 | PASS |
| fraction probe (unscored) | position | x 1662 if direct fraction drives, 1512 if ignored | x 1662.0 | - | info |
