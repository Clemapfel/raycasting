var server = Server.default;
var volume = Volume.new(server);
var midi = MIDIInterface.new(server);
var prefix = thisProcess.nowExecutingPath.dirname;
volume.volume = -40; // db offset

/* ####### IMPLEMENTATIONS ####### */


server.waitForBoot({
	~bubble_pop.();
});

/* ####### IMPLEMENTATIONS ####### */

// overworld.bubble.pop
~bubble_pop = {
	 var def = SynthDef(\bubble_pop, { arg out = 0, base_start, base_end, above_start, above_end, sweep_duration;
		var attack = 0.05;
		var env = Env.perc(
            attackTime: sweep_duration * attack,
            releaseTime: sweep_duration * (1 - attack)
        );
        var amplitude = EnvGen.ar(env, doneAction: 2);

        var sweep_base = amplitude * SinOsc.ar(
            freq: XLine.kr(base_start, base_end, dur: sweep_duration),
            phase: Rand(0, 2pi)
        );

		var delay = 0.1 * sweep_duration;
		var sweep_above = amplitude * Line.ar(0, 1, delay) *
            SinOsc.ar(
                freq: XLine.kr(above_start, above_end, dur: sweep_duration - delay),
                phase: Rand(0, 2pi)
            );

		var snap_duration = 0.032;
		var noise = EnvGen.ar(Env.perc(0.001, snap_duration)) * LPF.ar(
            WhiteNoise.ar(1.0),
			freq: XLine.ar(8000, 10, snap_duration - 0.001)
        );

        var signal = noise + sweep_above + sweep_base;
        Out.ar(out, signal.dup);
    }).add;

	var sweep_duration = 0.1;
    var scale = Scale.chromatic;
    var pattern = Pbind(*[
        instrument: \bubble_pop,
		tempo: 3,
        key: Pseq(scale.degrees + 60),
        base_start:  Pfunc { |ev| (ev[\key] +  0).midicps }, // convert midi key to hertz
        base_end:    Pfunc { |ev| (ev[\key] + 12).midicps },
        above_start: Pfunc { |ev| (ev[\key] -  3).midicps },
        above_end:   Pfunc { |ev| (ev[\key] +  5).midicps },
        sweep_duration: sweep_duration
	]);

    Renderer.render(
        def,
        pattern,
        "bubble_pop.wav",
		duration: Renderer.measureDuration(pattern) + sweep_duration
	);
}