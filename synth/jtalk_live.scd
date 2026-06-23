var server, pwd, file_path;
var cc_spec, bend_spec, sliders, id_to_bus, id_to_spec, id_to_midi_def;

server = Server.default;
server.options.memSize = 1024 * 1024;

sliders = Pseq.new((110 .. 117)).asStream;
cc_spec = ControlSpec(0, 2**7, \lin);
bend_spec = ControlSpec(0, 2**14, \lin);
id_to_bus = IdentityDictionary.new;
id_to_spec = IdentityDictionary.new;
id_to_midi_def = IdentityDictionary.new;

~register_cc = { arg id, min_value, max_value, easing;
    var slider, midi_def_id;

	slider = sliders.next;

    midi_def_id = id; // capture
    id_to_bus.put(midi_def_id, Bus.control(server, 1));
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


pwd = thisProcess.nowExecutingPath.dirname;
file_path = (pwd +/+ "../jtalk/export/mei/angry/SHEI_q.wav").standardizePath;

server.waitForBoot({
	var filter_def, filter_playback,
	    file_config,
	    buffer
	;

	file_config = SoundFile.openRead(file_path);

	buffer = Buffer.read(server, file_path);

	~register_cc.(\frequency, 20, 24000, \exp);
	~register_cc.(\bandwidth, 0, 10);
	~register_cc.(\db, -100, 0);
	~register_cc.(\resonance, 0, 2);

	filter_def = SynthDef(\filter, { arg out, bufnum;
		var signal = PlayBuf.ar(file_config.numChannels, bufnum, loop: 1);

		/*
		signal = BPeakEQ.ar(
			in: signal,
			freq: ~get_cc.(\frequency),
			rq: ~get_cc.(\bandwidth),
			db: ~get_cc.(\db)
		);
		*/

		/*
		signal = BBandStop.ar(
			in: signal,
			freq: ~get_cc.(\frequency),
			bw: ~get_cc.(\bandwidth)
		);
		*/

		signal = RLPF.ar(
			signal,
			freq: ~get_cc.(\frequency),
			rq: ~get_cc.(\resonance)
		);

		Out.ar(out, signal.dup);
	}).add;

	// main

	MIDIClient.init;
	MIDIIn.connectAll;

	id_to_bus.at(\frequency).setSynchronous(0.5);
	id_to_bus.at(\bandwidth).setSynchronous(0.5);
	id_to_bus.at(\resonance).setSynchronous(0.5);

	server.sync;

	filter_playback = Synth(\filter, [
		bufnum: buffer.bufnum
	]);

	CmdPeriod.doOnce({
		id_to_bus.do({ arg key; id_to_bus.at(key).free; });
		id_to_midi_def.do({ arg key; id_to_midi_def.at(key).free; });
		id_to_spec.do({ arg key; id_to_spec.at(key).free; });
		filter_playback.free;
	});
});

