var server = Server.default;
var midi = MIDIInterface.new(server);

server.options.sampleRate = Renderer.sampleRate;
server.options.memSize = 2 * (2 ** 16);

~detect_clipping = ClipDetector();
~detect_done = DoneSentinel; // sic, type
~export_path = thisProcess.nowExecutingPath.dirname +/+ "export";
~asset_path = thisProcess.nowExecutingPath.dirname +/+ "assets";

/* ##### MAIN ##### */

server.waitForBoot({

	~bubble.();
	CmdPeriod.doOnce({ server.freeAll; })
});

/* ##### IMPLEMENTATIONS ##### */

~bubble = { arg filename, degree;
	var condition = Condition.new(true);

	fork {
		var outFile;
		var recorder = Recorder(server)
		.recHeaderFormat_(Renderer.headerFormat)
		.recSampleFormat_(Renderer.sampleFormat);

		// Correct OSC path definitions
		var recordStartOSC = '/recordStart';
		var recordEndOSC = '/recordEnd';

		var pr_startRecording = { |outfile, bus, numChannels = 1|
			if (condition.test == false) {
				Error("In Renderer.startRecording: recording to % is already active".format(outFile)).throw;
			};

			recorder.record(outfile, bus, numChannels);
			condition.test = false; // Set condition test to false while recording
		};

		var pr_endRecording = {
			if (condition.test == true) {
				Error("In Renderer.endRecording: no recording is currently active").throw;
			};
			recorder.stopRecording;
			outFile = nil;
			condition.test = true; // Set condition test to true when done
			condition.unhang;      // Resume the Routine
		};

		var recordStartDef = OSCdef(\recordStartDef, { arg msg;
			var filename = msg[1];
			var bus = msg[2];
			var numChannels = msg[3];
			var outfile;

			if (File.exists(export_dir).not) { File.mkdir(export_dir) };

			outfile = ~export_path +/+ filename;
			pr_startRecording.(outfile, bus, numChannels);
		}, recordStartOSC);

		var recordEndDef = OSCdef(\recordEndDef, { arg msg;
			pr_endRecording.();
		}, recordEndOSC);

		var def = SynthDef(\testDef, { arg out = 0;
			var signal = SinOsc.ar(440) * EnvGen.ar(Env.perc());
			Out.ar(out, signal.dup);
			SendReply.ar(DetectSilence.ar(signal, doneAction: Done.freeSelf), recordEndOSC);
		}).add;

        var pattern = Pbind(*[
            instrument: def.name,
            degree: Pn(0, 1)

        ]);

		server.sync;

		NetAddr.localAddr.sendMsg('/recordStart', "bubble.wav", 0, 1);

		// Play pattern after starting recorder
		pattern.play;

		// Wait until condition.unhang is called by pr_endRecording
		condition.hang;

		// Cleanup OSC responders after execution finishes
		recordStartDef.free;
		recordEndDef.free;
	};

	/*
	var popDef = SynthDef(\bubblePop, {
		arg out = 0, amp, degree, freq, baseStart, baseEnd, aboveStart, aboveEnd, sweepDuration, attack = 0.05;

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

		~detect_done.(signal);
		~detect_clipping.(signal);
	}).add;

		var scale = Scale.chromatic;
		var pattern = Pbind(*[
			instrument: popDef.name,
			tempo: 3,
			degree: 4,
			baseState: 0,
			baseEnd: 12,
			aboveStart: -3,
			aboveEnd: 5,
			sweepDuration: 0.1,
		]);
	*/
};


Date.getDate; // console output on execution