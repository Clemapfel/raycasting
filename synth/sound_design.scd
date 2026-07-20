var server = Server.default;
var volume = Volume.new(server);
var midi = MIDIInterface.new(server);
var prefix = thisProcess.nowExecutingPath.dirname;
var degrees = Scale.chromatic.degrees + 60;

/* ####### MAIN ####### */

volume.volume = 0; // db offset
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
    var def = SynthDef(\bounce_pad, { arg out = 0, degree = 261.62, amp = 0.5;
        var pitchSweep, pitchWobble, body, slapEnv, slap, signal;

		var besselRatios = [ // bessel frequency ratios
			// n = 0
			[1.0000, 2.2954, 3.5985, 4.9044, 6.2117, 7.5196],
			// n = 1
			[1.5933, 2.9173, 4.2298, 5.5406, 6.8482, 8.1571],
			// n = 2
			[2.1357, 3.4998, 4.8317, 6.1524, 7.4677, 8.7801],
			// n = 3
			[2.6531, 4.0592, 5.4127, 6.7460, 8.0688, 9.3903],
			// n = 4
			[3.1554, 4.6008, 5.9762, 7.3253, 8.6603, 9.9878],
			// n = 5
			[3.6474, 5.1310, 6.5297, 7.8926, 9.2395, 10.5747]
		];

		var decayBase = 1.4;
		var ratios = [
			1.0
			/*
			besselRatios[0][0],
			besselRatios[0][1],
			//besselRatios[0][2],
			//besselRatios[0][3],
			//besselRatios[0][4],

			besselRatios[1][0],
		    besselRatios[1][1],
			//besselRatios[1][2],
		    //besselRatios[1][3],
			//besselRatios[1][4],

			besselRatios[2][0],
			besselRatios[2][1],
			//besselRatios[2][2],
			//besselRatios[2][3],
			//besselRatios[2][4],

			besselRatios[3][0],
			besselRatios[3][1],
			//besselRatios[3][2],
		    //besselRatios[3][3],
			//besselRatios[3][4],

			//besselRatios[4][0],
			//besselRatios[4][1],
			//besselRatios[4][2],
			//besselRatios[4][3],
			//besselRatios[4][4],
			*/
		];

		var duration = 0.7;

		var amplitudes = ratios.collect({ |r| 1 / r; });
		var decayduration = 0.7 * duration;
		var decaytimes = ratios.collect({ |r| decayduration / (r ** 0.25); }); // decay duration

		var freq = (degree - 18).midicps;

        var excitation = LPF.ar(PinkNoise.ar, 4000) * EnvGen.ar(Env.perc(0.001, 0.005));

		var pitchAttack = 0.05;
		var pitchRelease = 0.2;

		var wobble_duration = 0.8 * duration;
		var bloop_duration = 0.3 * duration;
		var wobble_freq, bloop_freq;
		var wobble, bloop;

		// pitch wobble
		pitchWobble = SinOsc.kr(freq: 8 * (1 - XLine.kr(1, 0.05, pitchRelease)));

		// pitch sweep: high -> low
        pitchSweep = EnvGen.ar(Env([2, 1.0, 0.97], [pitchAttack, pitchRelease], \exp)) + pitchWobble;

        body = Klank.ar(`[ // Ref
            ratios,
            amplitudes,
            decaytimes
        ], excitation, freqscale: freq * (1 + pitchWobble));

		// wobble
		wobble_freq = (degree - 12).midicps;
		wobble = SinOsc.ar(wobble_freq * (1 - pitchSweep)) * EnvGen.ar(
			Env.perc(releaseTime: wobble_duration)
		);

		// percussive bloop
	    bloop_freq = (degree - 24).midicps;
	    bloop = HPF.ar(Ringz.ar(
			EnvGen.ar(Env.perc(attackTime: 0.02, releaseTime: bloop_duration)),
			freq: bloop_freq * EnvGen.ar(Env.new([1, 0], [bloop_duration], curve: \welch)),
			decaytime: bloop_duration
		), freq: 200);

		signal = body + (0.8 * wobble) + (0.25 * bloop);
		signal = signal * amp;
		signal.clip(20);

        DetectSilence.ar(signal, 0.001, doneAction: Done.freeSelf);

        Out.ar(out, signal.dup);
    }).add;

    var pattern = Pbind(*[
        instrument: \bounce_pad,
        degree: Pn(Pseq([Pshuf(Scale.major.degrees + 60, 1), Rest(1)], 1), 3),
        dur: 1.25,
        amp: 1.0,
		tempo: 3
    ]);

    pattern.play;
};

// overworld.bubble.pop
~bubble_pop = { arg filename;
	 var def = SynthDef(\bubble_pop, { arg out = 0, amp = 1, base_start, base_end, above_start, above_end, sweep_duration;
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
        Out.ar(out, (amp * signal).dup);
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

true;