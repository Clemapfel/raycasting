var server = Server.default;

// degree
var dg = { |x| Degree.new(x).midi };

var b1 = 4 / 1;   // 1 measure
var b2 = 4 / 2;   // 1 / 2 measure
var b4 = 4 / 4;   // 1 beat
var b8 = 4 / 8;   // 1 / 8th
var b16 = 4 / 16; // 1 / 16th
var b32 = 4 / 32; // 1 / 32th
var b64 = 4 / 64;

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

var r1 = Rest(b1);
var r2 = Rest(b2);
var r4 = Rest(b4);
var r8 = Rest(b8);
var r16 = Rest(b16);
var r32 = Rest(b32);

var r1d = Rest(b1d);
var r2d = Rest(b2d);
var r4d = Rest(b4d);
var r8d = Rest(b8d);
var r16d = Rest(b16d);
var r32d = Rest(b32d);

var tempo = 120 / 60; // 120 bpm
var freqs = { |t| t.collect { |x| Degree.new(x.asString).midi }.midicps };
var transpose = { |freq, offset = 12| (freq.cpsmidi + offset).midicps };
var amp = 1.0;

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

	var bass = SynthDef.new(\bass, { arg out, gate = 1, freq, dur;
		var env = EnvGen.ar(Env.asr(attackTime: 0.05, releaseTime: b1 * dur), gate: gate, doneAction: Done.freeSelf);
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
		Out.ar(out, amp * env * Mix.ar(amps * oscs).dup);
	}).add;

	var kick = SynthDef.new(\kick, { arg out, amp, gate = 1, freq = 30, dur = 0.5, filter = 0;
		var sig;
		var kick_env = EnvGen.ar(
			Env.perc(attackTime: 0.001, releaseTime: 0.9),
			gate: gate
		);

		var pitch = EnvGen.ar(Env.new(1 + [1, 0], b32 * dur, \exp), gate: gate);
		var exciter = PinkNoise.ar() * EnvGen.ar(Env.perc(0.001, 0.002));
		var kick = Ringz.ar(exciter, (freq * pitch).max(20), b64 * dur);

		var base_env = Line.ar(2, 1, b4 * dur) - 1;
		var base = SinOsc.ar(freq * pitch * Line.kr(2, 0.5, b16d * dur));
		kick = kick + Limiter.ar(0.5 * Ringz.ar(kick, freq: freq, decaytime: 2));

		sig = Limiter.ar((kick * kick_env) + (base * base_env));
		sig = XFade2.ar(sig, RHPF.ar(sig, 200), filter.linlin(0, 1, -1, 1));

		Out.ar(out, amp * sig.dup);
		ClipDetector.ar(sig);
		DetectSilence.ar(sig, doneAction: Done.freeSelf);
	}).add;

	var clap = SynthDef.new(\clap, { arg out, amp, gate = 1, dur = 0.5, filter = 0;

	}).add;

	var shaker = SynthDef.new(\shaker, { arg out = 0, amp, gate = 1, dur, which = 0;
		var noise = WhiteNoise.ar();

		var amp_env = EnvGen.ar(Env.perc(0.02, b32 * dur));

		var m_min = -1, m_max = 1;
		var forward_env = EnvGen.kr(
			Env(1 + [m_min, m_max, 0].midiratio, [0.02, 0.04], \exp)
		) - 1;

		var backward_env = EnvGen.kr(
			Env(1 + [m_max, m_min, 0].midiratio, [0.02, 0.03], \exp)
		) - 1;

		var pitch = Select.kr(which, [ forward_env, backward_env ]);

		var sig = ClipNoise.ar.range(0.0, 1.0) * BPF.ar(noise,
			pitch.linlin(-1.midiratio, 1.midiratio, 1800, 3000),
			rq: 1
		) * amp_env;

		Out.ar(out, amp * sig.dup);
		DetectSilence.ar(sig, doneAction: Done.freeSelf);
	}).add;

	var lead = SynthDef.new(\lead, { arg out = 0, freq = 440, gate = 1, amp;
		var amp_env = EnvGen.ar(Env.asr(0.02, 1.0, 1.0), gate: gate, doneAction: Done.freeSelf);
		var osc = SinOsc.ar(Lag.ar(freq));

		Out.ar(out, amp * (osc * amp_env).dup);
	}, [nil, \ar]).add;


	var metronome_pattern = Pbind(*[
		instrument: metronome,
		degree: Pseq([4, 0, 0, 0], inf)
	]);

	var bass_pattern = Pbind(*[
		instrument: bass,
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

	var kick_pattern = Pbind(*[
		instrument: kick,
		freq: 40,
		dur: Pseq([b4, r4, b4, r4], inf),
		filter: Pseq([0, 0, 0, 0], inf)
	]);

	var shaker_pattern = Pbind(*[
		instrument: shaker,
		dur: Pseq([b4, b4, b4, b4], inf),
		which: Pseq([0, 1, 0, 1], inf)
	]);

	var clap_pattern = Pbind(*[
		instrument: clap,
		dur: Pseq([b4, b4, b4, b4], inf)
	]);

	// https://onlinesequencer.net/3645233


	var lead_in = [
		"D#5", b8
		,"D#6", b4
		,"", r4
		,"C#6", b4
		,"D#6", b4
		,"", r4
		,"C#6", b4
		,"D#5", b4
		,"", r16
		,"D#5", b8
		,"D#6", b4


		,"C#6 ", b4
		,"D#6", b4
		,"", r4

		,"C#6", b4
		, "", r8
		,"D#6", b8
		,"D#6", b8
		,"D#6", b8

	];

	var lead_notes = lead_in.clump(2).flop;
	var lead_pattern = Pnew(lead.name, *[
		freq: Pseq(lead_notes[0].collect({ |x| Degree.new(x).freq }), 1),
	    dur: Pseq(lead_notes[1], inf)
	]);

	//bass_pattern.play;
	//kick_pattern.play;
	//shaker_pattern.play;
	//clap_pattern.play;
	lead_pattern.play;

	CmdPeriod.doOnce { server.freeAll }
}
