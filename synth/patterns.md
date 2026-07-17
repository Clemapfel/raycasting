# Patterns

## Pbind
valid keys: 
+ `instrument` name of the synthdef to trigger
+ `degree` music pitch, e.g. 440 for A4
+ `dur` duration of the note, where 1 is one beat
+ `stretch` note duration multiplier
+ `lag` note delay
+ `strum` takes array of keys, plays all of them at the same time
+ `legato`, `sustain`: target envelope gate, require Env.asr
+ `amp` volume, where 1 is the default volume
+ `out` output bus

## Composition
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pbindf`](https://doc.sccode.org/Classes/Pbindf.html) | `Pbindf(pattern, * pairs)` | bind several value patterns to one existing event stream by binding keys to values |
| [`Pchain`](https://doc.sccode.org/Classes/Pchain.html) | `Pchain(* patterns)` | pass values from stream to stream |

---

## Time
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pseg`](https://doc.sccode.org/Classes/Pseg.html) | `Pseg(valPattern, durPattern, curvePattern, repeats: 1)` | timed embedding of values |
| [`Pstep`](https://doc.sccode.org/Classes/Pstep.html) | `Pstep(levels, durs, repeats: 1)` | timed, sample-and-hold embedding of values |
| [`PstepNadd`](https://doc.sccode.org/Classes/PstepNadd.html) | `PstepNadd(patternA, patternB)` | pattern that returns combinatoric sums |
| [`PstepNfunc`](https://doc.sccode.org/Classes/PstepNfunc.html) | `PstepNfunc(func, patternList)` | combinatoric pattern |
| [`Ptime`](https://doc.sccode.org/Classes/Ptime.html) | `Ptime(repeats: inf)` | returns time in beats from moment of embedding in stream |

---

## Language Control
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pif`](https://doc.sccode.org/Classes/Pif.html) | `Pif(condition, ifTrue, ifFalse, default)` | Pattern-based conditional expression |
| [`Pprotect`](https://doc.sccode.org/Classes/Pprotect.html) | `Pprotect(pattern, errorFunc)` | evaluate a function when an error occurred in the thread |
| [`Pseed`](https://doc.sccode.org/Classes/Pseed.html) | `Pseed(seed, pattern)` | set the random seed in subpattern |
| [`Pwhile`](https://doc.sccode.org/Classes/Pwhile.html) | `Pwhile(func, pattern)` | While a condition holds, repeatedly embed stream |

---

## List
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pboolnet`](https://doc.sccode.org/Classes/Pboolnet.html) | `Pboolnet(structure, repeats: 1)` | Boolean network pattern |
| [`Pclump`](https://doc.sccode.org/Classes/Pclump.html) | `Pclump(n, pattern)` | A pattern that takes another pattern and groups its values into arrays. |
| [`Pgeom`](https://doc.sccode.org/Classes/Pgeom.html) | `Pgeom(start, grow, length)` | geometric series pattern |
| [`Place`](https://doc.sccode.org/Classes/Place.html) | `Place(list, repeats: 1)` | interlaced embedding of subarrays |
| [`Ppatlace`](https://doc.sccode.org/Classes/Ppatlace.html) | `Ppatlace(list, repeats: 1)` | interlace streams |
| [`Prand`](https://doc.sccode.org/Classes/Prand.html) | `Prand(list, repeats: 1)` | embed values randomly chosen from a list |
| [`Pseq`](https://doc.sccode.org/Classes/Pseq.html) | `Pseq(list, repeats: 1, offset: 0)` | sequentially embed values in a list |
| [`Pser`](https://doc.sccode.org/Classes/Pser.html) | `Pser(list, repeats: 1, offset: 0)` | sequentially embed values in a list |
| [`Pseries`](https://doc.sccode.org/Classes/Pseries.html) | `Pseries(start: 0, step: 1, length: inf)` | arithmetic series pattern |
| [`Pshuf`](https://doc.sccode.org/Classes/Pshuf.html) | `Pshuf(list, repeats: 1)` | sequentially embed values in a list in constant, but random order |
| [`Pslide`](https://doc.sccode.org/Classes/Pslide.html) | `Pslide(list, repeats: 1, len: 3, step: 1, start: 0, wrapAtEnd: true)` | slide over a list of values and embed them |
| [`Ptuple`](https://doc.sccode.org/Classes/Ptuple.html) | `Ptuple(list, repeats: 1)` | combine a list of streams to a stream of lists |
| [`Pwalk`](https://doc.sccode.org/Classes/Pwalk.html) | `Pwalk(list, stepPattern, directionPattern, startPos: 0)` | A one-dimensional random walk over a list of values that are embedded |
| [`Pwrand`](https://doc.sccode.org/Classes/Pwrand.html) | `Pwrand(list, weights, repeats: 1)` | embed values randomly chosen from a list |
| [`Pxrand`](https://doc.sccode.org/Classes/Pxrand.html) | `Pxrand(list, repeats: 1)` | embed values randomly chosen from a list |

---

## Repetition
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pclutch`](https://doc.sccode.org/Classes/Pclutch.html) | `Pclutch(pattern, connected)` | sample and hold a pattern |
| [`Pconst`](https://doc.sccode.org/Classes/Pconst.html) | `Pconst(sum, pattern, tolerance: 0.001)` | constrain the sum of a value pattern |
| [`Pdup`](https://doc.sccode.org/Classes/Pdup.html) | `Pdup(n, pattern)` | repeat input stream values |
| [`PdurStutter`](https://doc.sccode.org/Classes/PdurStutter.html) | `PdurStutter(n, pattern)` | partition a value into n equal subdivisions |
| [`Pfin`](https://doc.sccode.org/Classes/Pfin.html) | `Pfin(count, pattern)` | limit number of events embedded in a stream |
| [`Pfindur`](https://doc.sccode.org/Classes/Pfindur.html) | `Pfindur(dur, pattern, tolerance: 0.001)` | limit total duration of events embedded in a stream |
| [`Pfinval`](https://doc.sccode.org/Classes/Pfinval.html) | `Pfinval(count, pattern)` | limit number of items embedded in a stream |
| [`Pgate`](https://doc.sccode.org/Classes/Pgate.html) | `Pgate(pattern, key)` | A gated stream that only advances when a particular event key is true. |
| [`Pn`](https://doc.sccode.org/Classes/Pn.html) | `Pn(pattern, repeats: inf)` | repeatedly embed a pattern |
| [`Pstutter`](https://doc.sccode.org/Classes/Pstutter.html) | `Pstutter(n, pattern)` | repeat input stream values |
| [`Psubdivide`](https://doc.sccode.org/Classes/Psubdivide.html) | `Psubdivide(n, pattern)` | partition a value into n equal subdivisions |
| [`Psync`](https://doc.sccode.org/Classes/Psync.html) | `Psync(pattern, quant, maxdur, tolerance: 0.001)` | synchronise and limit pattern duration |

---

## Math
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Padd`](https://doc.sccode.org/Classes/Padd.html) | `Padd(name, value, pattern)` | add to value of a key in event stream |
| [`Paddp`](https://doc.sccode.org/Classes/Paddp.html) | `Paddp(name, value, pattern)` | add each value of a pattern to the value at a key in event stream |
| [`Paddpre`](https://doc.sccode.org/Classes/Paddpre.html) | `Paddpre(name, value, pattern)` | event pattern that adds to existing value of one key |
| [`Pavaroh`](https://doc.sccode.org/Classes/Pavaroh.html) | `Pavaroh(pattern, scale, stepsPerOctave: 12)` | applying ascending and descending scales to event stream |
| [`Pbinop`](https://doc.sccode.org/Classes/Pbinop.html) | `Pbinop(operator, a, b, adicat)` | binary operator pattern |
| [`PdegreeToKey`](https://doc.sccode.org/Classes/PdegreeToKey.html) | `PdegreeToKey(pattern, scale, stepsPerOctave: 12)` | index into a scale |
| [`Pmul`](https://doc.sccode.org/Classes/Pmul.html) | `Pmul(name, value, pattern)` | multiply with value of a key in event stream |
| [`Pmulp`](https://doc.sccode.org/Classes/Pmulp.html) | `Pmulp(name, value, pattern)` | multiply with each value of a pattern to value of a key in event stream |
| [`Pmulpre`](https://doc.sccode.org/Classes/Pmulpre.html) | `Pmulpre(name, value, pattern)` | multiplies with value of a key in event stream, before it is passed up |
| [`Pnaryop`](https://doc.sccode.org/Classes/Pnaryop.html) | `Pnaryop(operator, a, arglist)` | n-ary operator pattern |
| [`Prorate`](https://doc.sccode.org/Classes/Prorate.html) | `Prorate(proportion, pattern)` | divide stream proportionally |
| [`Punop`](https://doc.sccode.org/Classes/Punop.html) | `Punop(operator, a)` | unary operator pattern |
| [`Pwrap`](https://doc.sccode.org/Classes/Pwrap.html) | `Pwrap(pattern, lo, hi)` | constrain the range of output values by wrapping |

---

## Random
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pbeta`](https://doc.sccode.org/Classes/Pbeta.html) | `Pbeta(lo: 0.0, hi: 1.0, prob1: 1.0, prob2: 1.0, length: inf)` | random values that follow a Eulerian Beta Distribution |
| [`Pbrown`](https://doc.sccode.org/Classes/Pbrown.html) | `Pbrown(lo: 0.0, hi: 1.0, step: 0.1, length: inf)` | brownian motion pattern |
| [`Pcauchy`](https://doc.sccode.org/Classes/Pcauchy.html) | `Pcauchy(mean: 0.0, spread: 1.0, length: inf)` | random values that follow a Cauchy Distribution |
| [`Pexprand`](https://doc.sccode.org/Classes/Pexprand.html) | `Pexprand(lo: 0.0001, hi: 1.0, length: inf)` | random values that follow a Exponential Distribution |
| [`Pgauss`](https://doc.sccode.org/Classes/Pgauss.html) | `Pgauss(mean: 0.0, dev: 1.0, length: inf)` | random values that follow a Gaussian Distribution |
| [`Pgbrown`](https://doc.sccode.org/Classes/Pgbrown.html) | `Pgbrown(lo: 0.0, hi: 1.0, step: 0.1, length: inf)` | geometric brownian motion pattern |
| [`Phprand`](https://doc.sccode.org/Classes/Phprand.html) | `Phprand(lo: 0.0, hi: 1.0, length: inf)` | random values that tend toward hi |
| [`Plorenz`](https://doc.sccode.org/Classes/Plorenz.html) | `Plorenz(xi: 0.1, yi: 0, zi: 0, s: 10, r: 28, b: 2.666, h: 0.01, length: inf)` | lorenz 3D chaotic pattern |
| [`Plprand`](https://doc.sccode.org/Classes/Plprand.html) | `Plprand(lo: 0.0, hi: 1.0, length: inf)` | random values that tend toward lo |
| [`Pmeanrand`](https://doc.sccode.org/Classes/Pmeanrand.html) | `Pmeanrand(lo: 0.0, hi: 1.0, length: inf)` | random values that tend toward ((lo + hi) / 2) |
| [`Ppoisson`](https://doc.sccode.org/Classes/Ppoisson.html) | `Ppoisson(mean: 1.0, length: inf)` | random values that follow a Poisson Distribution (positive integer values) |
| [`Pprob`](https://doc.sccode.org/Classes/Pprob.html) | `Pprob(distribution, lo: 0.0, hi: 1.0, length: inf, tableSize: 200)` | random values with arbitrary probability distribution |
| [`Pwhite`](https://doc.sccode.org/Classes/Pwhite.html) | `Pwhite(lo: 0.0, hi: 1.0, length: inf)` | random values with uniform distribution |

---

## Filter
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pcollect`](https://doc.sccode.org/Classes/Pcollect.html) | `Pcollect(func, pattern)` | Apply a function to a pattern |
| [`PfadeIn`](https://doc.sccode.org/Classes/PfadeIn.html) | `PfadeIn(pattern, fadeTime, holdTime, tolerance: 0.001)` | Fade an event pattern in |
| [`PfadeOut`](https://doc.sccode.org/Classes/PfadeOut.html) | `PfadeOut(pattern, fadeTime, holdTime, tolerance: 0.001)` | Fade an event pattern out |
| [`Ppatmod`](https://doc.sccode.org/Classes/Ppatmod.html) | `Ppatmod(pattern, func, repeats: 1)` | modify a given pattern before passing it into the stream |
| [`Preject`](https://doc.sccode.org/Classes/Preject.html) | `Preject(func, pattern)` | Filters a source pattern by rejecting particular values. |
| [`Pselect`](https://doc.sccode.org/Classes/Pselect.html) | `Pselect(func, pattern)` | Filters values returned by a source pattern. |
| [`Pset`](https://doc.sccode.org/Classes/Pset.html) | `Pset(name, value, pattern)` | event pattern that sets values of one key |
| [`Psetp`](https://doc.sccode.org/Classes/Psetp.html) | `Psetp(name, value, pattern)` | event pattern that sets values of one key |
| [`Psetpre`](https://doc.sccode.org/Classes/Psetpre.html) | `Psetpre(name, value, pattern)` | set values of one key in an event before it is passed up |

---

## Function
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pfunc`](https://doc.sccode.org/Classes/Pfunc.html) | `Pfunc(nextFunc, resetFunc)` | Function pattern |
| [`Pfuncn`](https://doc.sccode.org/Classes/Pfuncn.html) | `Pfuncn(func, repeats: 1)` | Function pattern of given length |
| [`Plazy`](https://doc.sccode.org/Classes/Plazy.html) | `Plazy(func)` | instantiate new patterns from a function |
| [`PlazyEnvir`](https://doc.sccode.org/Classes/PlazyEnvir.html) | `PlazyEnvir(func)` | instantiate new patterns from a function |
| [`PlazyEnvirN`](https://doc.sccode.org/Classes/PlazyEnvirN.html) | `PlazyEnvirN(func)` | instantiate new patterns from a function and multichannel expand them |
| [`Prout`](https://doc.sccode.org/Classes/Prout.html) | `Prout(routineFunc)` | routine pattern |

---

## Parallel
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pgpar`](https://doc.sccode.org/Classes/Pgpar.html) | `Pgpar(list, repeats: 1)` | embed event streams in parallel and put each in its own group |
| [`Pgtpar`](https://doc.sccode.org/Classes/Pgtpar.html) | `Pgtpar(list, repeats: 1)` | embed event streams in parallel and put each in its own group, with time offset |
| [`Ppar`](https://doc.sccode.org/Classes/Ppar.html) | `Ppar(list, repeats: 1)` | embed event streams in parallel |
| [`Pspawn`](https://doc.sccode.org/Classes/Pspawn.html) | `Pspawn(pattern, spawnProtoEvent)` | Spawns sub-patterns based on parameters in an event pattern |
| [`Pspawner`](https://doc.sccode.org/Classes/Pspawner.html) | `Pspawner(func)` | dynamic control of multiple event streams from a Routine |
| [`Ptpar`](https://doc.sccode.org/Classes/Ptpar.html) | `Ptpar(list, repeats: 1)` | embed event streams in parallel, with time offset |

---

## Event
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pbind`](https://doc.sccode.org/Classes/Pbind.html) | `Pbind(* pairs)` | combine several value patterns to one event stream by binding keys to values |
| [`Pmono`](https://doc.sccode.org/Classes/Pmono.html) | `Pmono(synthName, * pairs)` | monophonic event stream |
| [`PmonoArtic`](https://doc.sccode.org/Classes/PmonoArtic.html) | `PmonoArtic(synthName, * pairs)` | partly monophonic event stream |

---

## Data Sharing
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Penvir`](https://doc.sccode.org/Classes/Penvir.html) | `Penvir(envir, pattern, independent: true)` | use an environment when embedding the pattern in a stream |
| [`Pfset`](https://doc.sccode.org/Classes/Pfset.html) | `Pfset(func, pattern)` | Insert an environment into the event prototype before evaluating the supplied pattern |
| [`Pget`](https://doc.sccode.org/Classes/Pget.html) | `Pget(key, default, envir)` | Retrieve a value within the scope (namespace) of a Plambda |
| [`Pkey`](https://doc.sccode.org/Classes/Pkey.html) | `Pkey(key, default)` | access a key in an event stream |
| [`Plambda`](https://doc.sccode.org/Classes/Plambda.html) | `Plambda(pattern, envir)` | create a scope (namespace) for enclosed streams |
| [`Plet`](https://doc.sccode.org/Classes/Plet.html) | `Plet(key, pattern, return)` | Define a value within the scope (namespace) of a Plambda |

---

## Server Control
| Pattern | Signature | Description |
| :--- | :--- | :--- |
| [`Pbus`](https://doc.sccode.org/Classes/Pbus.html) | `Pbus(pattern, dur: 2.0, fadeTime: 0.02, numChannels: 2, rate: 'audio')` | isolate a pattern by restricting it to a bus |
| [`Pfx`](https://doc.sccode.org/Classes/Pfx.html) | `Pfx(pattern, fxname, * pairs)` | add an effect synth to the synths of a given event stream |
| [`Pfxb`](https://doc.sccode.org/Classes/Pfxb.html) | `Pfxb(pattern, fxname, * pairs)` | add an effect synth to the synths of a given event stream |
| [`Pgroup`](https://doc.sccode.org/Classes/Pgroup.html) | `Pgroup(pattern)` | Starts a new Group and plays the pattern in this group |
| [`PparGroup`](https://doc.sccode.org/Classes/PparGroup.html) | `PparGroup(pattern)` | Starts a new ParGroup and plays the pattern in this group |
| [`Pproto`](https://doc.sccode.org/Classes/Pproto.html) | `Pproto(makeFunction, pattern, cleanupFunction)` | provide a proto event for an event stream |