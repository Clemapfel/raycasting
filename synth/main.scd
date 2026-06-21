var server = Server.default;
var fader_handler, note_handler;

server.options.memSize = 65536;

if (server.serverRunning.not) {
    server.boot;
};

server.waitForBoot({
	var mapping;
    var path = thisProcess.nowExecutingPath;
    var dir = if(path.notNil) { path.dirname } { "" };
    var buffer = Buffer.read(server, dir +/+ "test.mp3");

    var bend_bus = Bus.control(server, 1);
    bend_bus.set(1.0);

	mapping = MIDIMapping.new;

    server.sync;

    SynthDef(\meow, { arg out = 0, bufnum = 0, pitch = 440, bend = 1.0;
        var reference_pitch = 440;

        var source = PlayBuf.ar(2, bufnum,
            loop: 1,
            doneAction: 2
        );

        var shifted = PitchShift.ar(source, 0.2, (pitch / reference_pitch) * bend);
        Out.ar(out, shifted);
    }).add;

    note_handler = MIDIMapping.connect_note_pressed({ arg note_id, hertz;
        Synth(\meow, [
            \bufnum, buffer,
            \pitch, hertz,
            \bend, bend_bus.asMap
        ]);
    });

    fader_handler = MIDIMapping.connect_bend({ arg id, t;
        var current_bend = t.linlin(-1, 1, 0.5, 2.0);
        bend_bus.set(current_bend);
    });

	MIDIMapping.connect_pad_pressed({ arg id;
		if (id == \PAD_01) {
		server.record();
		} {
			if (id == \PAD_02) {
				server.stopRecording();
			};
		};
	});

	server.sync;

	MIDIMapping.free;
});
