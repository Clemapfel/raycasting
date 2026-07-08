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
    //BA", "BAI", "BI", "DA", "GA", "GAU", "KA", "KE", "KI", "PA", "PEI", "PUU", "TA", "TAI", "TE",
    // labiodental fricatives
    //"FA", "FAU", "FI", "FOU", "FUU", "VAI", "VE", "VI", "VUU",
    // alveolar fricatives
    //"SA", "SAU", "SEI", "SO", "ZA", "ZAU", "ZE", "ZEI",
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

	var midi = MIDIInterface.new(server);

	midi.register_cc(\freq, 0, 12000);
	midi.register_cc(\2, -1, 1);


	midi.set_cc(\freq, 8000);

	filter_def = SynthDef(\filter, { arg out=0, bufnum;
		var signal = PlayBuf.ar(
			1,
			bufnum,
			rate: BufRateScale.kr(bufnum),
			loop: 0
		);

		var freq = midi.get_cc(\freq);
		var composite;

		var n = 2.pow(12);
		var esses = FFT(LocalBuf(n), signal, wintype: 1);
		var rest = FFT(LocalBuf(n), signal, wintype: 1);
		var w = (freq / (48000 / 2));

		// isolate esses
		esses = PV_Cutoff(esses, w);
		rest = PV_MagMinus(rest, esses);

		composite = IFFT(rest);

		Out.ar(out, XFade2.ar(composite, signal, midi.get_cc(\2)).dup);
	}).add;



    // main

    play_routine = Routine({
        loop {
            var current_path = paths.choose;
			var buffer = Buffer.read(server, current_path);
            var synth;

            server.sync;

			5.do({
            synth = Synth(\filter, [\out, 0, \bufnum, buffer.bufnum]);

            "Playing %".format(PathName.new(current_path).fileName).postln;

			(buffer.duration * 1.25).wait;
							synth.free;
			});

            buffer.free;
        }
    }).play;

	CmdPeriod.doOnce({
		midi.free;
		play_routine.stop;
	});
});