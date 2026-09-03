var server = Server.default;
var recorder = AutoRecorder.new(server);

~detect_clipping = ClipDetector.new;
~detect_done = { |signal| DetectSilence.ar(signal, 1e-4, time: 1.0, doneAction: Done.freeSelf); };

~temp_path = Platform.defaultTempDir +/+ "synth";
~export_path = thisProcess.nowExecutingPath.dirname +/+ "export";
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

server.options.sampleRate = AutoRecorder.sampleRate;
server.options.memSize = 2 * (2 ** 16);

server.waitForBoot {
	var before = Main.elapsedTime;
    ~bubble_pop.();
    ~bubble_unpop.();

	"Done. Took %s".format(Main.elapsedTime - before).postln;

    CmdPeriod.doOnce {
        server.freeAll;
        recorder.stop;
    };
};

/* ##### IMPLEMENTATIONS ##### */

~degrees = [0, 1];

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

        var signal = noise + sweepAbove + sweepBase;
        Out.ar(out, (amp * signal).dup);

        ~recorder_end.(signal);
        ~detect_done.(signal);
        ~detect_clipping.(signal);
    }).add;

    server.sync;

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

		signal = signal + (0.25 * FreeVerb.ar(SinOsc.ar(EnvGen.kr(freqEnv)) * EnvGen.ar(ampEnv), room: 0.2, damp: 1.5));

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

Date.getDate;