var server, pwd, file_path;

server = Server.default;
server.options.memSize = 1024 * 1024;

pwd = thisProcess.nowExecutingPath.dirname;
file_path = (pwd +/+ "../jtalk/export/mei/angry/SHA_q.wav").standardizePath;

server.waitForBoot({
	var filter_def, filter_playback,
	    file_config,
	    buffer,
	    cc_spec,
	    frequency_bus, frequency_midi_def, frequency_spec,
	    bandwidth_bus, bandwidth_midi_def, bandwidth_spec
	;

	file_config = SoundFile.openRead(file_path);

	buffer = Buffer.read(server, file_path);

	MIDIClient.init;
	MIDIIn.connectAll;

	cc_spec = ControlSpec(0, 2**7 + 1, \lin);

	frequency_bus = Bus.control(server, 1);
	frequency_midi_def = MIDIdef.cc(\frequency, { arg value, id, channel, source;
		frequency_bus.set(cc_spec.unmap(value));
    });

	bandwidth_bus = Bus.control(server, 1);
	bandwidth_midi_def = MIDIdef.cc(\bandwidth, { arg value, id, channel, source;
		bandwidth_bus.set(cc_spec.unmap(value));
	});

	frequency_spec = ControlSpec(20, 20000, \exp);
	bandwidth_spec = ControlSpec(0.01, 100, \exp);  // bandwidth Q

	filter_def = SynthDef(\filter, { arg out, bufnum;
		var signal = PlayBuf.ar(file_config.numChannels, bufnum, loop: 1);
		signal = BPeakEQ.ar(signal,
			frequency_spec.map(In.kr(frequency_bus)),
			bandwidth_spec.map(In.kr(bandwidth_bus)).reciprocal
		);
		Out.ar(out, signal.dup);
	}).add;

	frequency_bus.setSynchronous(0.5);

	server.sync;

	filter_playback = Synth(\filter, [
		bufnum: buffer.bufnum
	]);

	CmdPeriod.doOnce({
		frequency_bus.free;
		filter_playback.free;
		frequency_midi_def.free;
	});
});

