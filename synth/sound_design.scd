var server = Server.default;
var volume = Volume.new(server);
var midi = MIDIInterface.new(server);
var prefix = thisProcess.nowExecutingPath.dirname;
var degrees = Scale.chromatic.degrees + 60;

/* ####### MAIN ####### */

volume.volume = -20; // db offset
server.waitForBoot({
	/*
	// wipe export dir
	PathName(Renderer.getExportDir()).entries.do({ |entry| File.delete(entry.fullPath); });

	// export for each degree
	degrees.do({ arg degree;
		~degree = degree;
		~bubble_pop.("bubble_pop_%.wav".format(Renderer.degreeToID(degree)));
	});
	*/

	~bounce_pad.();
});

/* ####### IMPLEMENTATIONS ####### */
~bounce_pad = { arg filename;
	var def = SynthDef(\bounce_pad, { arg out, degree, comb_coefficient, ks_coef = 0.5, ks_mix = 0.5;
		/*
		var comb_sig, signal;
		comb_sig = CombLP.ar(
			excitation,
			delaytime: 1 / degree,
			decaytime: 2.0,
			coef: 1 - Line.ar(1, 0.2, 1.0)
		);
	*/

		var sentinel = EnvGen.ar(Env.cutoff(1), doneAction: Done.freeSelf);
		var env = EnvGen.ar(Env.perc(0.01, 0.02));
		var excitation = Impulse.ar(degree) * env;

		var settle, ring, freq;
		var ringDecay = 2;
		var ringFreq = 40;
		var baseFreq = 20;
		var overshoot = 1.0;

		settle = EnvGen.ar(
			Env.new(
				levels: [baseFreq * overshoot, baseFreq],
				times: [ringDecay * 2],
				curve: \exp
			),
			gate: excitation
		);

		freq = settle;
		freq.max(20); // safety floor, avoid negative/sub-audio freq

		// blend the two excitation/resonance models

		Out.ar(out, freq.dup);
	}).add;

	var step = 0.01;
	var pattern = Pbind(*[
		instrument: \bounce_pad,
		degree: Pseq((Scale.chromatic.degrees + 60).midicps, 1)
	]);
	pattern.play;
};

// overworld.bubble.pop
~bubble_pop = { arg filename;
	 var def = SynthDef(\bubble_pop, { arg out = 0, base_start, base_end, above_start, above_end, sweep_duration;
		var attack = 0.05;
		var env = Env.perc(
            attackTime: sweep_duration * attack,
            releaseTime: sweep_duration * (1 - attack)
        );
        var amplitude = EnvGen.ar(env, doneAction: Done.freeSelf);

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
		degree: Pseq([~degree], 1),
        base_start:  Pfunc { |ev| (ev[\degree] +  0).midicps }, // convert midi key to hertz
        base_end:    Pfunc { |ev| (ev[\degree] + 12).midicps },
        above_start: Pfunc { |ev| (ev[\degree] -  3).midicps },
        above_end:   Pfunc { |ev| (ev[\degree] +  5).midicps },
        sweep_duration: sweep_duration,
	]);

	Renderer.render(
		def,
		pattern,
		filename,
		duration: Renderer.measureDuration(pattern) + sweep_duration
	);
};