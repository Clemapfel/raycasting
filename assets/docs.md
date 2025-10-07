# Classes

```
## ClassName

Types: Polygon, Circle, Rectangle, Point, Sprite



```

### ClassName

| Polygon | Circle | Rectangle | Point | Sprite |
|--------|-------|----------|------|-------|
| OX     | OX    | OX       | OX   | OX    |

| Property | Type | Values | Optional |
|--------|------|-----|-----------|
|        |      |     | |



### AcceleratorSurface

| Polygon | Circle | Rectangle | Point | Sprite |
|-------|------|---------|-----|------|
| O     | O    | O       | X   | X    |

| Property Name | Type   | Values | Optional |
|---------------|--------|--------|----------
| `friction`      | Float? | `<= 0`   | y

### BoostField

| Polygon | Circle | Rectangle | Point | Sprite |
|-------|------|---------|-----|------|
| O     | O    | O       | X   | X    |

| Property  | Type  | Values |
|-----------|-------|------|
| `velocity` | Float | `> 0`  |
| `axis` | Object | `BoostFieldAxis`   |

### BoostFieldAxis

| Polygon | Circle | Rectangle | Point | Sprite |
|-------|------|---------|-------|------|
| X     | X    | X       | O     | X    |

| Property | Type  | Values   |
|----------|-------|----------|
| `axis_x` | Float | `[-1, 1]` |
| `axis_x` | Float | `[-1, 1]` |




