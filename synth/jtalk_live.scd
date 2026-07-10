var server, midi;
var paths, import_prefix, genders, emotions, phonemes, postfixes;

var qitch_buffer;
var fft_buffer_size = 4096;
var sample_rate = 48000;

server = Server.default;
server.options.sampleRate = sample_rate;
server.volume = 1.0;
server.options.memSize = 1024 * 1024;

qitch_buffer = Buffer.read(server, (Platform.systemExtensionDir +/+ "SC3plugins/PitchDetection/extraqitchfiles/QspeckernN" ++ fft_buffer_size ++ "SR" ++ sample_rate ++ ".wav").standardizePath);

~collectFilesToProcess = { arg genders, emotions;
	var export_prefix = thisProcess.nowExecutingPath.dirname +/+ "export";
	var import_prefix = thisProcess.nowExecutingPath.dirname +/+ ".." +/+ "jtalk" +/+ "export";

	var files = List.new;

	genders.do({ arg gender;
		var gender_dir = export_prefix +/+ gender;
		if (File.exists(gender_dir).not) { File.mkdir(gender_dir); };

		emotions.do({ arg emotion;
			var emotion_dir = gender_dir +/+ emotion;
			var in_path = PathName.new(import_prefix +/+ gender +/+ emotion);

			if (File.exists(emotion_dir).not) { File.mkdir(emotion_dir); };

			if (in_path.isFolder) {
				in_path.files.do({ arg file;
					if (file.isFile) {
						files.add((
							in: file.fullPath.standardizePath,
							out: (emotion_dir +/+ file.fileName).standardizePath
						));
					};
				});
			};
		});
	});

	files;
};

paths = ~collectFilesToProcess.(
	[ "mei" ], //, "takumi" ];
	[ "normal" ] //, "happy", "angry", "sad", "bashful" ];
);

thisThread.randSeed = Date.new.rawSeconds;

server.waitForBoot({
    var filter_def, play_routine;
    var file_config, sample_path;

	var midi = MIDIInterface.new(server);
	var message_name = '/pos';

	midi.register_cc(\freq, 0, 12000);
	midi.register_cc(\2, -1, 1, slider: midi.pads.next);

	midi.set_cc(\freq, 5000);
	midi.set_cc(\2, -1);

	// https://www.youtube.com/watch?v=_NED_v716U4

	filter_def = SynthDef(\filter, { arg out=0, bufnum;
    var signal = PlayBuf.ar(
        1,
        bufnum,
        rate: BufRateScale.kr(bufnum),
        loop: 0
    );
    var freq = midi.get_cc(\freq);
    var pitch = Pitch.kr(signal, median: 30);

    signal = BPeakEQ.ar(signal, freq: pitch, rq: 0.95, db: 0);
    Out.ar(out, signal.dup);
}).add;

    // main

    play_routine = Routine({
        loop {
            var current_path = paths.choose.in;
			var buffer = Buffer.read(server, current_path);
            var synth;

            server.sync;

            synth = Synth(\filter, [\out, 0, \bufnum, buffer.bufnum]);

            "Playing %".format(PathName.new(current_path).fileName).postln;
			(buffer.duration * 1.25).wait;

            synth.free;
            buffer.free;
        }
    }).play;

	CmdPeriod.doOnce({
		midi.free;
		play_routine.stop;
	});
});