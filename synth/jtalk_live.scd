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
    "SA", "SAU", "SEI", "SO", "ZA", "ZAU", "ZE", "ZEI",
    // postalveolar fricatives
    "SHA", "SHE", "SHI", "SHUU",

	"KA", "KEI", "KO",

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

	midi.register_cc(\mix, -1, 1);
	midi.register_cc(\freq, 0, 40);
	midi.register_cc(\normal, -1, 1);

	midi.set_cc(\freq, 1800);

	filter_def = SynthDef(\filter, { arg out=0, bufnum;
		var signal = PlayBuf.ar(
			1,
			bufnum,
			rate: BufRateScale.kr(bufnum),
			loop: 0
		);

		var debug;

		var chain = FFT(LocalBuf(1024), signal);
		var cutoff = 0.08;
		var high_chain = PV_BrickWall(chain, -1 * (1 - cutoff));
		var low_chain = PV_BrickWall(chain, cutoff);

		var fricative_mul = -0.5;
		var onset = Onsets.kr(chain, threshold: 0.7, relaxtime: 0.5);

		var fricative = onset;
		fricative = Decay2.kr(fricative, attackTime: 0.01, decayTime: 0.43);
		signal = XFade2.ar(IFFT(low_chain), IFFT(high_chain), fricative);
		signal = SinOsc.ar(220, mul: fricative);
		//signal = signal + RLPF.ar(signal, rq: 0.18);

		Out.ar(out, signal.dup);
	}).add;

    // main

    play_routine = Routine({
        loop {
            var current_path = paths.choose;
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