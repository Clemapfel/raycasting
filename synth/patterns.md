# SuperCollider Pattern Reference

> **Note on Pattern Coverage**  
> This document covers the majority of standard patterns found in SuperCollider’s core library. Some patterns listed here are either undocumented (`Peventmod`), not part of the core distribution (`Pprob`, chaotic maps like `PlinCong`, `Pquad`, etc.), or come from third‑party extensions. Where ambiguity exists, I have added clarifying notes.

---

## List Iteration & Indexing
*Traversing pre‑defined lists in structured, non‑random ways.*

| Pattern | Common Description | Formula / Description |
| :------ | :------------------ | :--------------------- |
| `Pseq(list, repeats, offset)` | Outputs a sequence of values from a list, cycling through the list `repeats` times. | `x_n = L[(n + offset) mod |L|]`, for `n = 0 … repeats·|L| - 1` |
| `Pser(list, repeats, offset)` | Outputs a fixed total number of individual values from a list (does not require full cycles). | Same as `Pseq` but `n = 0 … repeats - 1` (total item count fixed) |
| `Pslide(list, repeats, len, step, start, wrapAtEnd)` | Creates a sliding window over the list. Each segment is a window of `len` items; the window moves by `step` each time. | Segment `k` = `L[(start + k·step) … (start + k·step + len - 1)] mod |L|` |
| `Pwalk(list, stepPattern, directionPattern, startPos)` | Walks through a list using a step pattern and a direction pattern; direction reverses at list boundaries. | `i_n = i_{n-1} + dir_n · step_n` (index into `L`), `x_n = L[i_n]` |
| `Pindex(listPat, indexPat, wrapAtEnd)` | Uses a stream of indices to look up values in a list. | `x_n = L[ i_n mod |L| ]`, where `i_n = next(indexPat)` |
| `Pswitch(list, whichPat)` | Switches between different sub‑patterns. **Important:** `Pswitch` embeds the entire selected sub‑pattern before moving to the next index; for one‑value‑per‑index use `Pswitch1`. | `x_n = next( L[ next(whichPat) ] )` — each step picks a sub‑pattern and draws from it until exhausted. |

---

## Interleaving & Bundling
*Weaving together several distinct lists or patterns.*

| Pattern | Common Description | Formula / Description |
| :------ | :------------------ | :--------------------- |
| `Place(list, repeats, offset)` | Interlaces elements from sub‑lists, cycling through sub‑lists and their internal elements. | Outputs items from sub‑arrays `L[n mod |L|]`, cycling one index deeper each full pass. |
| `Ppatlace(list, repeats, offset)` | Interlaces values from a list of sub‑patterns in a round‑robin fashion. | `x_n = next( L[n mod |L|] )` — draws one value from each sub‑pattern sequentially. |
| `Ptuple(list, repeats)` | Collects simultaneous values from multiple patterns into a single array/tuple. | `x_n = ( next(P1), …, next(Pk) )` — bundles concurrent values. |

---

## Repetition, Timing & Constraints
*Controlling flow, duration, and how many times patterns play.*

| Pattern | Common Description | Formula / Description |
| :------ | :------------------ | :--------------------- |
| `Pn(pattern, repeats)` | Repeats an entire sub‑pattern a specified number of times. | Concatenate `pattern`’s full output `repeats` times. |
| `Pdup(n, pattern)` | Repeats each individual value from a pattern `n` times. | Each drawn value `v_k` is emitted `n` times: `x_{kn+i} = v_k` |
| `Psubdivide(n, pattern)` | Repeats each value while dividing its value (often duration) by `n` to keep overall time constant. | `x_{kn+i} = v_k / n` (total duration per original item remains the same) |
| `Pstep(levels, durs, repeats)` | Holds a value for a specified duration, then steps to the next. | Hold `levels[i]` constant for `durs[i]`, then advance to `i+1`. |
| `Ptime(repeats)` | Outputs the elapsed time in beats since the pattern started. | `x_n = t_now - t_embed` (beats since stream began) |
| `Pfin(count, pattern)` | Limits a pattern to a hard maximum number of items. | `x_n = next(pattern)` for `n = 0 … count-1`, then stop. |
| `Pconst(sum, pattern, tolerance)` | Limits a value stream so the total sum hits a specific target exactly. | Emit until `Σ x_n ≥ sum - tolerance`; last value trimmed to make `Σ x_n = sum`. |
| `Pfindur(dur, pattern, tolerance)` | Limits an event stream so its total *duration* (sum of `\dur` fields) hits a specific target. | Same as `Pconst`, but summing `dur` fields of events: `Σ dur_n = dur` exactly. |
| `Psync(pattern, quant, maxdur, tolerance)` | Like `Pfindur` but can also round up the final event’s duration to a multiple of `quant` if the pattern ends early. | Trims at `maxdur` if needed; otherwise rounds last `dur` up to a multiple of `quant`. |

---

## Mathematical Operations & Combinatorics
*Element‑wise or cross‑combined arithmetic and logic.*

| Pattern | Common Description | Formula / Description |
| :------ | :------------------ | :--------------------- |
| `Punop(selector, pattern)` | Applies a unary math operator (e.g., `.abs`, `.midicps`) to every value. | `x_n = selector( next(pattern) )` |
| `Pnaryop(selector, argList)` | Combines multiple pattern streams using an n‑ary operator. | `x_n = selector( next(P1), next(P2), … )` |
| `Pmul(pattern, mul, repeats)` | Multiplies each value from a pattern by a constant or another pattern. If `mul` is a pattern, the multiplication happens element‑wise. | `x_n = next(pattern) * (next(mul) if mul is a pattern else mul)` |
| `Pstep2add(list1, list2, repeats)` | Adds values from two lists at different stepping rates (combinatoric sums). | Produces sums `list1[i] + list2[j]` at stepped rates. |
| `Pstep3add(list1, list2, list3, repeats)` | Adds values from three lists combinatorially. | `list1[i] + list2[j] + list3[k]` |
| `PstepNfunc(lists, func, repeats)` | Combines multiple lists through a custom function combinatorially. | Feed combinations of `N` lists through an arbitrary function. |
| `Pclutch(pattern, connected)` | Sample‑and‑hold: freezes the current value when `connected` becomes false. | `x_n = next(pattern)` if `connected_n` true, else `x_n = x_{n-1}`. |
| `Pif(condition, iftrue, iffalse, default)` | Branches between two patterns based on a boolean condition stream. | Draws from `iftrue` when condition true, else from `iffalse`. |

---

## Continuous & Statistical Distributions
*Procedural number generation via probability distributions or random walks.*

| Pattern | Common Description | Formula / Description |
| :------ | :------------------ | :--------------------- |
| `Pwhite(lo, hi, length)` | Uniform random numbers. | `x_n ~ Uniform(lo, hi)` |
| `Pexprand(lo, hi, length)` | Exponential distribution (good for pitch/freq). | `x_n = lo·(hi/lo)^u`, with `u ~ Uniform(0,1)` |
| `Pbrown(lo, hi, step, length)` | Additive Brownian motion (random walk). | `x_n = clamp(x_{n-1} + δ, lo, hi)`, `δ ~ Uniform(-step, step)` |
| `Pgbrown(lo, hi, step, length)` | Geometric Brownian motion (multiplicative). | `x_n = clamp(x_{n-1}·(1+δ), lo, hi)`, `δ ~ Uniform(-step, step)` |
| `Pbeta(lo, hi, prob1, prob2, length)` | Beta‑distributed numbers (clustered). | `x_n = lo + (hi-lo)·B`, `B ~ Beta(α=prob1, β=prob2)` |
| `Pcauchy(mean, spread, length)` | Cauchy distribution (central with rare outliers). | `x_n = mean + spread·tan(π(u-½))`, `u ~ Uniform(0,1)` |
| `Pgauss(mean, dev, length)` | Gaussian (normal) distribution. | `x_n ~ N(mean, dev²)` |
| `Phprand(lo, hi, length)` | Bias toward high end (max of two draws). | `x_n = max(u1, u2)`, `u1,u2 ~ Uniform(lo,hi)` |
| `Plprand(lo, hi, length)` | Bias toward low end (min of two draws). | `x_n = min(u1, u2)` |
| `Pmeanrand(lo, hi, length)` | Cluster around centre (average of two draws). | `x_n = (u1+u2)/2` |
| `Ppoisson(mean, length)` | Poisson‑distributed integers. | `P(x_n = k) = mean^k e^{-mean} / k!` |
| `Pprob(distribution, lo, hi, length, tableSize)` | *(Not a core pattern)* Custom probability table over `[lo,hi]`. | If available, draws from a user‑defined probability histogram. |

---

## Discrete Random Selection
*Random picks from a predefined finite set.*

| Pattern | Common Description | Formula / Description |
| :------ | :------------------ | :--------------------- |
| `Prand(list, repeats)` | Random item from a list with replacement. | `x_n ~ Uniform(L)` i.i.d. |
| `Pxrand(list, repeats)` | Random item, never repeats the same item twice in a row. | `x_n ~ Uniform(L)` subject to `x_n ≠ x_{n-1}` |
| `Pshuf(list, repeats)` | Shuffles the list once and repeats that random order. | Pick one random permutation `π`; `x_n = π[n mod |L|]` |
| `Pwrand(list, weights, repeats)` | Weighted random selection. | `P(x_n = L[i]) = w_i / Σw_j` |

---

## Deterministic Math & Chaotic Maps
*Arithmetic sequences, recurrences, and chaotic attractors.*  
**Note:** Many of these (chaotic maps) are not part of the core distribution; they may be found in extensions or contributed libraries.

| Pattern | Common Description | Formula / Description |
| :------ | :------------------ | :--------------------- |
| `Pseries(start, step, length)` | Arithmetic progression. | `x_n = start + n·step` |
| `Pgeom(start, grow, length)` | Geometric progression. | `x_n = start·growⁿ` |
| `PlinCong(a, c, m, x0, length)` | Linear congruential generator (pseudo‑random). | `x_{n+1} = (a·x_n + c) mod m` |
| `Pquad(a, b, c, x0, length)` | Quadratic map (chaotic). | `x_{n+1} = a·x_n² + b·x_n + c` |
| `Pgbman(x0, y0, length)` | Gingerbreadman map (2D chaotic). | `x_{n+1} = 1 - y_n + |x_n|`, `y_{n+1} = x_n` |
| `Phenon(a, b, x0, x1, length)` | Hénon map (2D chaotic). | `x_{n+1} = 1 - a·x_n² + b·x_{n-1}` |
| `Platoo(a, b, c, d, x0, y0, length)` | Latoocarfian map (chaotic). | `x_{n+1} = sin(b·y_n) + c·sin(b·x_n)`<br>`y_{n+1} = sin(a·x_n) + d·sin(a·y_n)` |
| `Pfhn(a, b, c, d, freq, dt, x0, y0, z0, length)` | FitzHugh‑Nagumo neuron model (chaotic voltage). | Iterates discretized FHN ODEs; returns chaotic voltage. |
| `Plorenz(freq, dt, s, r, b, x0, y0, z0, length)` | Lorenz attractor (3D chaotic trajectory). | Iterates discretized Lorenz ODEs; returns trajectory values. |

---

## Event Generation & Sound Sequencing
*Building and playing musical events with SuperCollider synths.*

| Pattern | Common Description | Formula / Description |
| :------ | :------------------ | :--------------------- |
| `Pbind(*pairs)` | Combines key‑value streams into an Event stream to trigger synths. | `e_n = { key1: next(P1), key2: next(P2), … }` |
| `Pmono(instrumentName, *pairs)` | Plays a single continuous synth and modulates its arguments over time. | Reuses one synth, updating its controls instead of retriggering. |
| `Pchain(patterns)` | Chains event patterns sequentially; earlier patterns’ keys override later ones. | Evaluates right‑to‑left, merging events: `e_n = e_n^(1) ∪ e_n^(2) ∪ …` |
| `Pproto(makeFunc, pattern, cleanupFunc)` | Allocates server resources (buffers/buses) before playing, cleans up after. | Injects resources into events; calls cleanup on stop. |
| `Pstandard(pattern)` | *(Undocumented / non‑core)* Purported to coerce arbitrary patterns into standard event streams. | Exact behaviour not officially defined. |

---

## Environments & Data Routing
*Managing shared state, scoped namespaces, and dictionary lookups.*

| Pattern | Common Description | Formula / Description |
| :------ | :------------------ | :--------------------- |
| `Pkey(key, default)` | Reads a key from the current event environment. | `x_n = e_n[key]` (from the input event) |
| `Pget(key, default)` | Reads a variable from an enclosing `Plambda` environment. | `x_n = scope[key]` (from `Plambda`’s namespace) |
| `Plet(key, pattern)` | Writes a value into a `Plambda` environment for later retrieval. | Writes `next(pattern)` into `scope[key]`. |
| `Penvir(envir, pattern, inEvent)` | Evaluates a pattern inside a custom environment dictionary. | Resolves variables against `envir`. |
| `Pdict(dict, repeats, keyPattern)` | Uses a key stream to look up sub‑patterns in a dictionary. | `x_n = next( dict[ next(keyPattern) ] )` |
| `Pevent(pattern, event)` | Wraps a value stream, merging outputs into a prototype event. | Merges each output into the given `event` prototype. |
| `Peventmod(pattern, function)` | *(Undocumented)* Passes every generated event through a modifying function. | `e_n = function(e_n)` — plausibly used for event transformation. |

---

## Functional & Procedural Callbacks
*Delegating generation logic to custom functions or routines.*

| Pattern | Common Description | Formula / Description |
| :------ | :------------------ | :--------------------- |
| `Pfunc(nextFunc, resetFunc)` | Generates values by evaluating a custom function each step. | `x_n = nextFunc()`; stops if `nil` is returned. |
| `Pfuncn(func, repeats)` | Calls a custom function a fixed number of times. | `x_n = func()` for `n = 0 … repeats-1`. |
| `Prout(routineFunc)` | Generates values from a routine/coroutine that yields. | `x_n = nth value yielded by routineFunc`. |
| `Plazy(func)` | Defers pattern creation until embed time, allowing dynamic structure. | Calls `func` to build a new pattern when played. |
| `Ppatmod(pattern, modFunc)` | Passes the pattern object itself through a modifier function before streaming. | `modFunc(pattern)` is called before spawning the stream. |