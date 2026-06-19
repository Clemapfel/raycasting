var server = Server.default;

/*
 * include paths in the same folder
 * Usage:
 *     include("foo.scd", "bar.sc").value()
 */
var include = { arg ...paths;
	paths.do { arg path;
		path = path ++ ".scd";
		if (File.exists(path).not) {
			Error("In include: file at % does not exist".format(path.standardizePath()));
		};
		path.loadRelative;
	}
};

// start the server if run from sclang directly
if (server.serverRunning.not) {
	//Server.supernova;
	server.boot;
};

server.doWhenBooted({

	var f;

	"midi.scd".loadRelative;

	~midi_connect_note_pressed.value({ arg note; "note pressed: %".format(note).postln; });
	~midi_connect_note_pressed.value({ arg note; "note released: %".format(note).postln; });

	~midi_connect_pad_released.value({ arg pad; "pad pressed: %".format(pad).postln; });
	~midi_connect_pad_pressed.value({ arg pad; "pad released: %".format(pad).postln; });

	~midi_connect_bend.value({ arg t; "bend: %".format(t).postln; });

	~midi_connect_slider.value({ arg slider_id, slider_value; "slider: % %".format(slider_id, slider_value).postln; });

	~midi_connect_raw.value({ arg id, value; "raw: % %".format(id, value); });

	~midi_connect_tick.value({ arg ...args; args.postln; });

	/*
	~in_prefix  = "C:/Users/cleme/Workspace/raycasting/jtalk/export/mei/angry/";
	~out_prefix = "C:/Users/cleme/Workspace/raycasting/synth/export";

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