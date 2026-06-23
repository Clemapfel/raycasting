var server_options, server, pwd;

server_options = ServerOptions.new;
server_options.threads = 12;
server_options.memSize = 1024 * 1024;
server_options.numOutputBusChannels = 2;
server_options.numInputBusChannels = 2;

server = Server(\nrt, options: server_options);

pwd = thisProcess.nowExecutingPath.dirname;

["meow.wav", "aaaa.wav"].do({ arg filename; fork {

	var file_path, file_config, filter_def, synth, score, score_offset, buffer, output_path, condition;

	file_path = pwd +/+ filename;

	// read config for file metadata
	file_config = SoundFile.new;
	file_config.openRead(file_path);

	// declare buffer
	buffer = Buffer.new(server,
		file_config.numFrames,
		file_config.numChannels
	);

	// delcare filter
	filter_def = SynthDef(\filter, {
		arg out, bufnum;
		Out.ar(out, HPF.ar(PlayBuf.ar(file_config.numChannels, bufnum), 440).dup);
	});

	// start score assembly
	score = Score.new;

	// register synth with server
	score.add([ 0.0,
		['/d_recv', filter_def.asBytes]
	]);

	// allocate buffer
	score.add([ 0.0,
		buffer.allocReadMsg(file_path)
	]);

	// create synth without instancin on server
	synth = Synth.basicNew(\filter, server);

	// create synth on server
	score.add([ 0.0,
		synth.newMsg(args: [bufnum: buffer.bufnum])
	]);


	output_path = (pwd +/+ "export" +/+ filename).standardizePath;
	if (File.exists(output_path)) {
		File.delete(output_path);
	};

	condition = Condition.new();

	score.recordNRT(
		outputFilePath: output_path,
		headerFormat: file_config.headerFormat,
		sampleFormat: file_config.sampleFormat,
		options: server.options,
		duration: file_config.duration, // does not actually affect time to finish
		action: {
			if (File.exists(output_path)) {
				"Wrote %".format(output_path).postln;
			} {
				"Failed to write %".format(output_path).postln;
			};

			condition.unhang;
		}
	);

	// wait for rendering to finish, then free resources
	condition.hang;
	synth.free
	buffer.free;

	}
});

server.remove;

/*
var server, server_options, filter_def_id, filter_def, pwd, eps;

server_options = ServerOptions.new;
server_options.threads = 12;
server_options.memSize = 2 * 1024 * 1024; // 2GB
server_options.numOutputBusChannels = 2;
server_options.numInputBusChannels = 0;

server = Server(\nrt, options: server_options);
eps = 0.001;

pwd = thisProcess.nowExecutingPath.dirname;

["meow.wav", "aaaa.wav"].do({ arg filename;
	var file_path, file_config, buffer, score, score_offset, synth, condition, osc_path, output_path;

	file_path = pwd +/+ filename;

	// read config for file metadata
	file_config = SoundFile.new;
	file_config.openRead(file_path);

	buffer = Buffer.new(server,
		file_config.numFrames,
		file_config.numChannels
	);

	score_offset = Pseq.new(Array.series(100, 0, eps)).asStream;

	score = Score.new;

	// register synth with server
	score.add([score_offset.next, ['/d_recv', SynthDef(\filter, {
		arg out, bufnum;
		Out.ar(out, HPF.ar(PlayBuf.ar(2, bufnum), 440).dup);
	}).asBytes]]);

	// allocate buffer
	score.add([score_offset.next, [buffer.allocReadMsg(file_path)]]);

	// create synth without instancin on server
	score.add([score_offset.next, [(synth = Synth.basicNew(\filter, server)).newMsg(args: [bufnum: buffer.bufnum])]]);
	score.add([score_offset.next, [synth.freeMsg]]);

	// render
	osc_path = PathName.tmp +/+ UniqueID.next ++ ".osc";
	output_path = (pwd +/+ "export" +/+ filename).standardizePath;

	if (File.exists(output_path)) {
		File.delete(output_path);
	};

	score.recordNRT(
		oscFilePath: osc_path,
		outputFilePath: output_path,
		headerFormat: file_config.headerFormat,
		sampleFormat: file_config.sampleFormat,
		options: server.options,
		duration: nil,
		action: {
			if (File.exists(output_path)) {
			    "Wrote %".format(output_path).postln;
			} {
				"Failed to write %".format(output_path).postln;
			}
		}
	);

	// cleanup
	File.delete(osc_path);
	file_config.free;
});

//exit(0);
*/