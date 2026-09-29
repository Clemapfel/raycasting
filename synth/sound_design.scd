var server = Server.default;
~recording = true;

server.options.blockSize = 2048;
server.options.numWireBufs = 256;
server.options.sampleRate = ~sample_rate;
server.options.memSize = 2 * (2 ** 16);

// ### MAIN ###

server.waitForBoot {
	var degrees = [0, 1, 4];

	[
		\bubble_pop,
		\bubble_unpop
	].do { |name| currentEnvironment[name].(degrees) };

	CmdPeriod.doOnce { server.freeAll }
};

// ### AUX ###

~amp = 0.4;
~rec = AutoRecorder;

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

	if (~recording) {
		degrees.do { arg degree;
			~rec.record(server,
				~rec.filename("bubble", "pop", degree), { arg recordbuf;
					Pbind(*[
						instrument: def.name,
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
		Pbind(*[
			instrument: def.name,
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

		toFree.add(buffer);
		toDelete.add(tempPath);
	};

	toFree.do { |buffer| buffer.free };
	toDelete.do { |path| File.delete(path) };
};