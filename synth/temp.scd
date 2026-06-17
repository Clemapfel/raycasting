var server = Server.default;/*Server(\nrt,
    options: ServerOptions.new
	   .numOutputBusChannels_(2)
       .numInputBusChannels_(2)
);*/

if (server.serverRunning.not) {
    //Server.supernova;
    server.boot;
} {
    // else noop
};

"===============================".postln;

~in_prefix = "C:/Users/cleme/Workspace/raycasting/jtalk/export/mei/angry/";
~out_prefix  = "C:/Users/cleme/Workspace/raycasting/synth/export";
~do_export = false;

server.dumpOSC(1);

server.doWhenBooted({
	var process, process_name, score, call_signature,
	    filename, in_file, buffer
	;

	filename = "A_long.wav";
	in_file = ~in_prefix +/+ filename;

	buffer = Buffer.read(server, in_file);

	process_name = \Process;
	process = SynthDef(process_name, { arg out, buffer_id;
        var player_buffer = PlayBuf.ar(
            1, // n channels
            buffer_id,
            BufRateScale.kr(buffer_id),
            doneAction: Done.freeSelf
        );

        var pan = Pan2.ar(player_buffer, 0);
		var lpf = RLPF.ar(pan, 800.0);
        Out.ar(out, lpf);
    });

	call_signature = [
        \out, 0,
        \buffer_id, buffer
    ];

	process.play(Server.default, call_signature);


	score = Score.new();

	// https://doc.sccode.org/Reference/Server-Command-Reference.html

	// allocate buffer
	score.add(0.0, [\b_allocRead, 0,
		in_file,  // filename
		0,  // start frame index
		0   // number of frames to read
	]);

	// wait for buffer to load
	score.add(0.0, [\sync]);

	// allocate synth def
	score.add(0.0, [\d_recv, process]);
	score.add(0.0, [\d_]

	// init file names and output folder


	/*
	if (~do_export) {

		var in_file, out_file,
		    in_path, out_path
		;

		in_path = (~in_prefix +/+ filename).standardizePath();
		out_path = (~out_prefix +/+ filename).standardizePath();

		if (File.exists(~out_prefix).not) {
			if (File.mkdir(~out_prefix).not) {
				Error("Unable to create directory at %".format(~out_prefix));
			};
		};

		in_file = SoundFile.new();
		if (in_file.openRead(in_path).not) {
			Error("Unable to open file at % for reading".format(in_path));
		};

		out_file = SoundFile.new();
		if (out_file.openWrite(out_path).not) {
			Error("Unable to open file at % for writing".format(in_path));
		};



		out_file.close;
		in_file.close;

		if (File.exists(out_path)) {
			("succesfully wrote file to %").format(out_path).postln;
		};
	}
	*/
});