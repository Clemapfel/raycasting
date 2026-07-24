var server = Server.default;
var volume = Volume.new(server);
//var midi = MIDIInterface.new(server);
var prefix = thisProcess.nowExecutingPath.dirname;
var degrees = Scale.chromatic.degrees + 60;

/* ####### MAIN ####### */

volume.volume = 0; // db offset
server.waitForBoot({
	/*
	// wipe export dir
	PathName(Renderer.getExportDir()).entries.do({ |entry| File.delete(entry.fullPath); });

	// export for each degree
	degrees.do({ arg degree;
		~degree = degree;
		~bubble_pop.("bubble_pop_%.wav".format(Renderer.degreeToID(degree)));
	});
	*/

	~bubble_unpop.("bubble_unpop.wav", degrees);

	CmdPeriod.doOnce({
		s.freeAll;
	})
});

/* ####### IMPLEMENTATIONS ####### */

// overworld.bounce_pad
~bounce_pad = { arg filename, degree = 60;
  var def = SynthDef(\bounce_pad, { arg out = 0, degree = 60, dur = 1.0;
        var signal;

        var decayDuration = dur;
        var delayDuration = dur / 4;

        var wobbleFreqWobble = SinOsc.kr(EnvGen.kr(Env(
			[0, 5, 12],
			[delayDuration, decayDuration - delayDuration],
			[\lin, \exp]
		)));

        var wobbleFreq = ((degree - 12).midicps) * wobbleFreqWobble.linlin(-1, 1, 0.5, 1);
        var wobbleExcitation = EnvGen.ar(
			Env([0, 0, 1, 0], [delayDuration, 0.05], [\lin, \welch])
        );

		var ratios = [ 1, 2, 3, 5, 7, 9 ].sqrt;
        var wobble = DynKlank.ar(`[
            ratios,
            ratios.collect({ |r| 1 / r; }),
            ratios.collect({ |r| decayDuration / (r ** 0.8); })
        ], wobbleExcitation, freqscale: wobbleFreq);

		var ringDuration = 0.4;
        var ring = Ringz.ar(
            EnvGen.ar(Env.perc(0.001)),
			freq: (degree - XLine.kr(1, 0, ringDuration).range(0, 4)).midicps,
            decaytime: ringDuration
		) * EnvGen.ar(Env.perc(0.01));

        signal = ring + wobble;
        Out.ar(out, signal.dup);

		DoneSentinel.ar(signal);
    }).add;

	var dur = 1.0;
    var pattern = Pbind(*[
        instrument: \bounce_pad,
		degree: Pseq([degree].flatten),
        dur: dur,
        amp: 1.0,
		tempo: 2
    ]);

	Renderer.render(
		def,
		pattern,
		duration: dur * (60 / 60) // 1 beat at 60bpm
		filename: filename,
	);
};

// overworld.bubble.pop
~bubble_pop = { arg filename, degree = 60;

	 var def = SynthDef(\bubble_pop, { arg out = 0, amp = 1, base_start, base_end, above_start, above_end, sweep_duration;
		var attack = 0.05;
		var env = Env.perc(
            attackTime: sweep_duration * attack,
            releaseTime: sweep_duration * (1 - attack)
        );

        var amplitude = EnvGen.ar(env, doneAction: Done.freeSelf);

        var sweep_base = amplitude * SinOsc.ar(
            freq: XLine.kr(base_start, base_end, dur: sweep_duration),
            phase: Rand(0, 2pi)
        );

		var delay = 0.1 * sweep_duration;
		var sweep_above = amplitude * Line.ar(0, 1, delay) *
            SinOsc.ar(
                freq: XLine.kr(above_start, above_end, dur: sweep_duration - delay),
                phase: Rand(0, 2pi)
            );

		var snap_duration = 0.032;
		var noise = EnvGen.ar(Env.perc(0.001, snap_duration)) * LPF.ar(
            WhiteNoise.ar(1.0),
			freq: XLine.ar(8000, 10, snap_duration - 0.001)
        );

        var signal = noise + sweep_above + sweep_base;
        Out.ar(out, (amp * signal).dup);
    }).add;

	var sweep_duration = 0.1;
    var scale = Scale.chromatic;
    var pattern = Pbind(*[
        instrument: \bubble_pop,
		tempo: 3,
		degree: Pseq([degree].flatten),
        base_start:  Pfunc { |ev| (ev[\degree] +  0).midicps }, // convert midi key to hertz
        base_end:    Pfunc { |ev| (ev[\degree] + 12).midicps },
        above_start: Pfunc { |ev| (ev[\degree] -  3).midicps },
        above_end:   Pfunc { |ev| (ev[\degree] +  5).midicps },
        sweep_duration: sweep_duration,
	]);

	Renderer.render(
		def,
		pattern,
		duration: Renderer.measureDuration(pattern) + sweep_duration,
		filename: filename
	);
};

~bubble_unpop = { arg filename, degree = 60;
	var forceRender = false;

	fork {
		var unpopDuration = 0.8;
		var delayDuration = 0.3;

		// synth to be recorded, later reversed
		var reverseDef = SynthDef(\bubble_unpop_to_reverse, { arg out = 0, degree = 60, bufnum;
			var freq = degree.midicps;
			var signal = EnvGen.ar(Env.perc(0.001, 0.005)) * SinOsc.ar(4 * freq);


			signal = DelayC.ar(signal, delaytime: 0.0);
			signal = NHHall.ar(signal.dup,
				stereo: 1,
				rt60: unpopDuration,
				lowRatio: 1,
				hiRatio: 1
			)[0]; // extract left channel for stereo-to-mono

			signal = Median.ar(3, signal);

			signal = signal * EnvGen.ar(Env.new(
				[0, 1, 1],
				[delayDuration, unpopDuration + delayDuration],
				curve: \welch
			));

			Out.ar(out, signal.dup);
			RecordBuf.ar(signal, bufnum, loop: 0);
			DoneSentinel.ar(signal);
		}).add;

		// reversing synth, actual output is this
		var def, reverseSynth, synth, recordDef, recordSynth, outPath, outBuffer;

		var recordBuffer;
		var recordBufferCondition = Condition.new;
		var tmpPath = Renderer.getExportDir() +/+ ".bubble_unpop_tmp.wav";

		server.sync; // wait for synthdefs

		// render to-be-reversed audio onto disk
		if (forceRender or: { File.exists(tmpPath).not }) {

			var playCondition = Condition.new;

			recordBuffer = Renderer.allocBuffer(server,
				numFrames: (unpopDuration + delayDuration) * Renderer.sampleRate,
				numChannels: 1
			);

			server.sync;

			// play reverseDef into record buffer, inside the group
			reverseSynth = Synth(reverseDef.name, [
				bufnum: recordBuffer,
				degree: degree
			]).onFree({
				playCondition.test = true;
				playCondition.signal;
			});

			playCondition.wait;

			// write for next time
			Renderer.writeBuffer(recordBuffer, tmpPath, doneAction: {
				recordBufferCondition.test = true;
				recordBufferCondition.signal;
			});
		} {
			recordBuffer = Renderer.readBuffer(server, tmpPath, doneAction: {
				recordBufferCondition.test = true;
				recordBufferCondition.signal;
			});
		};

		recordBufferCondition.wait; // wait for recordBuffer to be filled

		def = SynthDef(\bubble_unpop, { arg out = 0, degree, inbufnum, outbufnum, popDelay;
			var buf = PlayBuf.ar(1, inbufnum,
				rate: -1 * BufRateScale.kr(inbufnum),
				startPos: BufFrames.kr(inbufnum) - 1,
				loop: 0
			);

			var popAttack = 0.02;
			var popDuration = 0.07;
			var popAmp = Env.new(
				[0, 0, 1, 0],
				[popDelay, popAttack, popDuration],
				\welch
			);

			var popFreq = EnvGen.ar(Env.new(
				[1, 1, 2],
				[popDelay, popDuration],
				[\hold, \exp]
			)) * degree.midicps;

			var pop = BPF.ar(FreeVerb.ar(
				(EnvGen.ar(popAmp) * SinOsc.ar(popFreq).dup)
			)[0], freq: popFreq, rq: 4);

			var signal = buf + pop;
			Out.ar(out, signal.dup);
			RecordBuf.ar(signal, outbufnum);
			DoneSentinel.ar(signal);
		}).add;

		outBuffer = Renderer.allocBuffer(server,
			recordBuffer.numFrames,
			recordBuffer.numChannels
		);
		outBuffer.updateInfo;

		outPath = Renderer.getExportDir +/+ filename;

		server.sync;

		synth = Synth.new(def.name, [
			inbufnum: recordBuffer,
			outbufnum: outBuffer,
			degree: degree,
			popDelay: recordBuffer.duration
		], server, 'addToTail');

		synth.onFree({
			Renderer.writeBuffer(outBuffer, outPath, doneAction: {
				"Wrote file to %".format(outPath);
			});
		});
	};
};

true;