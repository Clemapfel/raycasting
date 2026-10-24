var server = Server.default;
var record_pattern;

~rec = AutoRecorder;
~rec.isRecording = false;

server.latency = 0.3;
server.options.blockSize = 2048;
server.options.numWireBufs = 256;
server.options.sampleRate = ~sample_rate;
server.options.memSize = 2 * (2 ** 16);

// ### MAIN ###

server.waitForBoot {

	var degrees = [0, 1]; //Scale.major.degrees;
	[
		//\bubble_pop,
		//\bubble_unpop,
		//\bubble_fizz,
		//\bounce_pad,
		//\air_dash_node_dash,
		//\air_dash_node_focus,
		//\boost_field,
		//\menu
		//\main_menu_dive
		//\menu_fall
		//\bubble_field
		\player
	].do { |name| currentEnvironment[name].(degrees) };

	CmdPeriod.doOnce { server.freeAll }
};

// ### AUX ###

~amp = 0.4;
~export_path = thisProcess.nowExecutingPath.dirname +/+ AutoRecorder.exportPathName;
~asset_path = thisProcess.nowExecutingPath.dirname +/+ AutoRecorder.assetPathName;

record_pattern = { arg recordbuf, recordbus, pattern, trig = nil, delay = 0;

	// for multi-snyth patterns, route into recordbus, then record in separate synth
	var recordDef = SynthDef.new(("record" ++ UniqueID.next).asSymbol, { arg out, recordbus, recordbuf, trigbus;
		var raw = In.ar(recordbus, 1);
		var signal = Limiter.ar(raw, 0.999);
		var releaseTrig;

		if (trig.isNil) {
			releaseTrig = DelayN.ar(DetectSilence.ar(signal), delay, delay);
		} {
			releaseTrig = DelayN.ar(In.ar(trig, 1), delay, delay);
		};

		~rec.ar(recordbuf, signal);
		~rec.end(releaseTrig);

		Out.ar(out, (~amp * (signal)).dup);
		ClipDetector.ar(raw);
		FreeSelf.kr(releaseTrig);
	}).add;

	server.sync;

	if (recordbus.isNil) {
		Error("In record_pattern: argument #2 `recordbus` is unassigned").throw;
	};

	if (recordbuf.isNil) {
		Error("In record_pattern: argument #3 `recordbuf` is unassigned").throw;
	};

	Synth(recordDef.name, [
		out: 0,
		recordbuf: recordbuf,
		recordbus: recordbus,
		trig: trig
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

	if (AutoRecorder.isRecording) {
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

		if (AutoRecorder.isRecording) {

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
        var nVoices = 16;
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

	if (AutoRecorder.isRecording) {
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

		var amplitudes = ([0.7, 1, 0.6, 1.5]).normalizeSum;
		var decayTimes = dur * (1 / (ratios ** 0.25));

		var excitation = EnvGen.ar(Env.new(
			[0, -1, 1], [0.0007, 1.0], [\welch, \welch]
		), gate: gate) + (BrownNoise.ar * EnvGen.ar(Env.perc(0.0005, 0.017), gate: gate));

		var vibratoDepth = 0.08;
		var vibratoFreq = XLine.ar(7, 4, dur);
		var vibrato = SinOsc.ar(
			freq: vibratoFreq
		).range(1 - vibratoDepth, 1 + vibratoDepth);

		var ring = Limiter.ar(DynKlank.ar(`[
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

	if (AutoRecorder.isRecording) {
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

	var def = SynthDef.new(\air_dash_node_dash, { arg out, gate = 1, freq, dur, bufnum, envbufnum, recordbuf;
		var bufStart = 0.0, bufEnd = 0.4;
		var sliceDur = abs(bufEnd - bufStart) * BufDur.ir(bufnum);

		var jitter = 0.25;
		var grainTrig = Impulse.ar(
			(XLine.ar(100, 1, dur) - 1) * Demand.ar(
				Impulse.ar(400),
				0, // no reset
				Dwhite(1 - jitter, 1 + jitter, inf)
			)
		);

		var grainDurMin = 0.2 * sliceDur;
		var grainDurMax = 0.4 * sliceDur;
		var grainDur = Demand.ar(grainTrig, gate, Dwhite(grainDurMin, grainDurMax));

        var grainPos = Demand.ar(grainTrig, gate, Dwhite(bufStart, bufEnd));

		var signal = GrainBuf.ar(1,
			trigger: grainTrig,
			sndbuf: bufnum,
			pos: grainPos,
			rate: 1,
			dur: grainDur,
			pan: 0,
			interp: 4,
			envbufnum: envbufnum,
			maxGrains: 1024
		) * EnvGen.ar(Env.new([0, 1, 1], [0.05], \welch), gate: gate);

		var endTrig = DetectSilence.ar(signal, time: 1);

		Out.ar(out, (~amp * signal).dup);
		~rec.ar(recordbuf, signal);
		~rec.end(DetectSilence.ar(signal));
		FreeSelf.kr(DelayN.ar(DetectSilence.ar(signal)));
	}, [nil, \ar]).add;

	server.sync;

	if (AutoRecorder.isRecording) {
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
			}, numChannels: 1, trimEnd: false);
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
		var env = EnvGen.ar(Env.asr(0, 1, dur), gate: gate);

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

		signal = Mix.ar(impulse) / nFeedback * env;
		Out.ar(out, signal);
		FreeSelf.kr(Done.kr(env))
	}).add;

	var rechargeDef = SynthDef(\air_dash_node_recharge, { arg out, dur, bufnum, recordbuf;
		var signal = PlayBuf.ar(1, bufnum,
			rate: -1 * BufRateScale.kr(bufnum),
			startPos: (dur * BufSampleRate.kr(bufnum)).min(BufFrames.kr(bufnum) - 1);
		) * EnvGen.kr(Env.linen(0.02, dur - 0.04, 0.02), doneAction: Done.freeSelf);

		var feedback = LocalIn.ar(1);
		var delay = 0.04;
		signal = DelayN.ar(signal + feedback, delay, delay);
		LocalOut.ar(0.4 * signal);
		Out.ar(out, signal);
	}).add;

	server.sync;

	if (AutoRecorder.isRecording) {
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
			var tmp_filename = ~rec.filename("air_dash_node", "focus", degree);
			var dur = 8 / 60, reverb = 0.15, maxDelay = 0.005;
			var buf;

			~rec.record(server,
				tmp_filename, { arg recordbuf, recordbus;
					record_pattern.(recordbuf, recordbus, Pnew(def.name, *[
						out: recordbus,
						degree: Pn(degree, 1),
						dur: dur,
						maxDelay: maxDelay,
						reverb: reverb
					]));
				}
			);

			buf = Buffer.read(server, tmp_filename);
			server.sync;

			~rec.record(server,
				~rec.filename("air_dash_node", "unfocus", degree), { arg recordbuf, recordbus;
					record_pattern.(recordbuf, recordbus, Pnew(rechargeDef.name, *[
						out: recordbus,
						bufnum: Pn(buf, 1),
						dur: dur
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

~boost_field = { arg degrees;
	var octaves = 8;
	var maxRate = 4;

	var def = SynthDef.new(\boost_field, { arg out = 0, degree, rampDur, holdDur, recordbuf, envIndex, gate = 1;
		var n = 8;
		var base = (12 + degree).midiratio;

		var sweep = EnvGen.ar(Env.new([0, 1, 1], [rampDur, holdDur], [\lin, \hold]));
		var rate = 1; //sweep.linlin(0, 1, 0, maxRate);

		var maxFreq = (60 + (3 * 12)).midicps; //0.25 * (server.sampleRate / 2);
		var envAttack = ControlDur.ir;
		var doneTrig;

		var feedback = LocalIn.ar(n);
		var signal = n.collect { arg i;
			var t = i / n;
			var pos = LFSaw.ar(
				freq: rate / octaves,
				iphase: t.linlin(0, 1, 0, 2)
			).range(0, 1) * EnvGen.ar(Env.new([0, 1], 0.04), gate: gate); // prevent bleep at start

			var semis = (pos * octaves * 12).softRound(
				margin: 0,
				strength: LFCub.ar(rate / 4).range(0, 1)
			);

			var rawFreq = base * semis.midiratio;
			var trig = Changed.ar((pos * octaves * 12).softRound(0.5, strength: 0));

			var window = IEnvGen.ar(
				Env([0, 1, 0], [0.5, 0.5], \sin),
				pos
			);

			var currentFreq = rawFreq.min(maxFreq);
			var guard = rawFreq.linlin(0, maxFreq, 1, 0);

			var sine = SinOsc.ar(currentFreq,
				phase: 0 * (t.linlin(0, 1, 0.1, 0.3)  * feedback[i].range(0, 2pi) + (t * 2pi)).mod(2pi)
			) * window * guard;

			sine;
		};

		LocalOut.ar(signal);
		signal = Mix.ar(signal) / 1.25;
		signal = BLowShelf.ar(signal, freq: 80, db: -30);

		signal = signal * Select.ar(envIndex, [
			EnvGen.ar(Env.linen(envAttack, rampDur - (2 * envAttack), envAttack), gate: gate),
			EnvGen.ar(Env.linen(envAttack, holdDur - (2 * envAttack), envAttack), gate: gate)
		]);
		ClipDetector.ar(signal, 1.0);
		Out.ar(out, ~amp * signal.dup);

		doneTrig = DetectSilence.ar(signal);
		~rec.ar(recordbuf, signal);
		~rec.end(doneTrig);

		FreeSelf.kr(doneTrig);
	}).add;

	var rampDur = 3 * (octaves / maxRate);
	var holdDur = 4 * (octaves / maxRate); // cycle of hold stage

	if (AutoRecorder.isRecording) {
		[0].do { |degree|
			~rec.record(server, ~rec.filename("boost_field", "ramp", degree), { arg recordbuf;
				Synth.new(def.name, [
					rampDur: rampDur,
					holdDur: 0,
					recordbuf: recordbuf,
					degree: degree,
					envIndex: 0
				]);
			});

			/*
			~rec.record(server, ~rec.filename("boost_field", "hold", degree), { arg recordbuf;
				Synth.new(def.name, [
					rampDur: 0,
					holdDur: rampDur,
					recordbuf: recordbuf,
					degree: degree,
					envIndex: 1
				]);
			});
			*/
		}
	} {
		Pmono(def.name, *[
			rampDur: rampDur,
			holdDur: holdDur,
			recordbuf: Pn(0, 1),
			dur: rampDur + holdDur
		]).play;
	};
};

~menu = { arg degrees;
	var nControlChannels = 3;

    var def = SynthDef.new(\menu, {
        arg out, gate = 1, dur = 1, freq = 440, amp = 1, fuzz = 0.5, click = 1, osc = 1, reverb = 0.8, reverbDelay = 0.4, release = 1, wavetableStart, wavetableEnd, controlBus, endTrig;

        var beepEnv = EnvGen.ar(Env.adsr(
			attackTime: 0.02, sustainLevel: 1, releaseTime: release * dur
		), gate: gate);

		/*
		var which = EnvGen.ar(Env.asr(
			attackTime: dur / 2, sustainLevel: 1, releaseTime: dur / 2
		), gate: gate) * fuzz;*/

        var signal = VOsc.ar(
            fuzz.linlin(0, 1, wavetableStart, wavetableEnd),
            freq
        ) * beepEnv;

		var snap = BBandPass.ar(
			WhiteNoise.ar * EnvGen.ar(Env.perc(0.0015, 0.0001), gate: gate),
			freq: 3000,
			bw: 1
		);

		signal = amp * ((osc * signal) + (click * snap));

        Out.ar(out, signal);
		Out.kr(controlBus, [ endTrig, reverb, reverbDelay ]);
		FreeSelf.kr(Done.kr(beepEnv));
	}).add;

    var recordDef = SynthDef.new(\menuRecord, {
        arg out, dur = 1, recordbus, recordbuf, controlBus;

        var raw = In.ar(recordbus, 1);
        var signal = raw;

		// wait for both to trigger at least once
		var releaseTrig;

		var trig = In.kr(controlBus, nControlChannels)[0];
		var reverb = In.kr(controlBus, nControlChannels)[1];
		var reverbDelay = In.kr(controlBus, nControlChannels)[2];

		var feedback = LocalIn.ar(1);
		var delay = 0.4;
		signal = DelayC.ar(signal + (reverb * feedback), delay, delay);
		LocalOut.ar(signal);

		releaseTrig = DelayN.ar(SetResetFF.ar([
			K2A.ar(Changed.kr(trig)),
			DetectSilence.ar(signal, time: 1)
		], reset: 0).sum >= 2, dur, dur);

        ~rec.ar(recordbuf, signal);
        ~rec.end(releaseTrig);

        Out.ar(out, ~amp * signal.dup);
        ClipDetector.ar(raw);
        FreeSelf.kr(releaseTrig);
    }).add;

    server.sync;

	if (~menu_wavetablebufs.isNil) {
		 var wavetableRes = 2048;
		var signalRes = wavetableRes / 2;

		var makeWavetable = { |func|
			Signal.fill(signalRes, { |i| func.value(i / signalRes * 2pi) }).normalize.asWavetable
		};

		// pure sin to square-ish tanh
		var wavetables = [0, 0.5, 1, 1.5, 2, 2.5, 3].collect { |k|
			makeWavetable.({ |t|
				if (k == 0) {
					sin(t)
				} {
					tanh(k * sin(t)) / tanh(k)
				}
			})
		};

		var bufs = Buffer.allocConsecutive(wavetables.size, server, wavetableRes, 1);
		server.sync;
		bufs.do { |buf, i| buf.loadCollection(wavetables[i]); };
		server.sync;
		~menu_wavetablebufs = bufs;
	};

	server.sync;

    [0].do { |degree|
		var make = { arg name, degrees, dur = [1], sustain = [1], reverb = [1], reverbDelay = [0.2], release = [1], click = [1], osc = [1], fuzz = [0];
			~rec.record(server, ~rec.filename("menu", name, degree), { arg recordbuf, recordbus;
                var controlBus = Bus.control(server, nControlChannels);
                var numSteps = degrees.size;

                var recordSynth = Synth.new(recordDef.name, [
                    out: 0,
                    recordbuf: recordbuf,
                    recordbus: recordbus,
                    controlBus: controlBus
                ]);

				var wts = ~menu_wavetablebufs;

                var play = PmonoArtic(def.name, *[
                    out: recordbus,
					controlBus: controlBus,
                    wavetableStart: wts[0].bufnum,
                    wavetableEnd: wts[0].bufnum + wts.size - 1.001,

					degree: Pseq(degree + degrees, 1),
                    dur: Pseq(dur, inf),
					reverb: Pseq(reverb, inf),
					reverbDelay: Pseq(reverbDelay, inf),
					sustain: Pseq(sustain, inf),
					release: Pseq(release, inf),
					click: Pseq(click, inf),
					osc: Pseq(osc, inf),
					fuzz: Pseq(fuzz, inf),

					amp: 1,
					endTrig: 0
				]);

				var record = Pnew(def.name, *[
                    out: recordbus,
					controlBus: controlBus,
                    wavetableStart: wts[0].bufnum,
                    wavetableEnd: wts[0].bufnum + wts.size - 1.001,

					degree: Pn(0, 1),
                    dur: Pseq(dur, inf),
					reverb: Pseq(reverb, inf),
					reverbDelay: Pseq(reverbDelay, inf),
					sustain: Pseq(sustain, inf),
					release: Pseq(release, inf),
					click: Pseq(click, inf),
					osc: Pseq(osc, inf),
					fuzz: Pseq(fuzz, inf),

					delta: Pn(0, 1),
					amp: 0,
					endTrig: 1
				]);

				Pseq([play, record]).play;
            });
        };

		[
			\up -> [0, 3],
			\down -> [1, -2]
		].do { |ev|
			 make.(ev.key.asString,
				degrees: ev.value,
				dur: [12.reciprocal],
				click: [0.5],
				osc: [1],
				sustain: [0.05],
				reverb: [0],
				reverbDelay: [0.05],
				release: [0.4],
				fuzz: [0.2]
			);
		};

		[
			\right -> [-1, 1, 0],
			\left -> [1, -1, 0]
		].do { |ev|
			 make.(ev.key.asString,
				degrees: ev.value,
				dur: [12.reciprocal],
				click: [0],
				osc: [1],
				sustain: [0.15],
				reverb: [0.12],
				reverbDelay: [0.0],
				release: [0.5],
				fuzz: [0.2]
			);
		};

		[
			\confirm -> [0, Rest(4), 3],
			\back -> [3, Rest(4), 0]
		].do { |ev|
			make.(ev.key.asString,
				degrees: ev.value,
				dur: [12.reciprocal],
				click: [0.25],
				osc: [1],
				sustain: [0.4],
				reverb: [0.12],
				reverbDelay: [0.4],
				release: [0.2, 1],
				fuzz: (0.2 ! (ev.value.size - 1)) ++ 0.4
			);
		};


		make.("reset",
			degrees: [0, 3, 0],
			dur: [12.reciprocal],
			click: [0],
			osc: [1],
			sustain: [0.4],
			reverb: [0.05],
			reverbDelay: [0.3],
			release: [1.0],
			fuzz: [0.4, 0.2, 0]
		);


		make.("error",
			degrees: [-1, -4],
			dur: [12.reciprocal, 1],
			click: [0],
			osc: [1],
			sustain: [0.4],
			reverb: [0.05],
			reverbDelay: [0.3],
			release: [1.0],
			fuzz: [1.0]
		);
	};
};

~main_menu_dive = {
	var nyquist = server.sampleRate / 2 * 0.5;
	var chord = #[1, 5, 8];

	var def = SynthDef.new(\main_menu_dive, { arg out, dur, gate = 1, phase = 0, glissandoFrac, recordbuf;
		var notes = chord.collect({ |note| 60 + note });
		var lowOctave = -4;
		var highOctave = 3;
		var maxPhase = 2;
		var maxFreq = SampleRate.ir / 2 * 0.7;

		var highDelay = glissandoFrac * dur; // glissando -> hold
		var attack = 0.05;
		var decay = 0.2 * dur;
		var hold = (dur - attack - highDelay - decay).max(0);

		var freqs = (lowOctave..highOctave).collect({ |octave|
			var offset = octave * 12;
			notes.collect({ |note| (note + offset).midicps })
		}).flatten.select({ |freq| freq < nyquist });

		var oscs = freqs.collect({ |freq, i|
			var dir = if (i.even) { -1 } { 1 };


			var freqEnv0 = EnvGen.ar(Env.new(
				[(freq.cpsmidi + (dir * 12)).midicps, freq], [dur / 2], \lin
			), gate: gate);
			var freqEnv = Select.ar(phase, [freqEnv0, DC.ar(freq)]);

			var minNoise = 0.04;
			var noiseEnv0 = EnvGen.ar(Env.new([1, minNoise], [dur / 2], \lin));
			var noiseEnv = Select.ar(phase, [noiseEnv0, DC.ar(minNoise)]);

			var noise = (noiseEnv * LFNoise2.ar(rrand(1.5, 2.5))).range(-0.5.midiratio, 0.5.midiratio);

			var ampDelay = EnvGen.ar(Env.new(
				[0, (i / freqs.size).linexp(0, 1, 0 + 1, 0.5 + 1) - 1],
				[highDelay],
				\lin
			));

			var ampEnv0 = EnvGen.ar(Env.new(
				[0, 0, 1] + 1, [ampDelay, 1 - ampDelay] * (dur / 2), \exp
			)) - 1;
			var ampEnv = Select.ar(phase, [ampEnv0, DC.ar(1.0)]);

			var oscFreq = Vibrato.ar(
				Clip.ar(freqEnv * noise, 20, maxFreq),
				rate: 6,
				depth: 0.1.midiratio - 1
			);

			// bw vibrato
			var bwRate = 100;
			var bwMin = 0.04;
			var bwMax = 0.06;

			var bw0 = Line.kr(0.7, SinOsc.kr(bwRate).range(bwMin, bwMax), highDelay);
			var bw1 = SinOsc.kr(bwRate).range(bwMin, bwMax);
			var bw = Select.kr(phase, [bw0, bw1]);

			var osc = VarSaw.ar(
				freq: oscFreq,
				iphase: rrand(0, 2),
				width: SinOsc.kr(20).range(0.45, 0.55)
			);

			var pink = BBandPass.ar(PinkNoise.ar, freq: oscFreq, bw: bw) * bw.reciprocal.sqrt;
			pink * osc.range(0, 1);
		});

		var env0 = EnvGen.ar(
			Env.new([0, 0.1, 1], [attack, highDelay], \welch),
			gate: gate
		);

		var env1 = EnvGen.ar(
			Env.new([1, 1], [hold], \hold),
			gate: gate
		);

		var fade = 0.05; // prevent clipping
		var mainEnv = Select.ar(phase, [
			env0 * EnvGen.ar(Env.linen(fade, highDelay + attack, fade)),
			env1 * EnvGen.ar(Env.linen(fade, hold, fade))
		]);

		var sig = (Mix.ar(oscs) / oscs.size) * mainEnv;
		var endTrig = Select.kr(phase, [ Done.kr(env0), Done.kr(env1) ]);

		Out.ar(out, ~amp * sig.dup);
		~rec.ar(recordbuf, sig);
		~rec.end(endTrig);
		FreeSelf.kr(endTrig);
	}).add;

	var dur = 12;
	var frac = 0.4; // [0, 1]

	server.sync;

	~rec.record(server, ~rec.filename("menu", "dive_sweep"), { arg recordbuf;
		Synth(def.name, [
			out: 0,
			dur: dur,
			recordbuf: recordbuf,
			glissandoFrac: frac,
			phase: 0
		]);
	});

	~rec.record(server, ~rec.filename("menu", "dive_hold"), { arg recordbuf;
		Synth(def.name, [
			out: 0,
			dur: dur,
			recordbuf: recordbuf,
			glissandoFrac: frac,
			phase: 1
		]);
	});
};

~bubble_field = { arg degrees;

	var buf = Buffer.cueSoundFile(
		server,
		"C:\\Users\\cleme\\Workspace\\raycasting\\assets\\music\\Bloodhail - 02 Bloodhail.ogg",
		startFrame: 0,
		numChannels: 2
	);

	// create grain sample
	var grainbuf = {
		var freqs = [60, 70, 80].midiratio;
		var def = SynthDef.new(\bubble_bloop, { arg out, dur = 1, recordbuf;
			var n = freqs.size;

			// levels: 0, f1, 0, f2, 0, f3
			var levels = freqs.collect { |f| [0, f] }.flatten;

			var times = ([dur, 0] ! n).flatten.drop(-1);

			var ampEnv = EnvGen.ar(Env.perc(0.01, dur), gate: Impulse.ar(1 / dur));

			var freqSeq = EnvGen.ar(Env(levels, times, \lin));

			var endTrig = Done.kr(freqSeq);

			var sig = SinOscFB.ar(freqSeq, feedback: 0.1) * ampEnv;

			~rec.ar(recordbuf, sig);
			~rec.end(endTrig);

			Out.ar(out, sig.dup);
			FreeSelf.kr(DelayN.kr(endTrig, 0.1, 0.1));
		}).add;

		var tmp_filename = ~rec.filename("bubble_field", "tmp_grain");

		server.sync;

		~rec.record(server, tmp_filename, { arg recordbuf;
			Pmono(def.name, *[
				degree: 2,
				dur: Pn(0.25, 1),
				recordbuf: recordbuf
			]).play;
		}, record: true);

		server.sync;

		Buffer.read(server, tmp_filename);
	}.value;

	var bus = Bus.audio(server, 2);
	var grainenv = Buffer.sendCollection(server, Env.new(
		[0, 1, 1, 0],
		[1, 8, 1].normalizeSum,
		[\welch, \hold, \welch]
	).discretize());

	var levelLag = 4;

	var bubbleDef = SynthDef.new(\bubble_synh, { arg out, dur, phase = 0, gate = 1, grainbuf, grainenv, playbackbuf;
		var disk = VDiskIn.ar(2, playbackbuf, BufRateScale.kr(playbackbuf));

		var density = Select.kr(phase, [
			EnvGen.kr(Env.new([0, 1], dur, \lin), gate), // phase 0
			EnvGen.kr(Env.new([1, 1], dur, \lin), gate), // phase 1
			EnvGen.kr(Env.new([1, 0], dur, \lin), gate)  // phase 2
		]).linexp(0, 1, 1, 41) - 1;

		var trig = Dust.ar(density);

		var rate = 1.5;
		var scale = [-12, -10, -8, -7, -5, -3, -1];
		var config = Demand.ar(trig, 0, [
			Drand((scale ++ (-1 * scale)).midiratio),
			Dwhite(-1, 1) // pan
		]);

		var sig = GrainBuf.ar(2,
			trigger: trig,
			dur: BufDur.ir(grainbuf),
			sndbuf: grainbuf,
			rate: config[0] * BufRateScale.ir(grainbuf),
			pos: 0,
			interp: 4,
			pan: config[1],
			envbufnum: grainenv
		);

		sig = FreeVerb.ar(sig);

		Out.ar(out, sig);
	}).add;

	var filterDef = SynthDef.new(\bubble_field_filter, { arg out, in, gate = 1, freq, dur;

		var attack = 0.02;
		var sig = In.ar(in, 2);
		var level = \level.kr(0, levelLag, true);

		var raw = sig;
		var cutoff = LFNoise2.ar(2).range(700, 1200);
		var delay = LFNoise2.ar(0.04, 0.05);

		var feedback = LocalIn.ar(2);
		var tapl, tapr;
		var tapEps = 0.01;
		var tapDecay = 0.0;

		sig = BHiShelf.ar(sig, cutoff, db: -40);
		sig = BLowPass4.ar(sig, cutoff);
		sig = BLowShelf.ar(sig, 200, db: 5);
		sig = BPeakEQ.ar(sig, -2.5.midiratio * cutoff, rq: 4.reciprocal, db: 10);
		sig = HPF.ar(sig, 40);

		#tapl, tapr = DelayC.ar(sig + (tapDecay * feedback), delaytime: (delay - ControlDur.ir).max(0));
		#tapl, tapr = BLowPass.ar([tapl, tapr], freq: cutoff);

		LocalOut.ar([tapl, tapr]);
		sig = LinXFade2.ar(sig, [tapl, tapr], -0.5);

		sig = XFade2.ar(
            DelayN.ar(raw, delaytime: delay), // keep in sync with wet signal
			sig,
			level.linlin(0, 1, -1, 1)
		);

		Out.ar(out, ~amp * sig);
	}).add;

	var level = Pseq([0, 1, 0], 1);
	var dur = Pseq([5, 10, 5], inf);

	server.sync;

	Pmono(bubbleDef.name, *[
		playbackbuf: buf,
		grainbuf: grainbuf,
		grainenv: grainenv,
		level: level,
		dur: dur,
		out: bus,
		phase: Pseq([0, 1, 2], inf)
	]).play;

	Pmono(filterDef.name, *[
		addAction: \addAfter,
		in: bus,
		out: 0,
		degree: 0,
		level: level,
		dur: dur
	]).play;
};

~menu_fall = { arg degrees;
	var tail = 0.5; // [0, 1]

	var numVoices = 6;
	var bpQ = 1.5;

	// pan freq: speed at which the panning of all voices varies
	var swipeDef = SynthDef.new(\menu_fall, { arg out, dur, startFreq, endFreq, gate = 1, panFreq = 3, recordbuf;
		var x = Sweep.ar(Trig1.ar(gate), (1e-4.log * (1.0 - tail).log).sqrt.exp / dur);
		var t = (x.log.squared / (1.0 - tail).log).exp;
		var freq = Line.kr(startFreq, endFreq, dur: dur);
		var endTrig = DelayN.ar(Impulse.ar(0), dur, dur);

		var eps = 0.5;
		var signal = Mix.ar(
			numVoices.collect { |i|
				var posNoise = LFNoise2.ar(panFreq / numVoices).range(-1.0, 1.0);
				Pan2.ar(
					t * BPF.ar(
						PinkNoise.ar,
						freq: freq,
						rq: bpQ.reciprocal
					),
					pos: sin(panFreq * ((x / dur) + (i / numVoices)) * 2pi) * posNoise
				)
			}
		);

		~rec.ar(recordbuf, signal);
		~rec.end(endTrig);

		Out.ar(out, ~amp * signal);
		FreeSelf.kr(endTrig);
	}).add;

	// create grain sample
	var grainbuf = {
		var def = SynthDef.new(\menu_grain, { arg out, dur = 1, recordbuf;

			var sig = PinkNoise.ar; // * EnvGen.ar(Env.linen(0.02, dur - 0.04, 0.02));
			var endTrig = Done.kr(Line.kr(0, 0, dur));

			~rec.ar(recordbuf, sig);
			~rec.end(endTrig);

			Out.ar(out, ~amp * sig.dup);
			FreeSelf.kr(DelayN.kr(endTrig, 0.1, 0.1));
		}).add;

		var tmp_filename = ~rec.filename("menu", "tmp_grain");

		server.sync;

		~rec.record(server, tmp_filename, { arg recordbuf;
			Pmono(def.name, *[
				dur: Pn(0.25, 1),
				recordbuf: recordbuf
			]).play;
		}, record: true);

		server.sync;

		Buffer.read(server, tmp_filename);
	}.value;

	var fallDef = SynthDef.new(\bubble_synh, { arg out, dur, gate = 1, grainbuf, grainenv, playbackbuf;
		var density = EnvGen.kr(Env.new([0, 1, 0], [dur / 2, dur / 2], \lin), gate);

		var trig = Impulse.ar(density.linlin(0, 1, 0, 30));

		var rate = 1.5;
		var scale = [-12, -10, -8, -7, -5, -3, -1];
		var config = Demand.ar(trig, 0, [
			Drand((scale ++ (-1 * scale)).midiratio),
			Dwhite(-1, 1) // pan
		]);

		var sig = GrainBuf.ar(2,
			trigger: trig,
			dur: BufDur.ir(grainbuf),
			sndbuf: grainbuf,
			rate: config[0] * BufRateScale.ir(grainbuf),
			pos: 0,
			interp: 4,
			pan: config[1],
			envbufnum: grainenv
		);

		sig = FreeVerb.ar(sig);

		Out.ar(out, ~amp * sig);
	}).add;


	server.sync;

	// swipe
	/*
	degrees.do { |degree|
		[\a, \b].do { |i| // for different noise shapes
			~rec.record(server,
				~rec.filename("menu", "swipe", degree, i), { arg recordbuf;
					Pnew(swipeDef.name, *[
						startFreq: (60 + degree).midicps,
						endFreq: (60 + degree + 12).midicps,
						dur: Pn(10, 1),
						recordbuf: recordbuf
					]).play;
			});
		}
	};
	*/

	// fall
	~rec.record(server,
		~rec.filename("menu", "fall"), { arg recordbuf;
			Pnew(fallDef.name, *[
				dur: Pn(10, 1),
				recordbuf: recordbuf
			]).play;
	});
};

~player = { arg degrees;

	var wavetable = if (~player_jump_wt.isNil) {
		var wavetableRes = 2048;
		var signalRes = wavetableRes / 2;

		var makeWavetable = { |func|
			Signal.fill(signalRes, { |i| func.value(i / signalRes * 2pi) }).normalize.asWavetable
		};

		var wavetables = [0, 1].collect { |k|
			makeWavetable.({ |t|
				if (k == 0) {
					sin(t)
				} {
					tanh(k * sin(t)) / tanh(k)
				}
			})
		};

		var bufs = Buffer.allocConsecutive(wavetables.size, server, wavetableRes, 1);
		server.sync;
		bufs.do { |buf, i| buf.loadCollection(wavetables[i]) };
		~player_jump_wt = bufs;
	} { ~player_jump_wt };

	var def = SynthDef.new(\player_jump, {
		arg out = 0, dur = 1, freq = 440, gate = 1, wtStart, wtEnd, mix = 0.5;

		var freqEnv = XLine.ar(freq, (freq.cpsmidi + 12).midicps, dur);
		var attack = 0.04;
		var sigAmpEnv = EnvGen.ar(
			Env.new(1 + [0, 1, 0], [attack, (dur - attack).max(0.01)], \exp),
			gate: gate
		) - 1;

		// bufnum position, kept strictly below the last table
		var wtPosition = mix.linlin(0, 1, wtStart, wtEnd - 1e-4);

		var feedback = LocalIn.ar(2) * 0.9;
		var sig = (feedback + VOsc.ar(wtPosition,
			freq: freqEnv,
			phase: 0.2 * feedback.range(0, 2pi)
		)) * sigAmpEnv;

		LocalOut.ar(DelayC.ar(
			sig,
			maxdelaytime: 0.02,
			delaytime: (0.02 - ControlDur.ir).max(0)
		));
		Out.ar(out, ~amp * sig);

		DetectSilence.ar(sig, doneAction: Done.freeSelf);
	}).add;

	server.sync;

	Pbind(
		\instrument, def.name,
		\wtStart, ~player_jump_wt.first.bufnum,
		\wtEnd, ~player_jump_wt.last.bufnum,   // = first + size - 1
		\degree, Pseq([0, 1, 3, 4]),
		\dur, 0.8
	).play;
};