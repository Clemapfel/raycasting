var server = Server.default;

[0.5 ! 4]!?_.add([1, 2])!?_.flop!?_.add([2, 2].reciprocal)!?_.flatten!?_.sum!?_.postln;

~recorder = AutoRecorder.new(server);

~sample_rate = AutoRecorder.sampleRate;
~sample_format = AutoRecorder.sampleFormat;
~nyquist = ~sample_rate / 2;
~temp_path = Platform.defaultTempDir +/+ "synth";
~export_path = thisProcess.nowExecutingPath.dirname +/+ "export";
~asset_path = thisProcess.nowExecutingPath.dirname +/+ "assets";

~degrees = Pseries(0, 3, 4).asStream.all; // pitches for all pitch-dependent sfx
~amp = 0.4;

~mode_record = \record;
~mode_play = \play;
~mode = ~mode_play;

server.latency = 0.25;
server.options.blockSize = 2048;
server.options.threads = 2;
server.options.numWireBufs = 256;
server.options.sampleRate = ~sample_rate;
server.options.memSize = 2 * (2 ** 16);

ServerOptions.devices.do{|x| x.postln};

/* ###### MAIN ###### */

server.waitForBoot {

	var before = Main.elapsedTime;

	var export = LuaExport.new;
	export["test"] = 1234;
	export[1234] = [1, 2, Dictionary.newFrom([\test, 1, "get", [1, 2, 3]])];
	export[[1, 2, 3]] = "test";
	export.serialize.postln;

	//~bubble_pop.();
	//~bubble_unpop.();
	//~bounce_pad.();
	//~air_dash_node_dash.();
	//~double_jump_tether_attach.();
	//~double_jump_tether_detach.();
	//~hook.();
	//~pulse.(2);
	//~accelerator_surface.();

	//"Done. Took %s".format(Main.elapsedTime - before).postln;

	//	~crystal.();
	//~metal_drum.();
	//~reverb.();
	CmdPeriod.doOnce {
		server.freeAll;
	}
};

/* ##### AUXILIARY ##### */

~detect_clipping = { |signal| ClipDetector.ar(signal, threshold: 1.0) };
~detect_volume = { |signal| ClipDetector.ar(signal, threshold: 0.0) };
~detect_done = { |signal| DetectSilence.ar(signal, 1e-4, time: 1.0, doneAction: Done.freeSelf); };

~filename = { arg prefix, name, degree;
	var res;
	if (prefix.isNil || name.isNil) { Error("In ~filename: expected string for argument #1 and #2").throw };
	if (File.exists(~export_path).not) { File.mkdir(~export_path) };
	if (File.exists(~export_path +/+ prefix).not) { File.mkdir(~export_path +/+ prefix) };

	if (degree.isNil) {
		res = ~export_path +/+ prefix +/+ name ++ "." ++ AutoRecorder.headerFormat;
	} {
		res = ~export_path +/+ prefix +/+ name ++ "_%".format(degree + 1) ++ "." ++ AutoRecorder.headerFormat;
	};

	res = res.standardizePath;
};

~recorder_start = { |path, f| ~recorder.record(path, f); };
~recorder_wait = { ~recorder.hang; };
~recorder_end = { |signal|
	~recorder.ar(signal, doneAction: Done.freeSelf);
	ClipDetector.ar(signal, threshold: 1.0);
};

/* ##### IMPLEMENTATIONS ##### */

~bubble_pop = {
    var def = SynthDef(\bubblePop, {
		arg out = 0, freq, baseStart, baseEnd, sweepDuration = 1, attack = 0.05;

		var baseFreqStart = (freq.cpsmidi + baseStart).midicps;
		var baseFreqEnd = (freq.cpsmidi + baseEnd).midicps;

		var env = Env.perc(
			attackTime: sweepDuration * attack,
			releaseTime: sweepDuration * (1 - attack)
		);

		var amplitude = EnvGen.ar(env);

		var sweepBase = amplitude * SinOsc.ar(
			freq: Line.kr(baseFreqStart, baseFreqEnd, dur: sweepDuration),
			phase: Rand(0, 2pi)
		);

		var snapDuration = 0.032;
		var noise = EnvGen.ar(Env.perc(0.001, snapDuration)) * LPF.ar(
			WhiteNoise.ar(1.0),
			freq: Line.ar(8000, 10, snapDuration - 0.001)
		);

		var signal = noise + FreeVerb.ar(sweepBase, mix: 0.05);
		signal = signal / 1.5;

		Out.ar(out, (~amp * signal).dup);

		~recorder_end.(signal);
		~detect_done.(signal);
		~detect_clipping.(signal);
	}).add;

    server.sync;

	if (~mode == ~mode_record) {
		~degrees.do { arg degree;
			~recorder_start.(
				~filename.("bubble", "pop", degree),
				Pbind(*[
					instrument: def.name,
					tempo: 1,
					sweepDuration: 0.25,
					degree: Pn(degree, 1),
					baseStart: 0,
					baseEnd: 12
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
			baseEnd: 12
		]).play;
	};
};

~bubble_unpop = {
    var forwardDef = SynthDef.new(\bubbleUnpopForward, { arg out, bufnum, dur = 1;
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

    var backwardsDef = SynthDef.new(\bubbleUnpopBackwards, { arg out, bufnum, degreeStart, degreeEnd;
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
    }).add;

	var toFree = List.new;
	var toDelete = List.new;
	var tmpFilename = "tmp_unpop";

	~degrees.do { arg degree;
		var originalPath = ~filename.("bubble", "pop", degree);
		var tempPath = ~filename.("bubble", tmpFilename, degree);

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
		var tempPath = ~filename.("bubble", tmpFilename, degree);
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
	toDelete.do { |path| File.delete(path); };
};

~bounce_pad = {
	var def = SynthDef(\bouncePad, { arg out, degree, freq = 440, dur, gate = 1;
		var wobbleAttack = 0.04;
		var ringDur = 0.1;
		var wobbleRelease = dur;

		var wobbleDegreeStart = (60 + degree);
		var wobbleDegreeEnd = (60 + degree - 9);

		var wobbleFreq = EnvGen.kr(Env.new(
			[wobbleDegreeStart, wobbleDegreeEnd].midicps,
			[wobbleAttack],
			[\hold, \exp]
		), gate: gate);

		var wobbleFreqStart = 7;
		var wobbleFreqEnd = 8;
		var wobbleFreqMod = EnvGen.kr(Env.new(
			[wobbleFreqStart, wobbleFreqStart, wobbleFreqEnd],
			[wobbleAttack + ringDur, wobbleRelease],
			[\hold, \exp]
		), gate: gate);

		var wobbleFreqDepth = EnvGen.kr(Env.new(
			1 + [0.0, 0.1, 0.03],
			[wobbleAttack, ringDur + wobbleRelease],
			[\lin, \exp]
		), gate: gate) - 1;

		var wobbleAmp = EnvGen.ar(Env.new(
			1 + [0, 1, 0],
			[wobbleAttack + ringDur, wobbleRelease],
			[\exp, \exp]
		), gate: gate) - 1;

		var feedback = LocalIn.ar(1);
		var vibrato = wobbleFreq * (1 + SinOsc.ar(wobbleFreqMod, mul: wobbleFreqDepth));
		var wobble = SinOsc.ar(vibrato) * wobbleAmp;

		var ringDegreeStart = (60 + degree);
		var ringDegreeEnd = (60 + degree - 4);
		var ringFreq = EnvGen.kr(Env.new(
			[ringDegreeStart, ringDegreeEnd].midicps,
			ringDur,
			\lin
		), gate: gate);

		var ringAmp = EnvGen.kr(Env.new(
			1 + [1, 0], ringDur, \exp
		), gate: gate) - 1;

		var ringImpulseDur = 1 / 100;
		var ringImpulse = EnvGen.ar(Env.perc(0.001, ringImpulseDur));

		var ratios = [ 0.5, 1 ];
		var ring = DynKlank.ar(`[
			ratios,
			1 ! ratios.size,
			dur ! ratios.size
		], ringImpulse, freqscale: freq) * ringImpulseDur;

		var signal = 0.0 * ring + (0.8 * wobble);
		signal = signal / 1.35;

		LocalOut.ar(vibrato / wobbleFreq);
		~detect_clipping.(signal);
		~recorder_end.(signal);
		Out.ar(out, ~amp * signal.dup);
    }).add;

	var dur = 2.0;

	if (~mode == ~mode_record) {
		~degrees.do { arg degree;
			~recorder_start.(
				~filename.("bounce_pad", "hit", degree),
				Pnew(def.name, *[
					degree: Pn(degree, 1),
					amp: 1,
					sustain: 0.2,
					dur: dur
				]);
			);
			~recorder_wait.()
		};
	} {
		Pnew(def.name, *[
			degree: Pseq(~degrees),
			dur: dur
		]).play;
	};
};

~air_dash_node_dash = {
	// initialize grain buffer
	var path = ~asset_path +/+ "tmp_granular_particles_in.wav";
	var export = false;

	// reverse buffer
	var buffer = if (export || File.exists(path).not) {
		var fillDef = SynthDef(\granular_particles_fill, { |out, recordbuf, playbuf|
			var signal, chain, rec;

			signal = PlayBuf.ar(1, playbuf,
				rate: -1 * BufRateScale.kr(playbuf),
				startPos: BufFrames.kr(playbuf) - 1,
				loop: 0
			);

			rec = RecordBuf.ar(signal, recordbuf, loop: 0, doneAction: Done.freeSelf);
			SendReply.kr(Done.kr(rec), '/done');
			Out.ar(out, (~amp * rec).dup);
		}).add;
		var synth;
		var condition = Condition.new(false);

		var playbuf, recordbuf;

		playbuf = Buffer.read(server, ~asset_path +/+ "storm.wav");
		server.sync;
		"In ~granular_synthesis: initializing buffer at `%`".format(path).postln;
		recordbuf = Buffer.alloc(server, playbuf.numFrames, 1);
		server.sync;

		synth = Synth(fillDef.name, [
			\recordbuf, recordbuf,
			\playbuf, playbuf
		]);

		OSCFunc({
			recordbuf.write(path,
				AutoRecorder.headerFormat,
				AutoRecorder.sampleFormat,
				completionMessage: {
					"In ~granular_synthesis: done.".postln;
					condition.test = true;
					condition.unhang;
					();
				}
			);
		}, '/done').oneShot;

		condition.hang;
		recordbuf;
	} {
		Buffer.read(server, path);
	};

	// initialize grain envelope
	var grainEnv = Buffer.loadCollection(server, Env.perc(1 / 10, 1).asSignal(2048).asArray);

	var def = SynthDef.new(\granular_particles, { arg out, amp, gate = 1, freq, dur, bufnum, envbufnum;
		var bufStart = 0.0, bufEnd = 0.4;
		var sliceDur = abs(bufEnd - bufStart) * BufDur.ir(bufnum);

		var grainTrig = Impulse.ar(XLine.ar(100, 1, dur) - 1);
		var grainDurMin = 0.2 * sliceDur;
		var grainDurMax = 0.4 * sliceDur;
		var grainDur = Demand.ar(grainTrig, gate, Dwhite(grainDurMin, grainDurMax));

        var grainPos = Demand.ar(grainTrig, gate, Dwhite(bufStart, bufEnd));

		var grainPanEps = 1e-5;
		var grainPanUniform = Demand.ar(grainTrig, gate, [
			Dwhite(grainPanEps, 1 - grainPanEps),
			Dwhite(grainPanEps, 1 - grainPanEps)
		]);
		var grainPan = (0.25 * (-2 * grainPanUniform[0].log).sqrt * (2pi * grainPanUniform[1]).cos).clip(-1, 1);

		var signal = GrainBuf.ar(1,
			trigger: grainTrig,
			sndbuf: bufnum,
			pos: grainPos,
			rate: 1,
			dur: grainDur,
			pan: grainPan,
			interp: 4,
			envbufnum: envbufnum,
			maxGrains: 1024
		) * EnvGen.ar(Env.new([0, 1, 1], [0.05], \welch), gate: gate);

		var sweepDur = 0.18;
		var freqSweep = freq * XLine.kr(1 / 4, 4, sweepDur);
		signal = BBandPass.ar(signal,
			freq: freqSweep,
			bw: XLine.kr(1, 10, sweepDur);
		);

		Out.ar(out, (~amp * (signal)).dup);
		~recorder_end.(signal);
		DetectSilence.ar(signal, doneAction: Done.freeSelf);
	}).add;

	if (~mode == ~mode_record) {
		~degrees.do { arg degree;
			~recorder_start.(
				~filename.("air_dash_node", "dash", degree),
				PmonoArtic(def.name, *[
					degree: Pn(degree, 1),
					bufnum: buffer.bufnum,
					envbufnum: grainEnv.bufnum,
					dur: 0.1
				]).play;
			);
			~recorder_wait.()
		};
	} {
		Pbind(*[
			instrument: def.name,
			degree: Pseq(~degrees, 1),
			bufnum: buffer.bufnum,
			envbufnum: grainEnv.bufnum,
			dur: 0.1,
			delta: 1
		]).play;
	};
};

~double_jump_tether_ratio = 0.0001;

~double_jump_tether_attach = {
	var def = SynthDef(\double_jump_tether_attach, { arg out, freq, dur, gate = 1;
		var ratio = ~double_jump_tether_ratio;
        var feedback = LocalIn.ar(1);
        var feedbackGain = 0.8;

		var impulseEnv = EnvGen.ar(Env.perc(0.01, 0.1), gate: gate);
		var releaseTime = 0.2;
		var minDelay = (-1).midiratio;
		var maxDelay = ( 1).midiratio;

		var impulse = SinOsc.ar(freq, phase: feedback) * impulseEnv;
		var delayTime = Line.kr(1, 0.05) * ratio;
		var signal = DelayC.ar(impulse + (feedbackGain * feedback), maxDelay, delayTime)
		    * EnvGen.ar(Env.asr(0.25, 1.0, dur - 0.25), gate: gate);

		LocalOut.ar(signal);

		signal = Mix.ar(signal) * 3;
		~recorder_end.(signal);
		Out.ar(out, ~amp * signal.dup);
    }).add;

	if (~mode == ~mode_record) {
		~degrees.do { |degree|
			~recorder_start.(
				~filename.("double_jump_tether", "tether", degree),
				Pnew(def.name, *[
					degree: Pn(degree, 1),
					dur: 1,
					amp: 1,
					sustain: 0.5
				]);
			);
			~recorder_wait.()
		}
	} {
		Pnew(def.name, *[
			degree: Pseq(~degrees, 1),
			dur: 1,
			amp: 1,
			sustain: 0.5
		]).play;
	}
};

~double_jump_tether_detach = {
	var def = SynthDef(\double_jump_tether_detach, { arg out, freq = 800, dur = 0.3, gate = 1;
		var impulse = PinkNoise.ar(1) * EnvGen.ar(Env.perc(1e-4, 0.01), gate: gate);

		var plucked = Pluck.ar(
			in: impulse,
			trig: Impulse.ar(0),
			maxdelaytime: freq.reciprocal,
			delaytime: freq.reciprocal,
			decaytime: dur * (freq / 800),
			coef: 0.8
		);

		var feedback = LocalIn.ar(1);

		var env =(XLine.ar(1, 2, dur) - 1);
		var delayed = DelayC.ar(plucked + feedback, delaytime: ~double_jump_tether_ratio)
		* env;

		delayed = BLowShelf.ar(delayed, 80, db: -40);
		delayed = BHiShelf.ar(delayed, 12000, db: -60);
		LocalOut.ar(LeakDC.ar(delayed) * 0.55);

		delayed = delayed * EnvGen.ar(Env.asr(attackTime: 0.05), gate: gate);
		delayed = Compander.ar(delayed, Amplitude.ar(delayed), thresh: 1.0, slopeBelow: 0.2);

		~recorder_end.(delayed);
		Out.ar(out, ~amp * delayed.dup);
	}).add;

	var dur = 0.5;
	if (~mode == ~mode_record) {
		~degrees.do { |degree|
			~recorder_start.(
				~filename.("double_jump_tether", "untether", degree),
				Pnew(def.name, *[
					degree: Pn(degree, 1),
					dur: dur
				]);
			);
			~recorder_wait.()
		}
	} {
		Pnew(def.name, *[
			degree: Pseq(~degrees, 1),
			dur: dur
		]).play;
	}
};

~accelerator_surface = {
    var grainCount = 8;
	var grainAttack = 0.075;
    var grainSustain = 0.5;
    var grainRelease = 1.0;

    var ratiosIn = #[
        1.0, 2.756, 5.404, 8.933, 13.34, 18.64, 24.82, 31.89, 39.85, 48.68, 53.71
    ];

    var ratios = ratiosIn.collect { |x, i|
        (i / (ratiosIn.size - 1)).linexp(0, 1, 1, 100)
    };

    var amplitudes = ratios.collect { |x| 1.0 / (x ** 1.5) };
    var ringTimes = ratios.collect { |x, i| (grainSustain / (x * 0.7)).min(grainSustain); };
    var frequencies = ratios.collect { |x| x * 2000 };

    var oscMessageID = '/crystalDone';
    var fillDef = SynthDef(\crystal_record, { arg out, recordbuf, recordoffset, freq = 440;
        var impulse = WhiteNoise.ar * EnvGen.ar(Env.perc(0.00001, 0.005));

        var sig = BHiPass.ar(DynKlank.ar(`[
            frequencies,
            amplitudes,
            ringTimes
        ], impulse, freqoffset: freq), 1200, 0.6);

        var trig = DetectSilence.ar(sig);

        sig = sig * EnvGen.ar(Env.new(
            [0, 1, 1, 0],
            [grainAttack, grainSustain, grainRelease],
            [\welch, \hold, \welch]
        ), doneAction: Done.freeSelf);

		sig = sig / 4;

		~detect_clipping.(sig);
        RecordBuf.ar(sig, recordbuf, recordoffset, loop: 0);
        Out.ar(out, sig.dup);
        SendReply.ar(trig, oscMessageID);
    }).add;

    var grainDur = grainAttack + grainSustain + grainRelease;
    var grainForwardPositions = grainCount.collect { |i| i / grainCount };
	var grainReversePositions = grainCount.collect { |i| (i + 1) / grainCount };
    var grainOverlap = 0.5;

	var humChord = #[0, 4, 7, 9];

	var masterAttack = grainOverlap * grainDur;
	var masterEnvEnv = Env.new(
		[0, 1, 1, 0],
		[masterAttack, grainDur, masterAttack],
		\welch
	);

	var masterDur = 2 * masterAttack + grainDur;

    var grainDef = SynthDef.new(\accelerator_grains, { arg out, dur, bufnum, envbuf, gate = 1;
        var masterAttack = grainOverlap * grainDur;
        var masterEnv = EnvGen.ar(masterEnvEnv, gate: gate);

		var trigEnv = EnvGen.ar(Env.new(
			[0, 0, 1, 1, 0],
			[masterAttack, 0.25 * dur, 0.75 * dur, masterAttack],
			\lin
		), gate: gate);

		var trig = Dust.ar(200 * trigEnv);

		var reset = 0.0;
        var grainPan = Demand.ar(trig, reset, 0.5 * Dwhite(-1, 1));

		// choose reverse or forward rate, avoiding 0 region
		var minRate = 2.reciprocal, maxRate = 2;
		var which = Demand.ar(trig, reset, Drand([0, 1], inf)); // duplicate to choose distribution
        var grainRate = Select.ar(which, [
			Demand.ar(trig, reset, -1 * Dwhite(maxRate, minRate)),
			Demand.ar(trig, reset,  1 * Dwhite(minRate, maxRate))
		]);

        var grainPos = Select.ar(which, [
			Demand.ar(trig, reset, Drand(grainForwardPositions, inf)),
			Demand.ar(trig, reset, Drand(grainReversePositions, inf)),
		]);

        var grains = GrainBuf.ar(2,
            trigger: trig,
            dur: grainDur / grainRate.abs,
            sndbuf: bufnum,
            pos: grainPos,
            pan: grainPan,
            rate: grainRate,
            envbufnum: envbuf,
            maxGrains: 1024
        ) * masterEnv;

		~detect_clipping.(grains);
        Out.ar(out, ~amp * grains);
		~recorder_end.(grains);
    }).add;

	var humDef = SynthDef.new(\accelerator_hum, { arg out, dur, degree, gate = 1;
        var masterEnv = EnvGen.ar(masterEnvEnv, gate: gate);
		var degrees = (60 - 12 + degree + humChord).midicps;
		var n = degrees.size;
		var feedback = LocalIn.ar(n);

		var hum = n.collect { |i|
            var phase = masterEnv.linlin(0, 1, 0, 0.45);
            BLowShelf.ar(SinOsc.ar(
                freq: Vibrato.kr(DC.kr(degrees[i]),
                    rate: masterEnv.linlin(0, 1, 6, 10),
                    depth: masterEnv.linlin(0, 1, 0, 0.015)
                ),
				phase: phase * feedback[i].range(-2pi, 2pi)
			) * LFPar.ar(degrees[i]), freq: (60 - (3 * 12)).midicps, db: -40);
        } * masterEnv / (degrees.size);

		var sig = Mix.ar(hum);

		~detect_clipping.(sig);
		~recorder_end.(sig);
        Out.ar(out, ~amp * sig.dup);

		LocalOut.ar(hum);
    }).add;

    var condition = Condition.new(false);

    fork {
        // allocate n consecutive grains
        var recordbuf = Buffer.alloc(server,
            numFrames: grainCount * grainDur * ~sample_rate,
			sampleRate: ~sample_rate
        );

        var rectEnv = Buffer.loadCollection(server, Env([1, 1], [1]).asSignal(512));

        var oscDoneCount = 0;
        var osc = OSCdef(\crystalDone, {
            oscDoneCount = oscDoneCount + 1;
            condition.test = (oscDoneCount == grainCount);
            condition.unhang;
        }, oscMessageID);

		var grainPattern = { |degrees|
			PmonoArtic(grainDef.name, *[
				amp: 1,
				degree: Pn(0, degrees.size),
				dur: masterDur,
				bufnum: recordbuf,
				envbuf: rectEnv
			]);
		};

		var humPattern = { |degrees|
			PmonoArtic(humDef.name, *[
				amp: 1,
				degree: Pseq(degrees, 1),
				dur: masterDur
			]);
		};

        server.sync;

        grainCount.do { |i|
            var grainFreq = (i / grainCount).linlin(0, 1, 220, 4000);
            Synth.new(fillDef.name, [
                \out, 0,
                \freq, grainFreq,
                \dur, grainDur,
                \release, grainRelease,
                \recordbuf, recordbuf,
                \recordoffset, i * grainDur * ~sample_rate
            ]);
        };

        condition.hang;
        server.sync;

		if (~mode == ~mode_record) {
			~degrees.do { |degree|
				~recorder_start.(
					~filename.("accelerator_surface", "hum", degree),
					humPattern.value([degree]).play;
				);
				~recorder_wait.()
			};

			~recorder_start.(
				~filename.("accelerator_surface", "grains"),
				grainPattern.value([0]).play;
			);

			~recorder_wait.();
		} {
            var deg = [0, 1, 4, -2];
			humPattern.value(deg).play;
			grainPattern.value(deg).play;
		};

        osc.free;
    };
};

~hook = {
	var humFreqs = #[ 240, 355, 470, 600, 720, 845 ];

	var def = SynthDef.new("\hook_filter", { arg out, freq, dur = 1, gate = 1, degree = 0, bufnum, split = 440, rate = 1, attack = 0.1;
		var isForward = (rate > 0);
		var startPos = Select.kr(isForward, [BufFrames.kr(bufnum) - 1, 0]);
		var playRate = Select.kr(isForward, [rate.abs.neg, rate.abs]);
		var signal = PlayBuf.ar(1, bufnum, rate: playRate, startPos: startPos);

		var feedback = LocalIn.ar(3);

		var bufDur = BufDur.kr(bufnum);
		var ampRelease = 0.05 * bufDur;
		var ampEnv = EnvGen.ar(
			Env.new([0, 1, 1, 0], [0.02, bufDur - ampRelease, ampRelease], \lin)
		);

		var low, mid, high, env;

		var chain = FFT(LocalBuf(2 ** 12), signal);
		var filterWeight = FFTPower.kr(chain);

		// filter noise floor
		var filtered = IFFT(PV_MagSmear(PV_MagAbove(chain, 0.025)));

		// filter hum during silence
		humFreqs.do({ |f|
			filtered = BBandStop.ar(filtered, freq: f, bw: 0.35);
		});
		signal = XFade2.ar(filtered, signal, filterWeight.linlin(0, 1.5, -1, 0.5));

		// filter fft artifact noise floor
		signal = BLowShelf.ar(signal, freq: 200, rs: 1.0, db: -18);
		signal = signal * ampEnv;

		low = BLowPass.ar(signal, split, rq: 1);
		mid = BBandPass.ar(signal, split, bw: 4);
		high = BHiPass.ar(signal, split, rq: 1);

		env = EnvGen.ar(Env.new([0, 1, 0], [attack, dur * 0.8], \welch));

		signal = XFade2.ar(RLPF.ar(Mix.ar([low, mid, high]), freq: 400), mid, Line.kr(0, -1, dur * 0.8));

		// mix some of the high clicks and bass back in
		signal = XFade2.ar(signal, BLowPass.ar(BLowShelf.ar(filtered, 4000, db: -60), freq: 5000), -0.3);
		signal = XFade2.ar(signal, BLowPass.ar(BHiShelf.ar(filtered, 1000, db: -60), freq: 500, rq: 0.2), 0);

		signal = XFade2.ar(signal, Mix.ar(GVerb.ar(signal, roomsize: 2)), -0.97);
		signal = signal * env;

		DetectSilence.ar(signal, doneAction: Done.freeSelf);

		LocalOut.ar([signal, mid, high]);

		~recorder_end.(signal);
		Out.ar(out, (~amp * signal).dup);
	}).add;

	var openBuffers = [
		"camera_shutter_open_01",
		"camera_shutter_open_02",
		"camera_shutter_open_03",
	].collect { |x| Buffer.read(server, ~asset_path +/+ x ++ ".wav") };

	var closeBuffers = [
		"camera_shutter_close_01",
		"camera_shutter_close_02",
		"camera_shutter_close_03"
	].collect { |x| Buffer.read(server, ~asset_path +/+ x ++ ".wav") };

	var play;

	server.sync;

	if (~mode == ~mode_record) {
		openBuffers.do { |buffer, i|
			~recorder_start.(
				~filename.("hook", "open", i), {
					var synth = Synth.new(def.name, [
						\out, 0,
						\amp, 1,
						\freq, 440,
						\bufnum, buffer.bufnum,
					]);
				}
			);

			~recorder_wait.();
		};

		closeBuffers.do { |buffer, i|
			~recorder_start.(
				~filename.("hook", "close", i), {
					var synth = Synth.new(def.name, [
						\out, 0,
						\amp, 1,
						\freq, 440,
						\bufnum, buffer.bufnum,
					]);
				}
			);

			~recorder_wait.();
		};
	} {
		var buffers = [openBuffers, closeBuffers].lace;
		play = { |bufs|
			if (bufs.size > 0) {
				var buf = bufs[0];
				var rest = bufs[1..];
				var synth = Synth.new(def.name, [
					\out, 0,
					\amp, 1,
					\freq, 440,
					\bufnum, buf.bufnum,
				]);

				synth.onFree {
					play.(rest);
					rest.isEmpty.if {
						buffers.do(_.free);
					};
				};
			}
		};

     play.(buffers);
	}
};

~pulse = { arg duration;
	var offsets = [-18.0, -6.0, 6.0, 18.0];

	var n = offsets.size;
	var decays = [ 0.05, 0.3, 1.0, 1.0 ];
	var fuzzes = 0.4 * [0.7, 1.0, 1.0, 0.3, 0.0];

	var phi = (1 + 5.sqrt) / 2;
	var phiEps = 0.001;
	var phiPitch = n.collect { |i| phi.pow(i + 1).frac.linlin(0, 1, 1 - phiEps, 1 + phiEps) };

	var def = SynthDef.new(\pulse, { arg out, amp, freq, degree, offset = 12, gate = 1, dur;
		var feedback = LocalIn.ar(n);

		var attackTime = 0.04;
		var osc = n.collect { |i|
			var attack = 0.045;

			var fuzzEnv = EnvGen.kr(Env.new([0, 1, 0], [attack, decays[i] * dur], [\lin, \welch]));
			var fuzz = Vibrato.kr(DC.kr(fuzzes[i]), // fuzz strength
				rate: fuzzEnv.linlin(0, 1, 9, 11.5),
				depth: fuzzEnv.linlin(0, 1, 0.05, 0.06)
			) * fuzzEnv;

			SinOsc.ar(
				freq: (60 + degree + offsets[i]).midicps * phiPitch[i],
				phase: fuzz * (feedback[i] * 2pi)
			) * EnvGen.ar(Env.new(
				[0, 1, 0],
				[attack, decays[i] * dur],
				[\lin, \sin]
			), gate: gate);
		};

		var mid, side, dry, wet;
		var stereo = 0.2; // how spread the stereo channels are

		var sig = Mix.ar(osc);
		sig = BHiShelf.ar(sig, freq: 5000, db: -60); // filter fuzz highs

		dry = sig;

		wet = DelayC.ar(sig, 0.03, 0.015);
		wet = NHHall.ar(wet.dup,
			rt60: 0.7,
			stereo: 0.7
		);

		// reduce stereo width
		mid = (wet[0] + wet[1]) * 0.5;
		side = (wet[0] - wet[1]) * 0.5 * stereo;
		wet = [mid + side, mid  - side];

		// wet / dry mix
		sig = XFade2.ar(wet, dry, -1);

		sig = BHiShelf.ar(sig, 1000, rs: 1.05.reciprocal, db: -30);
		sig = BLowShelf.ar(sig, 200, rs: 2.reciprocal, db: -10);

		sig = sig * (-1 + EnvGen.ar(Env.new(
			1 + [0, 1, 0], [1, 4], \exp
		), gate: gate, doneAction: Done.freeSelf));

		LocalOut.ar(osc);
		Out.ar(out, ~amp * sig);

		~recorder_end.(sig);
	}).add;

	server.sync;

	if (~mode == ~mode_record) {
	    ~degrees.do { arg degree;
			~recorder_start.(
				~filename.("player", "pulse", degree),
				Pnew(def.name, *[
					degree: Pn(degree, 1),
					dur: 0.15
				])
			);

			~recorder_wait.()
		};
	} {
		Pnew(def.name, *[
			degree: Pn(0, 1),
			dur: 0.15
		]).play;
	}
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
        Out.ar(out, ~amp * signal.dup);
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