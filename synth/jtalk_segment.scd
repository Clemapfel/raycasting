var server, midi;
var paths, import_prefix, genders, emotions, phonemes, postfixes;

server = Server.default;
server.volume = 1.0;
server.options.memSize = 1024 * 1024;

// generate paths
paths = List.new();
import_prefix = thisProcess.nowExecutingPath.dirname +/+ ".." +/+ "jtalk" +/+ "export";
genders = [ "mei" ]; //, "takumi" ];
emotions = [ "normal", "happy", "angry", "sad", "bashful" ];
phonemes = [
    // stops
	"BA", "BAI", "BI", "DA", "GA", "GAU", "KA", "KE", "KI", "PA", "PEI", "PUU", "TA", "TAI", "TE",
    // labiodental fricatives
    "FA", "FAU", "FI", "FOU", "FUU", "VAI", "VE", "VI", "VUU",
    // alveolar fricatives
    "SA", "SAU", "SEI", "SO", "ZA", "ZAU", "ZE", "ZEI",
    // postalveolar fricatives
    "SHA", "SHE", "SHI", "SHUU",

	//"KA", "KEI", "KO",

	//"PA", "PAI", "PEI", "PU", "POU",
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

	// register listener
	var message_name = '/pos';
	var start_id = 0;
	var end_id = 1;
	var listener = OSCdef.new(\listener, { arg message;
		var values = message.drop(3).asInteger;
		var path_id = values.at(0);
        var start_or_end = (values.at(1) == start_id).if("start", "end");
		var sample = values.at(2);

		[path_id, start_or_end, sample].postln;
	}, message_name);

	// registe playback
	filter_def = SynthDef(\filter, { arg out=0, bufnum, path_i;
		var signal = PlayBuf.ar(
			1,
			bufnum,
			rate: BufRateScale.kr(bufnum),
			loop: 0
		);

		// interpolate current buffer position
		var position = Phasor.ar(
			0,
			rate: BufRateScale.kr(bufnum),
			start: 0,
			end: BufFrames.kr(bufnum)
		); // position in frames

		// check for word start
		var start = Onsets.kr(FFT(LocalBuf(2048), signal),
			threshold: 0.1,
			odftype: \power,
			floor: 0.25,
			relaxtime: 0.05
		);

		// check for word end
		var end = Amplitude.ar(signal,
			attackTime: 0.1,
			releaseTime: 0.01
		);

		SendReply.kr(start, message_name,
			values: [path_i, start_id, position]
		);

		SendReply.ar(end, message_name,
			values: [path_i, end_id, position]
		);

		Out.ar(out, signal.dup);
	}).add;

    // main

    play_routine = Routine({
        loop {
			var path_i = paths.size.rand;
			var current_path = paths.at(path_i);
			var buffer = Buffer.read(server, current_path);
            var synth;

            server.sync;

            synth = Synth(\filter, [
					\out, 0,
					\bufnum, buffer.bufnum,
					\path_i, path_i
				]
			);

            "Playing %".format(PathName.new(current_path).fileName).postln;

			(buffer.duration * 1.00).wait;

			synth.free;
            buffer.free;
        }
    }).play;
	CmdPeriod.doOnce({
		midi.free;
		play_routine.stop;
	});
});