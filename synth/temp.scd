var server = Server.default;

if (server.serverRunning.not) {
    //Server.supernova;
    server.boot;
} {
    // else noop
};

"===============================".postln;

~in_prefix = "C:/Users/cleme/Workspace/raycasting/jtalk/export/mei/angry/";
~out_prefix  = "C:/Users/cleme/Workspace/raycasting/synth/export";

server.doWhenBooted({

	var process, process_name, score, call_signature,
	    filename, in_file, buffer
	;

	MIDIClient.init;
	MIDIIn.connectAll;

	MIDIFunc.noteOff({ arg vel, n, chan, src;
		"Off : %".format(n).postln;
	});

	MIDIFunc.noteOn({ arg vel, n, chan, src;
		"On  : %".format(n).postln;
	});

	MIDIFunc.cc({ arg val, num, chan, src;
		"CC  : % val: %".format(num, val).postln;
	});

	MIDIFunc.bend({ arg val, chan, src;
		"Bend: % chan: %".format(val, chan).postln;
	});

	MIDIFunc.touch({ arg val, chan, src;
		"Touch chan: % val: %".format(chan, val).postln;
	});

	MIDIFunc.polytouch({ arg val, n, chan, src;
		"Poly: % note: %".format(val, n).postln;
	});

	MIDIFunc.program({ arg val, chan, src;
		"Prog: % chan: %".format(val, chan).postln;
	});
})

	/*
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
	+/

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