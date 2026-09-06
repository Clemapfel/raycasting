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
	~bounce_pad.();
	//~air_dash_node_dash.();


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
	var def = SynthDef(\bouncePad, { arg out, amp, freq, dur, gate = 1;
		var signal;

		var ringFreq = Ball.ar(Impulse.ar(0), g: 10, damp: 0, friction: 0);
		var ringAmp = EnvGen.ar(Env.perc(0.1, 0.04), gate: gate);
		var ring = Saw.ar(freq: freq);

		// wobble

		var wobbleFreq = Ball.ar(Impulse.ar(0),
			g: 0.01,
			damp: 0.0,
			friction: 0.002
		);

		var feedback = LocalIn.ar(1);
		var wobble = (1 - 1e-3) * SinOsc.ar(
			freq: wobbleFreq.linlin(0, 1, freq * (1 - 0.4), freq + (1 + 0.4)),
			phase: 0.35 * feedback
		);
		LocalOut.ar(wobble);

		~detect_clipping.(ring);
		~detect_clipping.(wobble);

		signal = Mix.ar([ring, 0.0 * wobble]);

		// make sure impulse last exactly dur long
		signal = signal * EnvGen.ar(
			Env.new([ 0, 1, 0 ], [ 0.01, dur - 0.1, 0.1 ]),
			doneAction: Done.freeSelf
		);

		Out.ar(out, (amp * signal).dup);
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
			dur: 2,
			amp: 1
		]).play;
	};
};

~air_dash_node_dash = {
     var def = SynthDef(\violin, { |out = 0, freq = 440, amp = 0.5, gate = 1, pan = 0|

        // --- 1. Bow Dynamics & Articulation ---
        // A real bow stroke requires a higher initial pressure (bite) to catch the string,
        // which then settles. When the gate goes to 0 (bow lifts), the force drops to 0.
        var forceEnv = EnvGen.kr(Env([0, 1.5, 1.0, 0], [0.05, 0.1, 0.08], \lin, releaseNode: 2), gate);

        // We use a slight lag on the frequency to mimic the finger gliding/placing on the fingerboard
        var fLag = Lag.kr(freq, 0.03);

        // Natural delayed vibrato introduced by the left hand
        var vibEnv = EnvGen.kr(Env([0, 0, 1], [0.2, 0.4]), gate); // Vibrato ramps up after 0.2s
        var vibrato = SinOsc.kr(Vibrato.kr(rate: 6, rateVariation: 0.1, depth: 0.2, delay: 0.1), 0, 0.007 * vibEnv);
        var f = fLag * (1 + vibrato);

        // --- 2. String Excitation (The Bowed String) ---
        // DWGBowed parameters tuned for realism:
        // pos: 0.14 mimics bowing roughly 1/7th of the string length from the bridge (standard position).
        // c1 (0.25) & c3 (30) dictate high and low-frequency loss. High frequencies decay faster.
        // release: 2.0 allows the internal DWG model to ring naturally when gate goes to 0.
        var stringDecay = 2.0;
        var sig = DWGBowed.ar(
            freq: f,
            velb: 0.8 * forceEnv, // Velocity drops when bow lifts
            force: 1.2 * forceEnv, // Pressure drops when bow lifts
            gate: gate,
            pos: 0.14,
            release: stringDecay,
            c1: 0.25,
            c3: 30
        );

        // --- 3. Sympathetic Resonance (The Open Strings) ---
        // A violin has 4 open strings: G3, D4, A4, E5. We simulate these using comb filters (waveguides).
        // They absorb energy from the main string and ring out independently.
        var openStrings = [196.00, 293.66, 440.00, 659.25]; // Frequencies in Hz
        var sympDecays  = [3.5, 2.8, 2.0, 1.5]; // Lower frequencies decay slower in real life

        var sympResonance = openStrings.collect { |sf, i|
            // Excite the comb filters primarily with the higher transient energy to avoid low-end mud
            var exciter = HPF.ar(sig, 150);
            CombL.ar(exciter, maxdelaytime: 0.01, delaytime: 1/sf, decaytime: sympDecays[i])
        }.sum;

        // --- 4. Violin Body Resonance (Formants & Wood) ---
        // We combine DWGSoundBoard (for complex woody reflections) with a Klank bank
        // modeled specifically on the resonant modes of a real violin body:
        // A0 (Air mode), CBR (Wood), B1-, B1+, and upper body modes.
        var bodyFreqs = [275, 400, 455, 550, 650, 900, 1200, 3000];
        var bodyAmps  = [1.0, 0.8, 0.8, 0.9, 0.6, 0.5, 0.3, 0.1];
        var bodyRings = [1.2, 1.0, 0.8, 0.6, 0.4, 0.2, 0.1, 0.05]; // High freq body modes decay extremely fast

        var combinedSignal = sig + (sympResonance * 0.05);

        var dwgBody = DWGSoundBoard.ar(combinedSignal);
        var modalBody = Klank.ar(`[bodyFreqs, bodyAmps, bodyRings], combinedSignal);


        // --- 5. Master Release Envelope ---
        // This keeps the synth alive after the bow lifts (gate=0), allowing the
        // free decay of the main string, sympathetic strings, and body to ring out
        // completely before SuperCollider kills the node.
        var masterEnv = EnvGen.kr(Env.asr(0.01, 1, stringDecay + 1.0), gate, doneAction: 2);


        // Mix the direct string, DWG physical body, and modal body resonances
        var outSig = (combinedSignal * 0.4) + (dwgBody * 0.4) + (modalBody * 0.05);

        // Final EQ to remove harsh digital artifacts and keep it in the violin's acoustic range
        outSig = LPF.ar(outSig, 10000);
        outSig = HPF.ar(outSig, 180);

        Out.ar(out, Pan2.ar(outSig * amp * masterEnv, pan));
    }).add;

    s.sync;

    // PmonoArtic will articulate staccato and legato gracefully.
    // Notice how the physical free-decay rings out vividly on the longer rests/releases.
    PmonoArtic(def.name,
        \degree, Pseq([0, 2, 4, 3, 2, -3, -1, 0], inf),
        \dur, Pseq([0.5, 0.5, 1.0, 0.5, 0.5, 0.5, 0.5, 2.0], inf),
        \legato, Pseq([0.8, 1.05, 0.5, 0.8, 1.05, 1.05, 1.05, 0.5], inf), // < 1 triggers free decay, > 1 glides
        \amp, 0.4
    ).play;
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