var server = Server.default;
var midi = MIDIInterface.new(server);
var prefix = thisProcess.nowExecutingPath.dirname;
var degrees = Scale.chromatic.degrees + 60;
var peakSentinel = PeakSentinel.new(server);

~asset_path = thisProcess.nowExecutingPath.dirname +/+ "assets";

/* ####### MAIN ####### */

server.volume.volume = 0;
server.options.sampleRate = Renderer.sampleRate;
server.options.memSize = 2 * (2 ** 20); // 2 gb

server.waitForBoot({
	//~accelerator_surface_sparkle.();
	//~player.();

	~granular.();

	CmdPeriod.doOnce({
		server.freeAll;
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
            ratios.collect({ |r| 1 / r; }).normalizeSum,
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
        instrument: def.name,
		degree: Pseq([degree].flatten),
        dur: dur,
        amp: 1.0,
		tempo: 2
    ]);

	pattern.play;
	/*

	Renderer.render(
		def,
		pattern,
		duration: dur * (60 / 60) // 1 beat at 60bpm
		filename: filename,
	);
	*/
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
        instrument: def.name,
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

// overworld.bubble.unpop
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

			var dry = EnvGen.ar(popAmp) * SinOsc.ar(popFreq).softclip;
			var wet = FreeVerb.ar(dry.dup)[0];

			var mix = 0.75;
			var pop = BBandPass.ar((dry * mix) + (wet * (1 - mix)),
				freq: popFreq * 3,
				bw: 0.8
			);

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
				"Wrote file to %".format(outPath).postln;
			});
		});
	};
};

// overworld.air_dash_node.dash
~air_dash_node_dash = { arg filename, degree = 60;
	var dashDef = SynthDef(\air_dash_node_dash_dash, { arg out, degree = 60, dur = 0.5;
		var attack = 0.05;
		var decay = 0.3;
		var sustain = (dur - attack - decay);

		var freqMul = 2;
		var dashFreqEnv = EnvGen.ar(Env.new(
			1 + [0, freqMul, freqMul, 0], // +1 for exp to not be NaN
			[attack, sustain, decay],
			[\exp, \exp]
		)) - 1;

		var dashAmp = EnvGen.ar(Env.new(
			[0, 1, 1, 0],
			[attack, sustain, decay],
			[\welch, \lin]
		));

		var bassFreq = ((degree - (4 * 12 + 6)).midicps);
		var harmonics = [1, 2, 4, 8];
		var bass = RHPF.ar(DynKlank.ar(
			`[
				harmonics,
				harmonics.collect({ |r| 1 / r });
				harmonics.collect({ |r| 0.2; })
			],
			EnvGen.ar(Env.perc(0.001)),
			freqscale: bassFreq * Line.ar(3 / 4, 1.25, 0.1)
		) * EnvGen.ar(Env.asr(attack, dur / 2))
		);

		var freq = ((degree.midicps - 12) * dashFreqEnv).max(20);
		var rq = 0.0;
		var swooshDry = BPF.ar(WhiteNoise.ar(), freq: freq, rq: 0.1) * dashAmp;
		var swooshWet = FreeVerb.ar(
			swooshDry,
			mix: 0.3,
			room: 0.6
		);
		var swooshMix = 0.4; // dry : wet
		var swoosh = ((swooshWet * (swooshMix)) + (swooshDry * (1 - swooshMix)));

		var nonCrackleDuration = 0; //attack + sustain + decay;
		var crackleAttack = 0.05;
		var crackleDecay = 2.0;
		var crackleEnv = EnvGen.ar(Env.new(
			[0, 0, 1, 0],
			[nonCrackleDuration, crackleAttack , crackleDecay ],
			[\hold, \lin, \welch]
		));

		var crackle = Dust.ar(density: 50)
		   + 0.24 * Crackle.ar(chaosParam: 2.0);

		var signal = bass + swoosh;
		Out.ar(out, signal.dup);
		DoneSentinel.ar(signal);
	}).add;

	var pattern;

	server.sync;
	pattern = Pbind(*[
		instrument: dashDef,
		\degree, Ppatlace([
			Pseq(60 + (Scale.major.degrees ++ [Scale.major.degrees.last + 1])),
			Pseq(Rest() ! Scale.major.degrees.size, Scale.major.degrees.size + 1)
		], inf),
		dur: 0.3
	]).play;
};

// fireworks
~fireworks = { arg filename, degree;
	// reference: https://www.youtube.com/watch?v=zbu-fVXP5nI
	var initSize = 1200;
	var def = SynthDef(\fireworks, { arg out, pitch = 440, amp = 1, shouldCrackle = 1, shouldRumble = 1;
		// initial snap
		var snapEnv = EnvGen.ar(Env.perc(0.01, 0.3));
		var snapTrig = WhiteNoise.ar(1);
		var snapPitch = pitch;
		var snap = FreeVerb.ar(
			Decay.ar(Mix.ar(
				0.4 * RHPF.ar(snapTrig, snapPitch, rq: 1.5),
				0.8 * BPF.ar(snapTrig, (snapPitch / 2).max(120), rq: 1.0),
				1.0 * RLPF.ar(snapTrig, (snapPitch / 16).max(120), rq: 0.4)
			)) * snapEnv,
			room: 0.42,
			damp: 0.2,
			mix: 0.2
		);

		var boomEnv = EnvGen.ar(Env.new([0, 1, 0], [0.001, 2]));
		var subPitch = EnvGen.ar(Env.new(
			[1, 1 / 4, 1 / 16] * (pitch / 4),
			[0.05, 1.5],
			\exp
		));
		var sub = SinOsc.ar(subPitch) * boomEnv;
		var rumble = LPF.ar(BrownNoise.ar(1), 200) * EnvGen.ar(Env.perc(0.02, 3.0, curve: -4));
		var boom = shouldRumble * (sub + rumble);

		var crackleAttack = 0.1;
		var crackleDecay = 1.6;
		var crackleDelay = 0.9;
		var crackleEnv = EnvGen.ar(Env.new(
			[0, 0, 1, 0],
			[0.7, crackleAttack, crackleDecay]
		));

		var crackleDry = EnvGen.ar(Env.perc(0.0001, 0.00001), gate: Dust.ar(400));
		var crackleDecayTime = 0.01;

		var crackleMix = 0.6;
		var crackleWet = FreeVerb.ar(crackleDry, room: Line.ar(1.0, 0.2, 0.8), mix: 0.4);
		var crackle = crackleEnv * Mix.ar([crackleMix * crackleDry, (1 - crackleMix) * crackleWet]);

		var signalDry = boom + snap + crackle;

		var signalWet =  NHHall.ar(signalDry.dup, stereo: 1.0,
			earlyDiffusion: 0.6
		)[0];

		var mix = 0.8;
		Out.ar(out, Mix.ar([mix * signalDry, (1 - mix) * signalWet], amp).dup);
		DoneSentinel.ar(signalWet);
	}).add;

	var numParticles = 20;
	var minDelay = 1;
	var maxDelay = 0.4;
	var firstPitch = 150;
	var minPitch = 2000;
	var maxPitch = 3000;

/*
	var pattern = Pbindf(Ptpar((numParticles + 1).collect({ |i|
		(i == 0).if({
			// initial big explosion
			[0, Pbind(*[
				pitch: Pwhite(0.8 * firstPitch, 1.2 * firstPitch, 1),
				amp: 1,
				shouldCrackle: 1,
				shouldRumble: 1,
			])]
		}, {
			// many tiny explosions
			[ minDelay + maxDelay.rand, Pbind(*[
				amp: 1 / numParticles.sqrt,
				shouldCrackle: 0,
				shouldRumble: 0,
				pitch: Pgauss(
					mean: minPitch + (0.5 * (maxPitch - minPitch)),
					dev: (maxPitch - minPitch) / 4,
					length: 1
				).clip(minPitch, maxPitch)
			])]
		})
	}).flatten), *[
		instrument: def.name
	]);
	*/

	var pattern = Pbind(*[
		instrument: def.name,
		pitch: Pwhite(0.8 * firstPitch, 1.2 * firstPitch, 1),
		amp: 1,
		shouldCrackle: 1,
		shouldRumble: 1,
	]);

	Renderer.render(
		def,
		pattern,
		duration: 3, // seconds
		filename: filename
	);

	server.sync;
	pattern.play;
};

~accelerator_surface_sparkle = { arg filename, degree;
	var scale = Scale.new(#[1, 5, 8, 11, 13]);
	var frequencies = 4.collect({ |x| 4 * (1 + x) });
	var phases = Array.series(frequencies.size, 0, (2 * pi) / frequencies.size);
	var ratios = frequencies.collect({ |f| 1 / f; });

	// bus that all voices write their dry signal to
	var reverbBus = Bus.audio(Server.default, 2);

	var voiceDef = SynthDef(\accelerator_sparkle, { arg out,
		degree = 60,
		dur = 1.0,
		overlap = 0,
		amp = 1,
		phase = 0
	;
		var baseAttack = 0.01;
		var voice = DynKlang.ar(`[
			frequencies,
			ratios,
			phases + phase
		],
		//input: Impulse.ar(0),
		freqscale: Vibrato.ar(
			DC.ar(degree.midiratio),
			rate: 6,
			depth: EnvGen.kr(Env.new([1.0, 1.02], [0.1], \exp)) - 1
		));

		var base = voice * EnvGen.ar(Env.new(
			[0, 1, 0],
			[baseAttack, ((1 + overlap) * dur) - baseAttack]
		), doneAction: 2);

		Out.ar(out, (amp * base).dup);
		DoneSentinel.ar(base);
	}).add;

	var reverbDef = SynthDef(\accelerator_sparkle_reverb, { arg out, in;
		var dry = In.ar(in, 2);
		var wet = FreeVerb.ar(dry, mix: 0.25, room: 0.3);
		Out.ar(out, wet.distort.clip);
		ReplaceOut.ar(in, Silent.ar(2));
		DoneSentinel.ar(wet);
	}).add;

	var voiceGroup = Group.new;
	var reverbGroup = Group.after(voiceGroup);

	var degrees = scale.degrees;
	var numOctaves = 2;
	var root = 60 + (4 * 12);
	var seq = [];
	var pattern;

	server.sync;

	(root + [8]).do { |root|
	    numOctaves.do { |octave|
		    degrees.do { |degree|
			    seq = seq ++ (root + degree + (12 * octave));
		     };
		     seq = seq ++ Rest(1);
		};
	};

	seq = seq ++ Rest(1);

	// we need to use a synth instead of `Pfx` because the
	// effect takes longer than the pattern. Pfx frees the fx when the
	// pattern finishes, not when the patterns emitted sounds are done
	Synth(reverbDef.name, [\in, reverbBus, \out, 0], reverbGroup);

	pattern = Pbind(*[
		group: voiceGroup,
		instrument: voiceDef.name,
		degree: Pseq(seq),
		phase: Pseries(0, (2 * pi) / (degrees.size * numOctaves)),
		overlap: 0,
		tempo: 60,
		out: reverbBus,
	]);

	pattern.play;

	//Renderer.record(server, pattern, filename);
};

~polyphonic_synth = { arg filename, degree;
	var def = SynthDef(\polyphonic_synth, { arg out, degree = 60, velocity = 1, on = 1, attack = 0.04, decay = 0.3, phase;
		var env, signal;

		env = EnvGen.kr(
			Env.asr(attack, 1, decay),
			gate: on,
		);

		signal = velocity * SinOsc.ar(degree.midicps) * env;
		Out.ar(out, signal.dup);
		DetectSilence.ar(signal, doneAction: Done.freeSelf);
	}).add;

	var velocitySpec = ControlSpec(0, 127, \lin);
	var noteToSynth = Dictionary.new;
	var getSynth = { arg degree;
		var synth;
		if (noteToSynth.at(degree).isNil) {
			synth = Synth(def.name, [
				\degree, degree,
				\velocity, 1,
				\amp, 1,
				\on, 1
			]);

			synth.onFree({
				noteToSynth.removeAt(degree);
			});

			noteToSynth.put(degree, synth);
		} {
			synth = noteToSynth.at(degree);
		};

		synth;
	};

	var onFunc = MIDIdef.noteOn(\sparkleMidiOn, {  arg velocity, degree;
		var synth = getSynth.(degree);
		synth.set("on", 1);
		synth.set("velocity", velocitySpec.unmap(velocity));
	});

	var offFunc = MIDIdef.noteOff(\sparkleMidiOff, { arg velocity, degree;
		var synth = getSynth.(degree);
		synth.set("on", 0);
	});
};

// player.on_hitbox, player.bubble.on_hitbox_bounce
~player_on_hitbox = { arg filename, degree = 60;
	var def = SynthDef.new(\player_on_hitbox, { arg out, degree, amp, dur, useBounce = 1;
		var trigDur = (0.3 + useBounce.linlin(0, 1, 0, 0.2)) * dur;
		var trigAttack = 0.01;

		var pitchEnvAttack = 0.005;
		var pitchRoot = (degree - 20 + (6 * useBounce)).midicps;
		var pitchEnv = EnvGen.ar(Env.new(
			pitchRoot * [4, 1, 0.7], [pitchEnvAttack, trigDur - pitchEnvAttack], [\exp, \exp]
		));

		var body = SinOsc.ar(Vibrato.ar(pitchEnv, rate: 6, depth: useBounce.linlin(0, 1, 0.1, 0.2))) * EnvGen.ar(Env.perc(trigAttack, trigDur, curve: -8));
		var click = LPF.ar(BrownNoise.ar, 800) * EnvGen.ar(Env.perc(0.001, 0.03));
		var voice = Mix.ar([body, click], [1, 0.1].normalizeSum);

		var bounce = voice * EnvGen.ar(Env.new(
			[0, 1, 1], [trigAttack * 2, trigDur], [\welch, \hold]
		));

		var dry = bounce;
		var wet = NHHall.ar(bounce.dup, rt60: 0.1)[0];
		var mix = 0.11;
		var signal = HPF.ar(LinXFade2.ar(dry, wet, mix.range(-1, 1)),
			freq: useBounce.linlin(0, 1, 135, 210)
		).dup;
		Out.ar(out, signal.dup);

		DoneSentinel.ar(signal);
	}).add;

	var pattern = Pbind(*[
		instrument: def.name,
		degree: Pseq(degree + [0, 1, 2, 3, 4, 5], 1),
		dur: 1
	]);

	var yesBubblePattern = Pbindf(pattern, \useBounce, 1);
	var noBubblePattern = Pbindf(pattern, \useBounce, 0);

	Pseq([yesBubblePattern, noBubblePattern]).play;
};


~dialog_box = { arg filename, degree;
	var def = SynthDef.new(\dialog_box_portamento, {
		arg out, freq, sustain, gate = 1, amp = 1, release = 1;

		var noteDuration = sustain;

		var attackTime = 0.04;
		var decayTime = 0.1;
		var releaseTime = release * (noteDuration - attackTime - decayTime);

		var frequency = Lag.ar(freq, 10.reciprocal);
		var voice = Normalizer.ar(Mix.ar([
			SinOsc.ar(frequency).softclip,
			Pulse.ar(frequency)
		] * [1, 1]));

		voice = BLowPass.ar(voice, freq: freq * 2);
		voice = voice * EnvGen.ar(
			Env.adsr(attackTime, decayTime, 1, releaseTime),
			doneAction: Done.freeSelf,
			gate: gate
		);

		Out.ar(out, (voice * amp).dup);

		DoneSentinel.ar(voice);
	}, [ nil, \ar, \kr] // freq is audio-rate (for Lag)
	).add;

	// confirm
	var confirmDegrees = 24 + [0, 7];
	var confirmPattern = PmonoArtic(def.name, *[
		degree: Pseq(confirmDegrees),
		sustain: 0.4,
		tempo: 40
	]);

	var backDegrees = 24 + [4, -4];
	var backPattern = PmonoArtic(def.name, *[
		degree: Pseq(backDegrees),
		sustain: 0.35,
		tempo: 40
	]);

	var resetCount = 2;
	var resetPattern = PmonoArtic(def.name, *[
		degree: 24 + Pseq([0, 1, 2, 1, 0, -1, 2, -1, 0]),
		sustain: 0.35,
		tempo: 40
	]);

	var navigationRelease = 0.5;
	var navigationSustain = 0.5;
	var navigationTempo = 100;
	var upDegrees = 24 + [0, 1, 2, 3] - 4;
	var upPattern = Pmono(def.name, *[
		degree: Pseq(upDegrees),
		release: navigationRelease,
		sustain: navigationSustain,
		tempo: navigationTempo
	]);

	var downDegrees = 24 + [3, 1, 2, 0] - 3;
	var downPattern = Pmono(def.name, *[
		degree: Pseq(downDegrees),
		release: navigationRelease,
		sustain: navigationSustain,
		tempo: navigationTempo
	]);

	Pseq([
		confirmPattern,
		Rest(40),
		backPattern,
		Rest(40),
		resetPattern,
		Rest(40),
		upPattern,
		Rest(40),
		downPattern,
		Rest(40)
	], 1).play;
};

~hook = { arg filename, degree;
	var buf_a = Buffer.read(server, ~asset_path +/+ "camera_shutter_a.wav");
	var buf_b = Buffer.read(server, ~asset_path +/+ "camera_shutter_b.wav");

	var def = SynthDef.new(\hook, { arg out, trig, bufnum = -1, degree, amp, dur;
		var buf = PlayBuf.ar(1, bufnum);
		var sig = buf;
		var fade_duration = 0.005;
		var before, after, carrier, sigChain, carrierChain;
		var fftBufSize = 2**12;

		// remove background hum
		[ 240, 360, 480, 600 ].do({ |freq|
			sig = BRF.ar(sig, freq: freq, rq: 0.05);
		});

		before = sig;

		// vocode
		carrier = Saw.ar(freq: 4 * Pitch.kr(sig));
		sigChain = FFT(LocalBuf(fftBufSize), sig);
		carrierChain = FFT(LocalBuf(fftBufSize), carrier);

		after = XFade2.ar(sig, IFFT(PV_MagMul(carrierChain, sigChain)), -0.8);

		after = after * EnvGen.ar(Env.new(
			[0, 1, 0],
			[fade_duration, dur - fade_duration],
			[\sin, \sin]
		));

		after = BHiShelf.ar(after, freq: 22000, db: -100);
		after = carrier;

		Out.ar(out, Select.ar(trig, [before, after]).dup);
		DoneSentinel.ar(buf);
	}, [ nil, \kr ]).add;

	var hook, unhook;

	server.sync;


	// hook
	hook = Pbind(*[
		instrument: def.name,
		bufnum: buf_a,
		dur: buf_a.duration,
		trig: Pseq([1], inf)
	]);

	// unhook
	unhook = Pbind(*[
		instrument: def.name,
		bufnum: buf_b,
		dur: buf_b.duration,
		trig: Pseq([1], 1)
	]);

	// recover

	unhook.play;
};

~player = {
	var def = SynthDef.new(\player, { arg out, freq, amp = 1, gate = 1, sustain = 1, tempo = 1;
		var noteDuration = sustain / tempo;
		var sweep = freq * XLine.ar(0.midiratio, 8.midiratio, noteDuration);
		var decay = 1;
		var signal = Ringz.ar(
			Impulse.ar(0),
			freq: sweep,
			decaytime: decay
		);

		var env = EnvGen.ar(Env.asr(
			attackTime: 0.02,
			releaseTime: decay
		), gate: gate);

		Out.ar(out, amp * (env * signal).dup);
		DetectSilence.ar(signal, doneAction: Done.freeSelf);
	}).add;

	server.sync;

	PmonoArtic(def.name, *[
		degree: Pseq([0] - 6),
		sustain: 0.1,
		amp: 1 / 2,
	]).play;
};

~granular = {
	var def = SynthDef.new(\granular, { arg out, gate = 1, freq, dur, bufnum, bufdur, amp = 0.5, density = 600, start_t = 0, end_t = 1;
		var sig = GrainBuf.ar(
			numChannels: 1,
			trigger: Impulse.ar(freq + Vibrato.ar(DC.ar(freq), depth: 0.03)),
			sndbuf: bufnum,
			dur: (end_t - start_t) * bufdur,
			pos: start_t * bufdur,
			envbufnum: -1
		);

		var env = EnvGen.ar(Env.asr(attackTime: 0.08 , releaseTime: 0.4), gate: gate);

		sig = sig * env;
		Out.ar(out, amp * sig.dup);
		DetectSilence.ar(sig, time: 2 * dur, doneAction: Done.freeSelf);
	}).add;


	var bufdur = 0.1;
	var buffer = Buffer.alloc(server, Renderer.sampleRate * bufdur, 1);
	{
		var sig = BrownNoise.ar();
		Silence.ar() * RecordBuf.ar(sig, buffer, run: 1, loop: false, doneAction: Done.freeSelf);
	}.play;

	server.sync;

	PmonoArtic(def.name, *[
		bufnum: buffer,
		bufdur: buffer.duration,
		start_t: 0.4,
		end_t: 0.6,
		dur: 0.5,
		degree: Pseq([0, 1, 2]),
		sustain: 0.25
	]).play;
};


Date.getDate; // console output on execution