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
    // "BA", "BAI", "BI", "DA", "GA", "GAU", "KA", "KE", "KI", "PA", "PEI", "PUU", "TA", "TAI", "TE",
    // labiodental fricatives
    //"FA", "FAU", "FI", "FOU", "FUU", "VAI", "VE", "VI", "VUU",
    // alveolar fricatives
    //"SA", "SAU", "SEI", "SO", "ZA", "ZAU", "ZE", "ZEI",
    // postalveolar fricatives
    "SHA", "SHE", "SHI", "SHUU",
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

	midi.register_cc(\freq, 20, 16000);

    filter_def = SynthDef(\filter, { arg out, bufnum;
		var signal, chain, low, high, composite;
		var base_amplitude, composite_amplitude;
		var onset, debug, gain, bias;

		signal = PlayBuf.ar(
			1,
			bufnum,
			rate: BufRateScale.kr(bufnum),
			loop: 0,
			doneAction: Done.freeSelf
		);
		chain = FFT(LocalBuf(1024), signal);

		onset = Onsets.kr(chain, odftype: \rcomplex, threshold: 0.55);
		onset = Decay2.kr(onset, attackTime: 0.02, decayTime: 0.2);

		debug = SinOsc.ar(onset.linlin(0, 1, 220, 880), 0.0, mul: onset);

		chain = PV_MagSmooth(chain, 0.35);
		signal = IFFT(chain);

		low = RLPF.ar(signal, 440, 0.4);

		bias = 0;
		composite = LinXFade2.ar(signal, low, onset.linlin(0, 1, -1, 1 - bias));

		Out.ar(out, (composite + debug).dup);
	}).add;

    // main

    play_routine = Routine({
        loop {
            var current_path = paths.choose;
            var buffer = Buffer.read(server, current_path);

            server.sync;
            Synth(\filter, [\out, 0, \bufnum, buffer.bufnum]);

            "Playing %".format(PathName.new(current_path).fileName).postln;

			buffer.duration.wait;
            buffer.free;
        }
    }).play;

	CmdPeriod.doOnce({
		midi.free;
		play_routine.stop;
	});
});