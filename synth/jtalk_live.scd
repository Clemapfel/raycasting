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
    // "BA", "BAI", "BI", "DA", "GA", "GAU", "KA", "KE", "KI", "PA", "PEI", "PUU", "TA", "TAI", "TE",
    // labiodental fricatives
    //"FA", "FAU", "FI", "FOU", "FUU", "VAI", "VE", "VI", "VUU",
    // alveolar fricatives
    //"SA", "SAU", "SEI", "SO", "ZA", "ZAU", "ZE", "ZEI",
    // postalveolar fricatives
    "SHA", "SHE", "SHI", "SHUU",
    // glottal fricatives
    //"HA", "HEI",
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

    ~register_cc.(\slider1, 10, 16000, \lin);
	~register_cc.(\slider2, 0.08, 0.12, \lin);
	~register_cc.(\slider3, 0, 48000 / 2 - 1, \lin);
	~register_cc.(\slider4, 0, 3, \lin);
	~register_cc.(\slider5, 0, 1.5, \lin);
	~register_cc.(\knob1, 0, 0.4, \lin, knobs.next);
	~register_cc.(\knob2, 0, 1, \lin, knobs.next);
	~register_cc.(\knob3, 0, 1, \lin, knobs.next);

	~set_cc.(\slider1, 440);
	~set_cc.(\slider2, 0.3);
	~set_cc.(\slider3, 9500);
	~set_cc.(\slider4, 0.5);
	~set_cc.(\slider5, 2.0);
	~set_cc.(\knob1, 1);
	~set_cc.(\knob2, 1);
	~set_cc.(\knob3, 1);

    filter_def = SynthDef(\filter, { arg out, bufnum;
		var signal, chain, low, high, composite;
		var base_amplitude, composite_amplitude;
		var onset, debug, gain;

		signal = PlayBuf.ar(
			1,
			bufnum,
			rate: BufRateScale.kr(bufnum),
			loop: 0,
			doneAction: Done.freeSelf
		);
		chain = FFT(LocalBuf(1024), signal);

		onset = Onsets.kr(chain, odftype: \rcomplex, threshold: 0.55);
		onset = Lag.kr(Decay2.kr(onset, attackTime: 0.01, decayTime: 0.2));

		debug = SinOsc.ar(onset.linlin(0, 1, 220, 880), 0.0, mul: onset) * 0.25;

		chain = PV_MagSmooth(chain, 0.35);
		signal = IFFT(chain);

		low = RLPF.ar(signal, 440, 0.4);

		high = BPF.ar(signal, 9500, 0.5);

		composite = LinXFade2.ar(signal, low, onset * 2 - 1);

		/*
		base_amplitude = Amplitude.ar(signal);
		composite_amplitude = Amplitude.ar(composite);
		composite = composite * (base_amplitude / composite_amplitude.max(0.001));
		*/

		Out.ar(out, (composite).dup);
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