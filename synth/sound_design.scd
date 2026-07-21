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

	CmdPeriod.doOnce({
		s.freeAll;
	})
});

/* ####### IMPLEMENTATIONS ####### */

~bounce_pad = { arg filename;
  var def = SynthDef(\bounce_pad, { arg out = 0, degree = 60, dur = 1.0;
        var signal;

        var decayDuration = dur;
        var delayDuration = dur / 4;

        var ratios = [
            1.0,
            2.sqrt,
            3.sqrt,
            5.sqrt,
            7.sqrt,
            9.sqrt
        ];

        var wobbleFreqWobble = SinOsc.kr(
            EnvGen.kr(Env(
                [0, 5, 12],
                [delayDuration, decayDuration - delayDuration],
                [\lin, \exp]
            ))
        );

        var wobbleFreq = ((degree - 12).midicps) * wobbleFreqWobble.linlin(-1, 1, 0.5, 1);
        var wobbleExcitation = DelayN.ar(Decay2.ar(Impulse.ar(0),
			attackTime: 0.1, decayTime: decayDuration
		), maxdelaytime: delayDuration, delaytime: delayDuration);

        var wobble = DynKlank.ar(`[
            ratios,
            ratios.collect({ |r| 1 / r; }),
            ratios.collect({ |r| decayDuration / (r ** 0.8); })
        ], wobbleExcitation, freqscale: wobbleFreq);

        var ring = Ringz.ar(
            EnvGen.ar(Env.perc(0.001)),
			freq: (degree - 4).midicps,
            decaytime: 0.6
        );

        signal = ring + wobble;
        Out.ar(out, signal.dup);
        DetectSilence.ar(signal, 0.001, doneAction: Done.freeSelf);
    }).add;

    var pattern = Pbind(*[
        instrument: \bounce_pad,
        degree: Pn(Pseq([Pshuf(Scale.major.degrees + 60, 1), Rest(1)], 1), 3),
        dur: 1.25,
        amp: 1.0,
		tempo: 2
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