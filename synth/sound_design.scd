var server = Server.default;
var volume = Volume.new(server);

~transpose = { arg freq, n;
    (freq.cpsmidi + n).midicps;
};

volume.volume = -15; // db offset

server.waitForBoot({
	var bubble_def = SynthDef(\bubble, { arg out = 0, base_freq = 400, end_freq = 800, sweep_duration = 0.04, amp = 1.0;

		var snap_env = EnvGen.ar(Env.perc(0.005, 0.015));
		var snap = snap_env * BPF.ar(WhiteNoise.ar(1), end_freq);

		var body_env = EnvGen.ar(Env.perc(0.001, sweep_duration));
		var pitch = XLine.kr(base_freq, end_freq, sweep_duration);
		var pitch_above = XLine.kr(1.2 * base_freq, 0.9 * end_freq, 0.8 * sweep_duration);
		var body = SinOsc.ar(pitch, phase: Rand(0, 2 * pi));
		var above = DelayN.ar(SinOsc.ar(pitch_above, phase: Rand(0, 2 * pi)), delaytime: 0.02);

		var signal = snap + body_env * (body + above);
		var sentinel = EnvGen.ar(Env.cutoff(sweep_duration), doneAction: Done.freeSelf);

		Out.ar(out, signal.dup);
	}).add;

	var clock = TempoClock.new(tempo: 2.5);
	var offset = 5; // semitones of variance
	var freq_start = 250;
	var freq_end = 500;

	// Calculate the exact boundaries using your transpose function
	var min_start = ~transpose.(freq_start, offset * -1);
	var max_start = ~transpose.(freq_start, offset);
	var min_end = ~transpose.(freq_end, offset * -1);
	var max_end = ~transpose.(freq_end, offset);

	var scale = Scale.minor;
	var root = 60; // MIDI root note (C4), adjust as needed
	var degrees = scale.degrees;

	var pattern = Pbind(
		\instrument, \bubble,
		\degree, Pshuf(degrees, inf),
		\root, root,
		\base_freq, Pfunc({ arg env;
			(root + env[\degree]).midicps
		}),

		\end_freq, Pfunc({ arg env;
			(root + env[\degree] - 8).midicps
		}),

		\sweep_duration, 0.5 * clock.beatDur
	);


	server.sync;
	pattern.play(clock);
});