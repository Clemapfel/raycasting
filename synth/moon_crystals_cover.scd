var server = Server.default;

// degree
var dg = { |x| Degree.new(x).midi };

var b1 = 4 / 1;   // 1 measure
var b2 = 4 / 2;   // 1 / 2 measure
var b4 = 4 / 4;   // 1 beat
var b8 = 4 / 8;   // 1 / 8th
var b16 = 4 / 16; // 1 / 16th
var b32 = 4 / 32; // 1 / 32th

// dotted
var b1d = b1 * 1.5;
var b2d = b2 * 1.5;
var b4d = b4 * 1.5;
var b8d = b8 * 1.5;
var b16d = b16 * 1.5;
var b32d = b32 * 1.5;

// triplets
var b2t = 4 / 3;
var b14t = 4 / 6;
var b18t = 4 / 12;
var b16t = 4 / 24;
var b32t = 4 / 48;

var tempo = 120 / 60; // 120 bpm
var freqs = { |t| t.collect { |x| Degree.new(x.asString).midi }.midicps };
var transpose = { |freq, offset = 12| (freq.cpsmidi + offset).midicps };


server.latency = 0.3;
server.options.blockSize = 2048;
server.options.numWireBufs = 256;
server.options.sampleRate = ~sample_rate;
server.options.memSize = 2 * (2 ** 16);
TempoClock.default.tempo = tempo;

server.waitForBoot {
	var metronome = SynthDef.new(\metronome, { |out, amp, freq|
		var click = SinOsc.ar(freq) * EnvGen.ar(Env.perc(releaseTime: 0.25), doneAction: Done.freeSelf);
		Out.ar(out, (amp * click).dup);
	}).add;

	var base = SynthDef.new(\base, { arg out, amp, gate = 1, freq;
		var env = EnvGen.ar(Env.asr(attackTime: 0.05, releaseTime: b1 / tempo), gate: gate, doneAction: Done.freeSelf);
		var freqs = [
			transpose.(freq, -12),
			freq,
			transpose.(freq, 12),
			transpose.(freq, 24)
		];

		var amps = [ 8, 4, 2, 1 ].normalizeSum;

		var fbWeight = [1, 0.5, 0.25, 0] * EnvGen.ar(Env.new([0, 1], 0.05, \welch));
		var sins = SinOscFB.ar(freqs,
			feedback: 0.6 * fbWeight, gate: gate
		);

		var feedback = LocalIn.ar(freqs.size);
		var saws = [2, 1, 0, 0] * VarSaw.ar(freqs, iphase: fbWeight * feedback.range(0, 2));

		var oscs = Mix.ar([32, 7].normalizeSum * [sins, saws]);

		LocalOut.ar(saws);
		Out.ar(out, env * Mix.ar(amps * oscs).dup);

		ClipDetector.ar(oscs, 0.0);
	}).add;

	var tempo = 120;

	var base_pattern = Pbind(*[
		instrument: base,
		freq: Pseq(freqs.([
			"A2",
			"E2",
			"F2"
		]), inf),

		dur: Pseq([
			b1,
			2 * b1,
			b1
		], inf),

		legato: 1
	]);


	Pbind(*[
		instrument: metronome,
		degree: Pseq([4, 0, 0, 0], inf)
	]).play;

	base_pattern.play;

	CmdPeriod.doOnce { server.freeAll }
}
