var server = Server.default;
var recorder = AutoRecorder.new(server);

~sample_rate = AutoRecorder.sampleRate;
~temp_path = Platform.defaultTempDir +/+ "synth";
~export_path = thisProcess.nowExecutingPath.dirname +/+ "export";
~asset_path = thisProcess.nowExecutingPath.dirname +/+ "assets";

~degrees = [0, 1, 2, 3, 4, 5, 6, 7]; // pitches for all pitch-dependent sfx

~mode_record = \record;
~mode_play = \play;
~mode = \play;

server.options.numWireBufs = 256;
server.options.sampleRate = ~sample_rate;
server.options.memSize = 2 * (2 ** 16);

/* ###### MAIN ###### */

server.waitForBoot {
	var before = Main.elapsedTime;
	//~bubble_pop.();
	//~bubble_unpop.();
	//~bounce_pad.();
	//~air_dash_node_dash.();
	~double_jump_tether.();

	//"Done. Took %s".format(Main.elapsedTime - before).postln;

	//~metal_drum.();
	//~reverb.();
	CmdPeriod.doOnce {
		server.freeAll;
		recorder.stop;
	};
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
	var wobbleFeedbackBus = Bus.audio(server, 1);

	var def = SynthDef(\bouncePad, { arg out, amp, freq = 440, dur, sustain, gate = 1, tempo;

		var feedback = LocalIn.ar(3);
		var signal;

		var wobbleDuration = dur;
		var wobbleGain = 1.0;
		var wobbleFreq = (freq.cpsmidi).midicps;
		var wobbleRatio = XLine.kr(1, 2, wobbleDuration).linlin(1, 2, -1, 1);
		var wobbleImpulse = SinOsc.ar(
			freq: freq,
			phase: wobbleRatio.range(0.05, 0) * feedback[0].range(0, 2pi)
		) * EnvGen.ar(Env.perc(0.05, wobbleDuration));

		var ratio = 2.0;
		var wobbleDelay = SinOsc.kr(9).range(1 / ratio, ratio) * 1e-5 * wobbleFreq;

		var feedbackOnly = DelayL.ar(
			feedback[1] * wobbleGain,
			maxdelaytime: 1,
			delaytime: wobbleDelay
		) * Line.kr(1, 0, wobbleDuration);

		var wobble = DelayC.ar(
			wobbleImpulse + (feedback[1] * wobbleGain),
			maxdelaytime: 1,
			delaytime: wobbleDelay
		) * Line.kr(1, 0, wobbleDuration);

		var ringDuration = (dur / 2);
		var ringFeedbackAmount = 0.01;
		var ringGain = 1.0;
		var ringFreq = (freq.cpsmidi - 5).midicps;
		var ringFeedbackDelay = 0.06;
		var ringImpulseIn = SinOsc.ar(
			freq: ringFreq,
			phase: ringFeedbackAmount * DelayC.ar(feedback[2], ringFeedbackDelay, ringFeedbackDelay).range(0, 2pi)
		) * EnvGen.ar(Env.perc(0.05, ringDuration));

		var ringImpulse = Limiter.ar(4 * ringImpulseIn * AnalogBassDrum.ar(
			trig: EnvGen.ar(Env.perc(0.0, 2.0)),
			freq: ringFreq / 15
		) * EnvGen.ar(Env.new([0, 1], [0.015], \welch)));

		feedbackOnly = feedbackOnly / 6.5;
		ringImpulse = ringImpulse / 0.1;

		~detect_clipping.(feedbackOnly);
		~detect_clipping.(ringImpulseIn);

		LocalOut.ar([ wobbleImpulse, wobble, ringImpulseIn ]);

		signal = Mix.ar(DelayN.ar(feedbackOnly, 1.0, dur / 16) + ringImpulse);
		signal = XFade2.ar(signal, FreeVerb.ar(signal, room: 0.02), XLine.kr(-1, -0.5, dur));

		signal = BHiShelf.ar(signal, freq: freq * 2, db: -20);

		~detect_done.(signal);

		Out.ar(out, (amp * signal).dup);
	}).add;

	var dur = 2.0;

	if (~mode == ~mode_record) {
		~degrees.do { arg degree;
			~recorder_start.(
				~filename.("bounce_pad", "hit", degree),
				Pbind(*[
					instrument: def.name,
					degree: Pn(degree, 1),
					dur: dur
				])
			);
			~recorder_wait.()
		};
	} {
		PmonoArtic(def.name, *[
			degree: Pseq(~degrees),
			amp: 1,
			sustain: 0.2,
			dur: dur
		]).play;
	};
};

~air_dash_node_dash = {
	// initialize grain buffer
	var path = ~asset_path +/+ "granular_particles_in.wav";
	var export = false;

	// reverse buffer
	var buffer = if (export || File.exists(path).not) {
		var fillDef = SynthDef(\granular_particles_fill, { |out, amp = 1, recordbuf, playbuf|
			var signal, chain, rec;

			signal = PlayBuf.ar(1, playbuf,
				rate: -1 * BufRateScale.kr(playbuf),
				startPos: BufFrames.kr(playbuf) - 1,
				loop: 0
			);

			rec = RecordBuf.ar(signal, recordbuf, loop: 0, doneAction: Done.freeSelf);
			SendReply.kr(Done.kr(rec), '/done');
			Out.ar(out, (amp * rec).dup);
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

		Out.ar(out, (amp * (signal)).dup);
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

~vynil = {
	var envDur = max(1 / (server.sampleRate / 2), 0.01);
	var def = SynthDef.new(\vynil_noise, { arg out, amp, gate = 1;
		var trig = Dust.ar(400);

		var demand = Demand.ar(trig, gate, [
			Dwhite(0, 1).linexp(0, 1, 1000, 4000), // freq
			Dwhite(0.03, 0.6), // amp
			Dwhite(0.001, 0.001), // dur
		]);

		var eps = 1e-5;
		var grainPanUniform = Demand.ar(trig, gate, [
			Dwhite(eps, 1 - eps),
			Dwhite(eps, 1 - eps)
		]);
		var grainPan = 0.25 * (-2 * grainPanUniform[0].log).sqrt * (2pi * grainPanUniform[1]).cos;

		var grainFreq, grainAmp, grainDur, shape;
		#grainFreq, grainAmp, grainDur = demand;

		shape = 0.25 * BBandPass.ar(WhiteNoise.ar(grainAmp), grainFreq) * EnvGen.ar(
			Env.perc(1e-5, grainDur),
			gate: trig
		);

		Out.ar(out, Pan2.ar(shape, grainPan.clip(-1, 1)));
	}).add;

	server.sync;

	Synth.new(def.name, [
		\amp, 1,
		\gate, 1
	]);
};

~reverb = {
    var server = Server.default;
    var sampleRate = server.sampleRate;

	var n = 8;

	var minDelay = 0.03;
	var maxDelay = 0.1;

	// choose delay amounts
    var delayAmounts = {
		var numDelays = n;

		// pick n logarithmically distributed
		var baseTimes = numDelays.collect { |i|
			minDelay * (maxDelay / minDelay) ** (i / n)
		};

		// then nudge to nearest prime number of samples
		// this ensures delay amounts are coprime
		var isPrime = { |x|
			var prime = true;
			case
			{ x < 2 } { prime = false }
			{ x == 2 } { prime = true }
			{ x.even } { prime = false }
			{
				prime = true;
				(3, 5..x.sqrt.floor).do { |i|
					if (x % i == 0) { prime = false }
				};
			};
			prime;
		};

		var nearestPrime = { |candidate|
			var offset = 0;
			var found = false;
			var result;

			while ({ found.not }, {
				if (isPrime.(candidate + offset)) {
					result = candidate + offset;
					found = true;
				} {
					if ((candidate - offset > 1) && isPrime.(candidate - offset)) {
						result = candidate - offset;
						found = true;
					}
				};
				offset = offset + 1;
			});

			result;
		};

		baseTimes.collect { |t|
			var candidate = (t * sampleRate).round.asInteger;
			nearestPrime.(candidate) / sampleRate;
		};
	}.value;

	// generate nxn orthonormal hadamard matrix using sylvester construction
    var mixingMatrix = { |n|
		var h = [[1]];
		while ({ h.size < n }, {
			var size = h.size;
			var newH = Array.fill(size * 2, { |i|
				Array.fill(size * 2, { |j|
					var r = i % size, c = j % size;
					if (i < size or: { j < size }) {
						h[r][c]
					} {
						h[r][c].neg
					};
				});
			});
			h = newH;
		});

		h / n.sqrt;
	}.value(n);

	// signal * gain -> delay
	var inputGain = 1 ! n;

	// delay -> output * gain
    var outputGain = 1 ! n;

	// feedback weight
	var t60 = 3.0;
	var feedbackGain = delayAmounts.collect { |d|
		10 ** (-3 * d / t60);
	};

    var reverbDef = SynthDef.new(\reverbFDN, { arg out, in, amp = 0.4, gate = 1, mix = 0.5;
		var dry = In.ar(in);

		var feedbackIn = LocalIn.ar(n);
        var expansion = dry ! n;
        var delays = n.collect { |i|
            DelayC.ar(
                in: (expansion[i] * inputGain[i]) + feedbackIn[i],
                maxdelaytime: delayAmounts[i],
                delaytime: delayAmounts[i] - ControlDur.ir
            );
        };

        var mixed = mixingMatrix.collect { |row, i|
            row.sum { |x, j| x * delays[j] };
        };

        var wet = Mix.ar(delays * outputGain);

		LocalOut.ar(mixed * feedbackGain);

		Out.ar(out, amp * ((mix * dry) + (1 - mix) * wet).dup);
		DetectSilence.ar(wet, doneAction: Done.freeSelf);
    }).add;

	var buf = Buffer.read(s, ExampleFiles.apollo11);
	var playDef = SynthDef.new(\playbackFDN, { arg out = 0, amp = 1.0, gate = 1, bufnum;
		Out.ar(out, amp * PlayBuf.ar(1,
			bufnum: bufnum,
			trigger: gate,
			doneAction: Done.freeSelf
		).dup);
    }).add;

	var group = Group.new;
	var bus = Bus.audio(server, 1);

    server.sync;

	Synth.new(playDef.name, [
		\out, bus,
		\bufnum, buf.bufnum
	], group, addAction: \addToHead);

	Synth.new(reverbDef.name, [
		\out, 0,
		\in, bus
	], group, addAction: \addToTail);

	/*
    PmonoArtic(def.name, *[
        degree: 0,
        mix: 0.5,
		bufnum: Pn(buf, 1)
    ]).play;
	*/
};

~double_jump_tether = {
	var attachDef = SynthDef(\doubleJumpTetherAttach, { arg out, amp, freq, dur, gate = 1;
		var ratios = #[1, 1.37];

        var feedback = LocalIn.ar(ratios.size);
        var feedbackGain = 1.0;

        var impulse = Spring.ar(Impulse.ar(0), spring: freq) * EnvGen.ar(Env.perc(0.02, 0.2), gate: gate);
        var minDelay = 0.001, maxDelay = 0.03;
		var signal = ratios.collect({ |ratio|
			var delayTime = ratio * XLine.ar(2, 1).linlin(1, 2, minDelay, maxDelay);
			DelayC.ar(impulse + (feedbackGain * feedback), maxDelay, delayTime)
		}).mean * EnvGen.ar(Env.adsr(attackTime: 0.02, decayTime: dur, releaseTime: 2), gate: gate);


		LocalOut.ar(signal ! ratios.size);

        ~detect_clipping.(signal);
        Out.ar(out, signal.dup);
    }).add;

	Pbind(*[
		instrument: attachDef,
		degree: Pseq(~degrees, 1),
		dur: 1,
		amp: 1,
		sustain: 0.5
	]).play;
};

~metal_drum = {
	var wobbleFeedbackBus = Bus.audio(server, 1);

	var def = SynthDef(\bouncePad, { arg out, amp, freq = 440, dur, sustain, gate = 1;
		var feedback = LocalIn.ar(1);

		var feedbackSweepDur = dur;
		var feedbackAmount = Vibrato.ar(XLine.ar(1.0, 1.8, dur) - 1,
			rate: XLine.kr(1, 20, feedbackSweepDur),
			depth: 0.05
		);

		var ringDuration = dur;
		var ringGain = 1.0;
		var ringFreq = (freq.cpsmidi - 5).midicps;
		var ringDelay = XLine.ar(1.0, 1.2) - 1;
		var ringImpulseIn = SinOsc.ar(
			freq: freq,
			phase: feedbackAmount * DelayC.ar(feedback, ringDelay, ringDelay).range(0, 2pi)
		) * EnvGen.ar(Env.adsr(
			attackTime: 0.04,
			decayTime: dur,
			releaseTime: 2
		), gate: gate);

		var ringImpulse = Limiter.ar(4 * ringImpulseIn * AnalogBassDrum.ar(
			trig: EnvGen.ar(Env.perc(0.0, 2.0)),
			freq: ringFreq / 15
		) * EnvGen.ar(Env.new([0, 1], [0.015], \welch)));

		~detect_volume.(ringImpulse);
		~detect_done.(ringImpulse);

		LocalOut.ar(ringImpulseIn);

		Out.ar(out, (amp * Mix.ar([0, ringImpulse])).dup);
	}).add;

	PmonoArtic(def.name, *[
		degree: Pseq(~degrees, 1),
		amp: 1,
		sustain: 0.2
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