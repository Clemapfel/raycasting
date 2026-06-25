var before = Date.new.rawSeconds;
var server_options, server, import_prefix, genders, emotions, to_iterate;

server_options = ServerOptions.new;
server_options.threads = 12;
server_options.memSize = 1024 * 1024; // gb
server_options.numOutputBusChannels = 1;
server_options.numInputBusChannels = 2;

fork {

~export_prefix = thisProcess.nowExecutingPath.dirname +/+ "export";
~import_prefix = thisProcess.nowExecutingPath.dirname +/+ ".." +/+ "jtalk" +/+ "export";
~genders = [ "mei" ]; //, "takumi" ];
~emotions = [ "normal" ]; //, "happy", "angry", "sad", "bashful" ];

~wait_to_finish_condition = Condition.new();

~process_all = {
    if (File.exists(~export_prefix).not) {
        File.mkdir(~export_prefix);
	};

	~genders.do({ arg gender;
		var gender_dir = PathName.new(~export_prefix +/+ gender);

		if (gender_dir.isFolder.not) {
			File.mkdir(gender_dir.fullPath);
		};

		~emotions.do({ arg emotion;
			var emotion_dir = PathName.new(~export_prefix +/+ gender +/+ emotion);
			var path = PathName.new(~import_prefix +/+ gender +/+ emotion);

			if (emotion_dir.isFolder.not) {
				File.mkdir(emotion_dir.fullPath);
			};

			if (path.isFolder) {
				path.files.do({ arg file;
					if (file.isFile) {
						~process.(file.fileName, gender, emotion);
					};
				});
			};
		});
	});

	~wait_to_finish_condition.unhang;
};


~process = { arg filename, gender, emotion;

	var import_path, export_path, file_config, buffer, filter_def, filter, score, condition;

	import_path = PathName.new(~import_prefix +/+ gender +/+ emotion +/+ filename);
	export_path = PathName.new(~export_prefix +/+ gender +/+ emotion +/+ filename);

	if (export_path.isFile) {
		File.delete(export_path);
	};

	if (import_path.isFile) {
			server = Server(("rt_" ++ UniqueID.next).asSymbol, options: server_options);

		// read config for file metadata
		file_config = SoundFile.new;
		file_config.openRead(import_path.fullPath);

		// declare buffer
		buffer = Buffer.new(server,
			file_config.numFrames,
			file_config.numChannels
		);

	    // declare filter
	    filter_def = SynthDef(\filter, {
	        arg out, bufnum;
	        Out.ar(out, HPF.ar(PlayBuf.ar(file_config.numChannels, bufnum), 440));
        });

		// start score assembly
		score = Score.new;

		// register synth with server
		score.add([ 0.0,
			['/d_recv', filter_def.asBytes]
		]);

		// allocate buffer
		score.add([ 0.0,
			buffer.allocReadMsg(import_path.fullPath)
		]);

		// create synth without instancin on server
		filter = Synth.basicNew(\filter, server);

		// create synth on server
		score.add([ 0.0,
			filter.newMsg(args: [bufnum: buffer.bufnum])
		]);

		fork {
			condition = Condition.new();

				/*
			score.recordNRT(
				outputFilePath: export_path,
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
			*/

			// wait for rendering to finish, then free resources
			condition.hang;
			filter.free;
			buffer.free;

			export_path.postln;
		}
	};
};

~process_all.();
~wait_to_finish_condition.hang;
~server.free;
"done, took % seconds".format(Date.new.rawSeconds - before).postln;
}
