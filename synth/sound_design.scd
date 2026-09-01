var server = Server.default;
var midi = MIDIInterface.new(server);
var recorder = AutoRecorder.new(server);

server.options.sampleRate = AutoRecorder.sampleRate;
server.options.memSize = 2 * (2 ** 16);

~detect_clipping = ClipDetector.new;
~detect_done = DoneSentinel; // sic, type

~export_path = thisProcess.nowExecutingPath.dirname +/+ "export";
~asset_path = thisProcess.nowExecutingPath.dirname +/+ "assets";

~recorder_start = { arg filename;
	recorder.start(~export_path +/+ filename);
};

~recorder_end = { arg signal;
	recorder.ar(signal);
};

/* ##### MAIN ##### */

server.waitForBoot({

	~bubble.();
	CmdPeriod.doOnce({ server.freeAll; })
});

/* ##### IMPLEMENTATIONS ##### */

~bubble = { arg filename, degree = 0;

	var popDef = SynthDef(\bubblePop, {
		arg out = 0, amp, degree, freq, baseStart, baseEnd, aboveStart, aboveEnd, sweepDuration = 1, attack = 0.05;

		var baseFreqStart = (freq.cpsmidi + baseStart).midicps;
		var baseFreqEnd = (freq.cpsmidi + baseEnd).midicps;
		var aboveFreqStart = (freq.cpsmidi + aboveStart).midicps;
		var aboveFreqEnd = (freq.cpsmidi + aboveEnd).midicps;

		var env = Env.perc(
			attackTime: sweepDuration * attack,
			releaseTime: sweepDuration * (1 - attack)
		);

		var amplitude = EnvGen.ar(env, doneAction: Done.freeSelf);

		var sweepBase = amplitude * SinOsc.ar(
			freq: XLine.kr(baseFreqStart, baseFreqEnd, dur: sweepDuration),
			phase: Rand(0, 2pi)
		);

		var delay = 0.1 * sweepDuration;
		var sweepAbove = amplitude * Line.ar(0, 1, delay) *
		SinOsc.ar(
			freq: XLine.kr(aboveStart, aboveEnd, dur: sweepDuration - delay),
			phase: Rand(0, 2pi)
		);

		var snapDuration = 0.032;
		var noise = EnvGen.ar(Env.perc(0.001, snapDuration)) * LPF.ar(
			WhiteNoise.ar(1.0),
			freq: XLine.ar(8000, 10, snapDuration - 0.001)
		);

		var signal = noise + sweepAbove + sweepBase;
		Out.ar(out, (amp * signal).dup);

		~recorder_end.(signal);
		~detect_done.(signal);
		~detect_clipping.(signal);
	}).add;

	Pbind(*[
		instrument: popDef.name,
		tempo: 1,
		sweepDuration: 0.25,
		degree: Pseq(degree + [0, 1, 2]),
		baseStart: 0,
        baseEnd: 12,
        aboveStart: -3,
        aboveEnd: 5,
		record: Pfunc({ |ev| ~recorder_start.("bubble_pop_%.wav".format(ev.degree)) })
	]).play;
};


Date.getDate; // console output on execution