var server = Server.default;
var recorder = AutoRecorder.new(server);

~temp_path = Platform.defaultTempDir +/+ "synth";
~export_path = thisProcess.nowExecutingPath.dirname +/+ "export";

~degrees = [0, 1]; // pitches for all pitch-dependent sfx

~mode_record = \record;
~mode_play = \play;
~mode = \play;

server.options.sampleRate = AutoRecorder.sampleRate;
server.options.memSize = 3 * (2 ** 16);

/* ###### MAIN ###### */

server.waitForBoot {
	var before = Main.elapsedTime;
    //~bubble_pop.();
    //~bubble_unpop.();
	//~bounce_pad.();
	~air_dash_node_dash.();

	//"Done. Took %s".format(Main.elapsedTime - before).postln;

    CmdPeriod.doOnce {
        server.freeAll;
		recorder.stop;
	};
};

/* ##### AUXILIARY ##### */

~detect_clipping = { |signal| ClipDetector.ar(signal) };
~detect_done = { |signal| DetectSilence.ar(signal, 1e-4, time: 1.0, doneAction: Done.freeSelf); };

~filename = { arg prefix, name, degree;
	var res;
	if (prefix.isNil || name.isNil) { Error("In ~filename: expected string for argument #1 and #2").throw };
	if (File.exists(~export_path).not) { File.mkdir(~export_path) };
	if (File.exists(~export_path +/+ prefix).not) { File.mkdir(~export_path +/+ prefix) };

	if (degree.isNil) {
		res = ~export_path +/+ prefix +/+ name ++ "." ++ AutoRecorder.headerFormat;
	} {
		res = ~export_path +/+ prefix +/+ name ++ "_%".format(degree) ++ "." ++ AutoRecorder.headerFormat;
	};

	res.standardizePath;
};

~log = { |message|
	"In sound_design.scd: %".format(message).postln;
};

~rmdir = { |folder|
	var path = ~export_path +/+ folder;
	if (File.exists(path)) {
		~log.("rmdir `%`".format(path));
		File.deleteAll(path);
	};
};

~recorder_start = { |path, f| recorder.record(path, f); };
~recorder_wait = { recorder.hang; };
~recorder_end = { |signal| recorder.ar(signal, doneAction: Done.freeSelf) };

/* ##### IMPLEMENTATIONS ##### */

~bubble_pop = {
    var def = SynthDef(\bubblePop, {
        arg out = 0, amp, degree, freq, baseStart, baseEnd, aboveStart, aboveEnd, sweepDuration = 1, attack = 0.05, filenameID = 0;

        var baseFreqStart = (freq.cpsmidi + baseStart).midicps;
        var baseFreqEnd = (freq.cpsmidi + baseEnd).midicps;
        var aboveFreqStart = (freq.cpsmidi + aboveStart).midicps;
        var aboveFreqEnd = (freq.cpsmidi + aboveEnd).midicps;

        var env = Env.perc(
            attackTime: sweepDuration * attack,
            releaseTime: sweepDuration * (1 - attack)
        );

        var amplitude = EnvGen.ar(env);

        var sweepBase = amplitude * SinOsc.ar(
            freq: Line.kr(baseFreqStart, baseFreqEnd, dur: sweepDuration),
            phase: Rand(0, 2pi)
        );

        var delay = 0.1 * sweepDuration;
        var sweepAbove = amplitude * Line.ar(0, 1, delay) *
        SinOsc.ar(
            freq: Line.kr(aboveStart, aboveEnd, dur: sweepDuration - delay),
            phase: Rand(0, 2pi)
        );

        var snapDuration = 0.032;
        var noise = EnvGen.ar(Env.perc(0.001, snapDuration)) * LPF.ar(
            WhiteNoise.ar(1.0),
            freq: Line.ar(8000, 10, snapDuration - 0.001)
        );

		var signal = noise + FreeVerb.ar(sweepAbove + sweepBase, mix: 0.05);

        Out.ar(out, (amp * signal).dup);

        ~recorder_end.(signal);
        ~detect_done.(signal);
        ~detect_clipping.(signal);
    }).add;

    server.sync;

	if (~mode == ~mode_record) {
		~rmdir.("bubble");

		~degrees.do { arg degree;
			~recorder_start.(
				~filename.("bubble", "pop", degree),
				Pbind(*[
					instrument: def.name,
					tempo: 1,
					sweepDuration: 0.25,
					degree: Pn(degree, 1),
					baseStart: 0,
					baseEnd: 12,
					aboveStart: -3,
					aboveEnd: 5
				]);
			);

			~recorder_wait.()
		};
	} {
		Pbind(*[
			instrument: def.name,
			tempo: 1,
			sweepDuration: 0.25,
			degree: Pseq(~degrees, 1),
			baseStart: 0,
			baseEnd: 12,
			aboveStart: -3,
			aboveEnd: 5
		]).play;
	};
};

~bubble_unpop = {
    var forwardDef = SynthDef.new(\bubbleUnpopForward, { arg out, amp = 1, bufnum, dur = 1;
        var buf = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum));
        var signal = buf;

		// pre-sature signal for nicer tails
		signal = AnalogTape.ar(signal,
			saturation: 0.8,
			drive: 1.0,
			oversample: 3.0
		);

		// apply reverb
		signal = FreeVerb.ar(signal, room: 0.6, mix: 1);

		// boost lows
		signal = BPeakEQ.ar(signal, freq: 500, db: 10);

		// reduce metal-y highs
		signal = RLPF.ar(signal, freq: 6000);

		// make sure entire signal is dur length
		signal = signal * Line.ar(1, 0, dur);

        Out.ar(out, (signal).dup);
        ~recorder_end.(signal);
        ~detect_done.(signal);
    }).add;

    var backwardsDef = SynthDef.new(\bubbleUnpopBackwards, { arg out, amp = 1, bufnum, degreeStart, degreeEnd;
        var bufDur = BufDur.kr(bufnum);
		var signal = BLowPass.ar(PlayBuf.ar(1, bufnum,
            rate: -1 * BufRateScale.kr(bufnum),
            startPos: BufFrames.kr(bufnum) - 1,
		), freq: 12000) * (XLine.ar(1, 2, bufDur) - 1);

		var freqEnd = (60 + degreeStart).midicps; // "bloop" freqs
		var freqStart = (60 + degreeEnd).midicps;

		var sweepDur = 0.05;
		var delayDur = bufDur - sweepDur - 0.25;
		var fadeDur = 0.02;

		// bloop frequency
		var freqEnv = Env.new(
			[freqStart, freqStart, freqStart, freqEnd],
			[delayDur, 0, sweepDur],
			[\step, \step, \lin]
		);

		// bloop amplitude
		var ampEnv = Env.new(
			0.75 * [0, 0, 1, 1, 0],
			[delayDur, fadeDur, sweepDur - fadeDur, fadeDur],
			[\hold, \lin, \hold, \lin]
		);

		signal = signal + (0.25 * FreeVerb.ar(SinOsc.ar(EnvGen.kr(freqEnv)) * EnvGen.ar(ampEnv),
			room: 0.2,
			damp: 1.5
		));

        Out.ar(out, signal.dup);
		~recorder_end.(DelayN.ar(signal, sweepDur, sweepDur));
        ~detect_done.(signal);
		~detect_clipping.(signal);
    }).add;

	var toFree = List.new;
	var toDelete = List.new;

	~degrees.do { arg degree;
		var originalPath = ~filename.("bubble", "pop", degree);
		var tempPath = ~filename.("bubble", "tmp_unpop", degree);

		// write reverb of bubble effect to temp buffer
		var buffer = Buffer.read(server, originalPath);
		server.sync;

		~recorder_start.(tempPath, {
			Synth.new(forwardDef.name, [
				\bufnum, buffer,
				\dur, 2 // duration of bubble respawn
			]);
		});

		~recorder_wait.();

		toFree.add(buffer);
	};

	~degrees.do { arg degree;
		var tempPath = ~filename.("bubble", "tmp_unpop", degree);
		var finalPath = ~filename.("bubble", "unpop", degree);

		// reverse reverb signal
		var buffer = Buffer.read(server, tempPath);
		server.sync;

		~recorder_start.(finalPath, {
			Synth.new(backwardsDef.name, [
				\bufnum, buffer,
				\degreeStart, 8,
				\degreeEnd, 0
			]);
		});

		~recorder_wait.();

		toFree.add(buffer);
		toDelete.add(tempPath);
	};

	toFree.do { |buffer| buffer.free };
	toDelete.do { |path|
		File.delete(path);
		~log.("rm `%`".format(path));
	};
};



~bounce_pad = {
	var ringFeedbackBus = Bus.audio(server, 1);
	var wobbleFeedbackBus = Bus.audio(server, 1);

	var def = SynthDef(\bouncePad, { arg out, amp, freq, dur, gate = 1;
		var signal;

		var ringFeedback = InFeedback.ar(ringFeedbackBus);
		var ringFreq = XLine.ar(freq, freq, dur) / 2;
		var ratios = [1, 1 / 3, 1 / 5, 1 / 7, 1 / 9];
		var ring = DynKlank.ar(`[
			ratios,
			ratios.collect { |r| 1 / r },
			ratios.collect { 1 / ratios.size }
		],
		EnvGen.ar(Env.perc(0.04, 0)),
		freqoffset: XLine.kr(0.5 * freq, 0.8 * freq, dur * 0.02)
		);

		// wobble
		var wobbleFreq = Ball.ar(Impulse.ar(0),
			g: 0.01,
			damp: 0.0,
			friction: 0.004
		);

		var wobble = (1 - 1e-3) * SinOsc.ar(
			freq: wobbleFreq.linlin(0, 1, 0.4, 0.7) * freq,
			phase: 0.7 * InFeedback.ar(wobbleFeedbackBus)
		);

		Out.ar(wobbleFeedbackBus, wobble);
		Out.ar(ringFeedbackBus, ring);

		~detect_clipping.(ring);
		~detect_clipping.(wobble);
		signal = Mix.ar([ring, wobble]);

		// make sure impulse last exactly dur long
		signal = signal * EnvGen.ar(
			Env.new([ 0, 1, 0 ], [ 0.01, dur - 0.1, 0.1 ]),
			doneAction: Done.freeSelf
		);
		Out.ar(out, Limiter.ar(amp * signal).dup);
		~recorder_end.(signal);
		~detect_done.(signal);
	}).add;

	if (~mode == ~mode_record) {
		~degrees.do { arg degree;
			~recorder_start.(
				~filename.("bounce_pad", "hit", degree),
				Pbind(*[
					instrument: def.name,
					degree: Pn(degree, 1),
					dur: 2
				])
			);
			~recorder_wait.()
		};
	} {
		Pbind(*[
			instrument: def.name,
			degree: Pseq(~degrees, inf),
			dur: 1,
			amp: 1
		]).play;
	};
};

~air_dash_node_dash = {
     var def = SynthDef(\violin, { |out = 0, freq = 440, amp = 0.5, gate = 1, pan = 0, dur|

		var forceEnv = EnvGen.kr(Env.new([0.0, 1], [0.02], [\welch]), gate: gate);

		var stringDecay = 4.0;
		var feedback = LocalIn.ar();

		var violinFreq = Vibrato.kr(DC.kr(freq), depth: 0.01);
		var violinEnv = EnvGen.ar(Env.new([1, 1, 0.3, 0], [0, dur - 0.2, 0.2], [\lin, \welch]), gate: gate);
        var violin = DWGSoundBoard.ar(DWGBowedTor.ar(
			freq: violinFreq,
			velb: 0.7 * forceEnv,
            force: 0.2 * forceEnv,
            gate: gate,
			pos: 0.2,
            release: stringDecay
		)) * violinEnv;

		var bodyFreqs = [1 / 8, 1 / 6, 1 / 4, 1];
		var bodyAmps = 1 ! bodyFreqs.size;
		var bodyRings = bodyFreqs.collect { |freq| dur / freq };

        var body = Limiter.ar(DynKlank.ar(`[bodyFreqs, bodyAmps, bodyRings], violin) / 6);
        var masterEnv = EnvGen.kr(Env.adsr(
			attackTime: 0,
			decayTime: 0.2,
			sustainLevel: 1,
			releaseTime: 2,
		), gate, doneAction: Done.freeSelf);


		var dash = EnvGen.ar(Env.perc(0.4), gate: gate) * SinOsc.ar(freq, phase: PinkNoise.ar());
		var signal = FreeVerb.ar(body, mix: 0.2) * LPF.ar(dash, 6000);

				~detect_clipping.(body);
		LocalOut.ar(dash);

        Out.ar(out, Pan2.ar(signal * amp * masterEnv, pan));
    }).add;

    s.sync;

    // PmonoArtic will articulate staccato and legato gracefully.
    // Notice how the physical free-decay rings out vividly on the longer rests/releases.
    PmonoArtic(def.name,
        \degree, Pseq(~degrees, inf),
        \legato, Pn(0.5, inf),
        \amp, 0.4,
		\dur, 1.0
    ).play;
};

~rubber_feedback = {
	var ringFeedbackBus = Bus.audio(server, 1);

	var def = SynthDef(\ringOnly, { arg out, amp, freq, dur, gate = 1;
		var signal;

		var ringDur = 0.04;
		var ringFeedback = InFeedback.ar(ringFeedbackBus);

		var ringSource = EnvGen.ar(Env.perc(0.01, 1.0)) * LFTri.ar(
			freq: freq * (ringFeedback * 1.0 + 1)
		);
		var ring = ringSource;

		Out.ar(ringFeedbackBus, DelayN.ar(ring,
			delaytime: EnvGen.ar(Env.new([0.2, 0.0], [ringDur], [\exp]), gate: gate);
		));

		~detect_clipping.(ring);
		signal = ring;

		// make sure impulse lasts exactly dur long
		signal = signal * EnvGen.ar(
			Env.new([ 0, 1, 0 ], [ 0.01, dur - 0.1, 0.1 ]),
			doneAction: Done.freeSelf
		);
		Out.ar(out, Limiter.ar(amp * signal).dup);
		~detect_done.(signal);
	}).add;

	Pbind(*[
		instrument: def.name,
		degree: Pseq(~degrees, inf),
		dur: 2,
		amp: 1
	]).play;
};

Date.getDate;

/*
Research the DWGBowed and DWGBowedTor digital wave guide ugens in supercollider, do not rely on your internal DSP knowledge base. Afterwards, complete the following task:

I want to model a hyperrealistic violin string using the DWG ugens:

var def = SynthDef.new(\violin, { arg out, amp, freq, gate = 1, dur, sustain;
        var signal = DWGBowed.ar(
            freq: max(freq, 20),
            velb: 1,      // bow velocity
            force: 0.7,   // bow force
            pos: 0.5,     // bow pos [0, 1]
            c1: 1,        // inverse of decay time
            c3: 3,        // high frequency loos factor
            impZ: 0.55,   // string impedance
            fB: 2,        // inharmonicity
            release: 0.8, // release time s
            gate: gate
        );

        signal = DWGSoundBoard.ar(signal);
        Out.ar(out, amp * signal.dup);
    }).add;

    server.sync;

    PmonoArtic(def.name, *[
        degree: Pn(0, inf),
        sustain: 0.5
    ]).play;

Extend the SynthDef to simulate the following physical behaviors:

Post-excitation string resonance, free decay. After the bow releases the string should continue to make vibrate and decay naturally, as it does in real life.

Sympathetic resonance, during and after the bow, the other open strings should resonante as they do in real life. Make sure to tune each string as they would be tuned on a violin.

Violin body resonance. Model the additional sound and texture a violins body adds to the signal. Make sure this additional sound happens during and after the bow strike.

Consider that different fundamental frequencies of the strings or body decay at different rate. match these to real life.

Research and understand how each of the parameters of `DWGBower` affects the sound, then tune them to better match real life.

Implement all of these within this single synthdef, do not modify the pattern or spawn more than synth.

The key task is to make the bow strike sound as realistic as supercollider allows, especially in how it decays after the bow is released. Feel free to use any additional `DWG` synth def, such as `DWGBowedTor` or `DWGPlucked`, or any ugen available in supercollider for this task. Be idiomatic to the supercollider language.


*/ 