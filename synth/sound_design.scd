var server = Server.default;
var record_pattern;

~is_recording = true;

server.latency = 0.3;
server.options.blockSize = 2048;
server.options.numWireBufs = 256;
server.options.sampleRate = ~sample_rate;
server.options.memSize = 2 * (2 ** 16);

// ### MAIN ###

server.waitForBoot {

	var degrees = [0, 4, 8, 12];
	[
		//\bubble_pop,
		//\bubble_unpop,
		//\bubble_fizz,
		//\bounce_pad, // TODO: make it sound less like a pure sine
		//\air_dash_node_dash,
		\air_dash_node_focus
	].do { |name| currentEnvironment[name].(degrees) };

	CmdPeriod.doOnce { server.freeAll }
};

// ### AUX ###

~amp = 0.4;
~export_path = thisProcess.nowExecutingPath.dirname +/+ AutoRecorder.exportPathName;
~asset_path = thisProcess.nowExecutingPath.dirname +/+ AutoRecorder.assetPathName;
~rec = AutoRecorder;
~rec.isSilenced = ~is_recording.not;

record_pattern = { arg recordbuf, recordbus, pattern, delay = 0;
	// for multi-snyth patterns, route into recordbus, then record in separate synth

	var recordDef = SynthDef.new(("record" ++ UniqueID.next).asSymbol, { arg out, recordbus, recordbuf;
		var signal = Limiter.ar(In.ar(recordbus, 1), 0.999);
		var releaseTrig = DelayN.ar(DetectSilence.ar(signal), delay, delay);

		~rec.ar(recordbuf, signal);
		~rec.end(releaseTrig);

		Out.ar(out, (~amp * (signal)).dup);
		ClipDetector.ar(signal);
		FreeSelf.kr(releaseTrig);
	}).add;

	server.sync;

	if (recordbus.isNil or: { recordbus == 0 }) {
		Error("In precord: argument #2 `recordbus` is unassigned").throw;
	};

	if (recordbuf.isNil or: { recordbuf == 0 }) {
		Error("In precord: argument #3 `recordbuf` is unassigned").throw;
	};

	Synth(recordDef.name, [
		out: 0,
		recordbuf: recordbuf,
		recordbus: recordbus
	]);

	if (pattern.isKindOf(Function)) {
		pattern.value;
	} {
		pattern.play;
	}
};


// for multi-synth patterns, route to recordbus, then record there

// ### IMPLEMENTATIONS ###

~bubble_pop = { arg degrees;

    var def = SynthDef(\bubblePop, { arg out = 0, freq, baseStart, baseEnd, dur, recordbuf;
		var baseFreqStart = (freq.cpsmidi + baseStart).midicps;
		var baseFreqEnd = (freq.cpsmidi + baseEnd).midicps;

		var attack = 0.05;
		var env = Env.perc(
			attackTime: dur * attack,
			releaseTime: dur * (1 - attack)
		);

		var amplitude = EnvGen.ar(env, doneAction: Done.freeSelf);

		var sweepBase = amplitude * SinOsc.ar(
			freq: Line.kr(baseFreqStart, baseFreqEnd, dur: dur),
			phase: Rand(0, 2pi)
		);

		var snapDuration = 0.032;
		var noise = EnvGen.ar(Env.perc(0.001, snapDuration)) * LPF.ar(
			WhiteNoise.ar(1.0),
			freq: Line.ar(8000, 10, snapDuration - 0.001)
		);

		var signal = noise + FreeVerb.ar(sweepBase, mix: 0.05);
		signal = signal / 1.5;

		~rec.ar(recordbuf, signal);
		~rec.end(Done.kr(amplitude));
		ClipDetector.ar(signal);
		Out.ar(out, (~amp * signal).dup);
	}).add;

    server.sync;

	if (~is_recording) {
		degrees.do { arg degree;
			~rec.record(server,
				~rec.filename("bubble", "pop", degree), { arg recordbuf;
					Pnew(def.name, *[
						tempo: 1,
						dur: 0.25,
						degree: Pn(degree, 1),
						baseStart: 0,
						baseEnd: 12,
						recordbuf: recordbuf
					]).play;
				}
			);
		};
	} {
		Pnew(def.name, *[
			tempo: 1,
			dur: 0.25,
			degree: Pseq(degrees, 1),
			baseStart: 0,
			baseEnd: 12
		]).play;
	};
};

~bubble_unpop = { arg degrees;
    var forwardDef = SynthDef.new(\bubbleUnpopForward, { arg out, bufnum, dur = 1, recordbuf;
        var buf = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum));
        var signal = buf;
		var env = Line.ar(1, 0, dur);

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
		signal = signal * env;

		FreeSelf.kr(Done.kr(env));
		~rec.ar(recordbuf, signal);
		~rec.end(Done.kr(env));
		Out.ar(out, signal);
	}).add;

    var backwardsDef = SynthDef.new(\bubbleUnpopBackwards, { arg out, bufnum, degreeStart, degreeEnd, recordbuf;
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
		var ampEnv = EnvGen.ar(Env.new(
			0.75 * [0, 0, 1, 1, 0],
			[delayDur, fadeDur, sweepDur - fadeDur, fadeDur],
			[\hold, \lin, \hold, \lin]
		), doneAction: Done.freeSelf);

		signal = signal + (0.25 * FreeVerb.ar(SinOsc.ar(EnvGen.kr(freqEnv)) * ampEnv,
			room: 0.2,
			damp: 1.5
		));

		~rec.ar(recordbuf, signal);
		~rec.end(Done.kr(ampEnv));
        Out.ar(out, signal.dup);
    }).add;

	var toFree = List.new;
	var toDelete = List.new;
	var tmpFilename = "tmp_unpop";

	degrees.do { arg degree;
		var originalPath = ~rec.filename("bubble", "pop", degree);
		var tempPath = ~rec.filename("bubble", tmpFilename, degree);

		// write reverb of bubble effect to temp buffer
		var buffer = Buffer.read(server, originalPath);
		server.sync;

		~rec.record(server,
			tempPath, { arg recordbuf;
				Synth.new(forwardDef.name, [
					\bufnum, buffer,
					\dur, 2, // duration of bubble respawn
					\recordbuf, recordbuf.bufnum
				]);
			}
		);

		toFree.add(buffer);
	};

	degrees.do { arg degree;
		var tempPath = ~rec.filename("bubble", tmpFilename, degree);
		var finalPath = ~rec.filename("bubble", "unpop", degree);

		// reverse reverb signal
		var buffer = Buffer.read(server, tempPath);
		server.sync;

		if (~is_recording) {

		~rec.record(server,
			finalPath, { arg recordbuf;
				Synth.new(backwardsDef.name, [
					\bufnum, buffer,
					\degreeStart, 8,
					\degreeEnd, 0,
					\recordbuf, recordbuf.bufnum
				]);
			}
		);
		} {
			Synth.new(backwardsDef.name, [
				\bufnum, buffer,
				\degreeStart, 8,
				\degreeEnd, 0
			]);
		};

		toFree.add(buffer);
		toDelete.add(tempPath);
	};

	toFree.do { |buffer| buffer.free };
	toDelete.do { |path| File.delete(path) };
};

~bubble_fizz = { arg degrees;

	var def = SynthDef(\bubbleFizz, { arg out = 0, t, dur, recordbuf;
        var nVoices = 36;
		var masterEnv = EnvGen.ar(Env.new(1 + [0, 1, 0], [attack, 1 - attack] * dur, \exp), doneAction: Done.freeSelf) - 1;
        var sig;

        var attack = 0.05;
        var poissonRate = 400;
        var poissonEnv = EnvGen.kr(Env(1 + [0, 1, 0.0001, 0], [attack, 1 - attack, 0.2] * dur, \exp)) - 1;

		var feedback = LocalIn.ar(nVoices);

        sig = nVoices.collect { |i|
            var t = Dust.ar((poissonRate * poissonEnv) / nVoices);
			var grainFreq = TRand.ar(t.linlin(0, 1, 2000, 5000), t.linlin(0, 1, 8000, 16000), t);
            var amplitude = TExpRand.ar(0.5, 1, t);
            var decay = TRand.ar(1e-3, 1e-3, t);
            var click = EnvGen.ar(Env.perc(0.001, 0.01), gate: t);
			var freqEnv = (EnvGen.ar(Env.new([1, 2, 1], [0.3, 0.7].normalizeSum * decay, \exp), gate: t));
			var v = SinOsc.ar(grainFreq * freqEnv, phase: 2pi.rand) * (click * amplitude);
			DelayN.ar(v + (feedback[i] * 0.4), delaytime: (i / nVoices).linlin(0, 1, 0.001, 0.15));
        };

		LocalOut.ar(sig);

		sig = Mix.ar(sig) / nVoices;
        sig = sig * masterEnv * nVoices.sqrt * 1.7;

        ~rec.ar(recordbuf, sig);
		~rec.end(DelayN.ar(Impulse.ar(0), dur, dur));
        ClipDetector.ar(sig);
        Out.ar(out, (~amp * sig).dup);
    }).add;

	var dur = 0.75;

    server.sync;

	if (~is_recording) {
		var n = 4.max(degrees.size);
		n.do { |degree|
			~rec.record(server,
				~rec.filename("bubble", "fizz", degree), { arg recordbuf;
					Pnew(def.name,
						\dur, dur,
						\t, Pn(degree / n, 1),
						\recordbuf, recordbuf
					).play;
				}
			);
		};
	} {
		Pnew(def.name,
			\t, Pseq(degrees / degrees.maxItem, 1),
			\dur, Pn(dur)
		).play;
	};
};

~bounce_pad = { arg degrees;
	var ratios = [-12, 0, 12, 12 + 8].midiratio;
	var def = SynthDef(\bouncePad, { arg out, freq, dur, gate = 1, recordbuf;
		var ringDur = dur;
		var ringAttack = 0.005;
		var ringEnv = EnvGen.ar(Env.new(
			1 + [0, 1, 0], [ringAttack, ringDur - ringAttack], [\sin, \exp]
		), gate: gate) - 1;

		var amplitudes = ([0.7, 1, 0.2, 0.8]).normalizeSum;
		var decayTimes = dur * (1 / ratios.sqrt);

		var excitation = EnvGen.ar(Env.new(
			[0, -1, 1], [0.0007, 1.0], [\sin, \sin]
		), gate: gate) + (PinkNoise.ar * EnvGen.ar(Env.perc(0.0005, 0.01, curve: -6), gate: gate));

		var vibratoDepth = 0.08;
		var vibrato = SinOsc.ar(
			freq: Line.ar(9, 2, dur),
		).range(1 - vibratoDepth, 1 + vibratoDepth);

		var ring = Normalizer.ar(DynKlank.ar(`[
			ratios,
			amplitudes,
			decayTimes
		], excitation, freqscale: freq * vibrato), 0.2) * ringEnv * 5;

		var sig = ring;
		var trig = DelayN.kr(Impulse.kr(0), dur, dur);

		~rec.ar(recordbuf, sig);
		~rec.end(trig);
		FreeSelf.kr(DelayN.ar(trig));
		ClipDetector.ar(sig);
		Out.ar(out, ~amp * sig.dup);
	}).add;

	var dur = 1.5;

	server.sync;

	if (~is_recording) {
		degrees.do { arg degree;
			~rec.record(server,
				~rec.filename("bounce_pad", "bounce", degree), { arg recordbuf;
					Pnew(def.name, *[
						degree: Pn(degree, 1),
						dur: dur,
						recordbuf: recordbuf
					]).play;
				}
			);
		};
	} {
		Pnew(def.name, *[
			degree: Pseq(degrees),
			dur: dur
		]).play;
	};
};

~air_dash_node_dash = { arg degrees;
	// reverse buffers
	var pathIn = ~asset_path +/+ "storm.wav";
	var condition = Condition.new(false);

    var buffer = {
		var buffer = Buffer.read(server, pathIn, action: { |buf|
			var chans = buf.numChannels;
			buf.loadToFloatArray(action: { |data|
				var reversed = data.clump(chans).reverse.flatten;

				Buffer.loadCollection(server, reversed, chans, action: { |revBuf|
					condition.test = true;
					condition.signal;
				});
			});
		});

		condition.wait;
		buffer
	}.value;

	// initialize grain envelope
	var grainEnv = Buffer.loadCollection(server, Env.perc(1 / 10, 1).asSignal(2048).asArray);

	var def = SynthDef.new(\air_dash_node_dash, { arg out, amp, gate = 1, freq, dur, bufnum, envbufnum, recordbuf;
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

		Out.ar(out, (~amp * (signal)).dup);
		~rec.ar(recordbuf, signal);
		~rec.end(DetectSilence.ar(signal));
		FreeSelf.kr(DelayN.ar(DetectSilence.ar(signal)));
	}).add;

	server.sync;

	if (~is_recording) {
		6.do { arg degree;
			~rec.record(server,
				~rec.filename("air_dash_node", "dash", degree), { arg recordbuf;
				PmonoArtic(def.name, *[
					degree: Pn(degree, 1),
					bufnum: buffer.bufnum,
					envbufnum: grainEnv.bufnum,
					dur: 0.1,
					recordbuf: recordbuf.bufnum
				]).play;
			});
		};
	} {
		Pbind(*[
			instrument: def.name,
			degree: Pseq(degrees, 1),
			bufnum: buffer.bufnum,
			envbufnum: grainEnv.bufnum,
			recordbuf: 0,
			dur: 0.1,
			delta: 1
		]).play;
	};
};

~air_dash_node_focus = { arg degrees;
	var def = SynthDef(\air_dash_node_focus, { arg out, freq, dur, reverb = 0.1, gain = 1, maxDelay = 0.04, gate = 1;
		var signal;
		var freqs = [freq, 12.midiratio * freq];
		var impulse = Ringz.ar(Impulse.ar(0),
			freq: freqs,
			decaytime: dur
		).mean * EnvGen.ar(Env.asr(0.25, gain * 1, gain * 1), gate: gate);

		var nFeedback = 12;
		var feedback = LocalIn.ar(nFeedback);
		var releaseTrig;

		impulse = feedback + impulse;

		nFeedback.do { |i|
			var t = i / nFeedback;
			var delay = t.linexp(0, 1, maxDelay / 20, maxDelay);
			impulse = AllpassC.ar(impulse,
				maxdelaytime: maxDelay,
				delaytime: delay,
				decaytime: delay
			);

			impulse = BHiShelf.ar(impulse, 7000, db: -40);
		};

		LocalOut.ar(reverb * LeakDC.ar(impulse));
		signal = Mix.ar(impulse) / nFeedback;
		Out.ar(out, signal);
		DetectSilence.ar(signal, doneAction: Done.freeSelf);
	}).add;

	var rechargeDef = SynthDef(\air_dash_node_recharge, { arg out, freq, bufnum, recordbuf;
		var signal = PlayBuf.ar(1, bufnum,
			rate: -1 *  BufRateScale.kr(bufnum),
			startPos: BufFrames.kr(bufnum) - 1
		);

		var feedback = LocalIn.ar(1);
		var delay = 0.04;
		signal = DelayN.ar(signal + feedback, delay, delay);
		LocalOut.ar(0.4 * signal);

		Out.ar(out, signal);
		//FreeSelf.kr(DelayN.kr(Impulse.kr(0), BufDur.ir(bufnum), BufDur.ir(bufnum)));
	}).add;

	server.sync;

	if (~is_recording) {
		/*
        var tempo = 12;
		degrees.do { |degree|
			~rec.record(server,
				~rec.filename("air_dash_node", "focus", degree), { arg recordbuf, recordbus;
					record_pattern.(recordbuf, recordbus, Pnew(def.name, *[
						out: recordbus,
						degree: Pseq([degree, degree + 3], 1),
						tempo: tempo,
						reverb: 0.1
					]));
				}
			);

			~rec.record(server,
				~rec.filename("air_dash_node", "unfocus", degree), { arg recordbuf, recordbus;
					record_pattern.(recordbuf, recordbus, Pnew(def.name, *[
						out: recordbus,
						degree: Pseq([degree, degree - 2], 1),
						tempo: tempo,
						reverb: 0.1
					]));
				}
			);
		};
		*/

		degrees.do { |degree|
			var tmp_filename = ~rec.filename("air_dash_node", "tmp_recharge", degree);
			var buf;

			~rec.record(server,
				tmp_filename, { arg recordbuf, recordbus;
					record_pattern.(recordbuf, recordbus, Pnew(def.name, *[
						out: recordbus,
						degree: Pn(degree, 1),
						dur: 0.25,
						maxDelay: 0.01,
						reverb: 0.7
					]));
				}
			);

			buf = Buffer.read(server, tmp_filename);
			server.sync;

			~rec.record(server,
				~rec.filename("air_dash_node", "recharge", degree), { arg recordbuf, recordbus;
					record_pattern.(recordbuf, recordbus, Pnew(rechargeDef.name, *[
						out: recordbus,
						bufnum: Pn(buf, 1)
					]));
				}
			);
		};
	} {
		PmonoArtic(def.name, *[
			degree: Pseq([0, 5, 8, 9, 14, Rest(2), 0, 5, 10, 7, 4, Rest(2)], 1),
			decay: Pgeom(1, 0.99, inf),
			trig: Pseq([-1, 1], inf)
		]).play;
	};
};
