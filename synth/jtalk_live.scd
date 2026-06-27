var server;
var cc_spec, bend_spec, sliders, knobs, bends, id_to_bus, id_to_spec, id_to_midi_def;
var volume_bus;
var paths, import_prefix, genders, emotions, phonemes, postfixes;

server = Server.default;
server.volume = 1.0;
server.options.memSize = 1024 * 1024;

volume_bus = Bus.new(server, 1);
volume_bus.setSynchronous(1.0);

sliders = Pseq.new((110 .. 110 + 8 - 1)).asStream;
knobs = Pseq.new((102 .. 102 + 8 - 1)).asStream;
cc_spec = ControlSpec(0, 2**7, \lin);

bends = Pseq.new((0 .. 15)).asStream;
bend_spec = ControlSpec(0, 2**14, \lin);

id_to_bus = IdentityDictionary.new;
id_to_spec = IdentityDictionary.new;
id_to_midi_def = IdentityDictionary.new;

~register_cc = { arg id, min_value, max_value, easing, slider;
    var midi_def_id, bus;

    slider = slider ?? sliders.next;
    bus = Bus.control(server, 1);
    midi_def_id = id; // capture
    id_to_bus.put(midi_def_id, bus);
    id_to_spec.put(midi_def_id, ControlSpec(min_value, max_value, easing ?? \lin));
    id_to_midi_def.put(
        midi_def_id,
        MIDIdef.cc(midi_def_id, { arg value, num, channel, source;
            "% : %".format(
                midi_def_id,
                id_to_spec.at(midi_def_id).map(cc_spec.unmap(value))
            ).postln;
            id_to_bus.at(midi_def_id).set(cc_spec.unmap(value));
        }, slider)
    );
};

~get_cc = { arg id;
    id_to_spec.at(id).map(In.kr(id_to_bus.at(id)))
};

~get_cc_raw = { arg id;
    id_to_spec.at(id).map(id_to_bus.at(id))
};

~set_cc = { arg id, value;
    id_to_bus.at(id).setSynchronous(id_to_spec.at(id).unmap(value));
    "% : %".format(id, value).postln;
};

~register_bend = { arg id, min_value, max_value, easing;
    var bend, midi_def_id;
    bend = bends.next;
    midi_def_id = id;
    id_to_bus.put(midi_def_id, Bus.control(server, 1));
    id_to_spec.put(midi_def_id, ControlSpec(min_value, max_value, easing ?? \lin));
    id_to_midi_def.put(
        midi_def_id,
        MIDIdef.bend(midi_def_id, { arg value, channel, source;
            "% : %".format(
                midi_def_id,
                id_to_spec.at(midi_def_id).map(bend_spec.unmap(value))
            ).postln;
            id_to_bus.at(midi_def_id).set(bend_spec.unmap(value));
        }, bend)
    );
};
~get_bend = { arg id;
    id_to_spec.at(id).map(In.kr(id_to_bus.at(id)))
};
~set_bend = { arg id, value;
    id_to_bus.at(id).setSynchronous(value);
};

// generate paths
paths = List.new();
import_prefix = thisProcess.nowExecutingPath.dirname +/+ ".." +/+ "jtalk" +/+ "export";
genders = [ "mei" ]; //, "takumi" ];
emotions = [ "normal", "happy", "angry", "sad", "bashful" ];
phonemes = [
    // stops
     "BA", "BAI", "BI", "DA", "GA", "GAU", "KA", "KE", "KI", "PA", "PEI", "PUU", "TA", "TAI", "TE",
    // labiodental fricatives
    "FA", "FAU", "FI", "FOU", "FUU", "VAI", "VE", "VI", "VUU",
    // alveolar fricatives
    "SA", "SAU", "SEI", "SO", "ZA", "ZAU", "ZE", "ZEI",
    // postalveolar fricatives
    "SHA", "SHE", "SHI", "SHUU",
    // glottal fricatives
    "HA", "HEI",
    // affricates / nasals
    //"JA", "JII", "MA", "N", "NOU", "RA",
    // glides
    //"WEI", "WII", "WOI", "WU", "YA", "YAU",
];

postfixes = [ "", "_q", "_long", "_long_q" ];

genders.do({ arg gender;
    emotions.do({ arg emotion;
        phonemes.do({ arg phoneme;
            postfixes.do({ arg postfix;
                var path;
                path = import_prefix +/+ gender +/+ emotion +/+ (phoneme ++ postfix ++ ".wav");

				if (File.exists(path)) {
					paths.add(path);
                };
            });
        });
    });
});

thisThread.randSeed = Date.new.rawSeconds;

server.waitForBoot({
    var filter_def, play_routine;
    var file_config, sample_path;

    // Grab configuration from the first file to set up the SynthDef accurately
    sample_path = paths.first;
    file_config = SoundFile.openRead(sample_path);
    if(file_config.notNil) { file_config.close };

    ~register_cc.(\freq, 10, 1000, \lin);
	~register_cc.(\eq, 0.08, 0.12, \lin);
	~register_cc.(\bpfreq, 0, 48000 / 2 - 1, \lin);
	~register_cc.(\bpbw, 0, 3, \lin);
	~register_cc.(\bprq, 0, 1, \lin);

	~register_cc.(\mix1, 0, 1, \lin, 116);
	~register_cc.(\mix2, 0, 1, \lin, knobs.next);
	~register_cc.(\mix3, 0, 1, \lin, knobs.next);

	~set_cc.(\freq, 440 * 0.5);
	~set_cc.(\eq, 0.3);

	~set_cc.(\bpfreq, 15000);
	~set_cc.(\bpbw, 0.5);
	~set_cc.(\bprq, 2.0);

	~set_cc.(\mix1, 1);
	~set_cc.(\mix2, 1);
	~set_cc.(\mix3, 1);

    filter_def = SynthDef(\filter, { arg out, bufnum;
		var signal, low, high, filteredMix;
		var origAmp, filtAmp, makeupGain, finalSignal;

		// Original Signal
		signal = PlayBuf.ar(
			file_config.numChannels,
			bufnum,
			rate: BufRateScale.kr(bufnum),
			loop: 0,
			doneAction: Done.freeSelf
		);

		// 1. Isolate the Base
		low = RLPF.ar(signal, ~get_cc.(\freq), ~get_cc.(\eq));

		// 2. Isolate the Fricatives
		// I removed the empty HPF wrapper. A BPF with high Q is usually enough for fricatives,
		// but if you truly want to chain them, you'd do HPF.ar(BPF.ar(...), cutoffFreq).
		high = BPF.ar(signal, ~get_cc.(\bpfreq), ~get_cc.(\bpbw), ~get_cc.(\bprq).reciprocal);

		// Mix the filtered elements (removed the original signal since its normalize factor was 0)
		filteredMix = Mix([low, high] * [1.0, 1.0].normalize);

		// --- The DSP Magic: Amplitude Matching ---

		// Track the RMS envelope of both signals.
		// Attack and release times are set to 0.01 and 0.1 (good defaults for voice).
		origAmp = Amplitude.kr(signal, attackTime: 0.2, releaseTime: 0.1);
		filtAmp = Amplitude.kr(filteredMix, attackTime: 0.2, releaseTime: 0.1);

		// Calculate how much gain we need to add back.
		// .max(0.001) prevents the Synth from blowing up (dividing by zero) during silences.
		makeupGain = origAmp / filtAmp.max(0.0005);

		// Apply the dynamic makeup gain to the filtered mix
		finalSignal = filteredMix * makeupGain;

		// Safety net: AGC can sometimes cause brief volume spikes on sudden transients.
		// A Limiter catches these before they hit your speakers.
		finalSignal = Limiter.ar(finalSignal, level: 1.0, dur: 0.01);

		Out.ar(out, finalSignal.dup);
	}).add;
    // main

    MIDIClient.init;
    MIDIIn.connectAll;

    play_routine = Routine({
        loop {
            var current_path = paths.choose;
            var buffer = Buffer.read(server, current_path);

            server.sync;
            Synth(\filter, [\out, 0, \bufnum, buffer.bufnum]);

            "Playing %".format(PathName.new(current_path).fileName).postln;

			buffer.duration.wait;
            buffer.free;
        }
    }).play;

    CmdPeriod.doOnce({
		"-----------------------------".postln;
		id_to_bus.keysValuesDo({ arg key, bus;
        var value = bus.getSynchronous;
        var spec = id_to_spec.at(key);
        var mapped = spec.notNil.if({ spec.map(value) }, { value });
        "% : % (raw: %)".format(key, mapped, value).postln;
    });

    id_to_bus.do({ arg bus; bus.free; });
    id_to_midi_def.keysValuesDo({ arg key, def; def.free; });
    play_routine.stop;
});
});