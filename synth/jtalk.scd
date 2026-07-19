(
var before = Date.new.rawSeconds;
var server_options, import_prefix, export_prefix, genders, emotions;
var files_to_process = List.new;
var max_concurrent_jobs = 12; // Aligned with your thread count
var semaphore = Semaphore(max_concurrent_jobs);
var wait_to_finish_condition = Condition.new;
var completed_count = 0;

var fft_size = 2.pow(12);

export_prefix = thisProcess.nowExecutingPath.dirname +/+ "export";
import_prefix = thisProcess.nowExecutingPath.dirname +/+ ".." +/+ "jtalk" +/+ "export";
genders = [ "mei" ]; //, "takumi" ];
emotions = [ "normal" ]; //, "happy", "angry", "sad", "bashful" ];

SynthDef(\filter, { arg out=0, bufnum;
	var signal = PlayBuf.ar(
		1,
		bufnum,
		rate: BufRateScale.kr(bufnum),
		loop: 0
	);

	var pitch = Pitch.kr(signal, median: 25);
	var freq = 8000;
	var composite;

	var esses = FFT(LocalBuf(fft_size), signal, wintype: 1);
	var rest = FFT(LocalBuf(fft_size), signal, wintype: 1);
	var w = (freq / (48000 / 2));

	// isolate esses
	esses = PV_Cutoff(esses, w);
	rest = PV_MagMinus(rest, esses);

	composite = IFFT(PV_MagSmooth(rest, factor: 0.1));
	composite = BPeakEQ.ar(composite, freq: pitch, rq: 0.95, db: 5);

	Out.ar(out, composite);
}).writeDefFile;

if (File.exists(export_prefix).not) { File.mkdir(export_prefix); };

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
                    files_to_process.add((
                        in: file.fullPath.standardizePath,
						out: (emotion_dir +/+ file.fileName).standardizePath
                    ));
                };
            });
        };
    });
});

"Found % files to process. Starting render pool...".format(files_to_process.size).postln;

fork {
    files_to_process.do({ arg job;

        semaphore.wait;

        fork {
			var file_config = SoundFile.new;
			var score;
			var fft_latency = fft_size / file_config.sampleRate;
			var osc_file_path;

			if (completed_count < 5 && file_config.openRead(job.in)) {
				server_options = ServerOptions.new;
				server_options.numOutputBusChannels = 1;
				server_options.numInputBusChannels = 1;
				server_options.memSize = 8192;
				server_options.verbosity = -1;

				score = Score.new;
				score.add([ 0.0, [\b_allocRead, 0, job.in] ]);
				score.add([ 0.0, [\s_new, \filter, 1000, 0, 0, \bufnum, 0] ]);

				osc_file_path = PathName.tmp;
				score.recordNRT(
					outputFilePath: job.out,
					headerFormat: file_config.headerFormat,
					sampleFormat: file_config.sampleFormat,
					oscFilePath: osc_file_path,
					options: server_options,
					duration: file_config.duration + fft_latency,
					action: {
						file_config.close;
						File.delete(osc_file_path);
						completed_count = completed_count + 1;
						"Processed % / % files".format(completed_count, files_to_process.size).postln;
						semaphore.signal;
						if (completed_count == files_to_process.size) {
							wait_to_finish_condition.unhang;
						};
					}
				);
			} {
				completed_count = completed_count + 1;
				semaphore.signal;
				if (completed_count == files_to_process.size) {
					wait_to_finish_condition.unhang;
				};
			};
		};
    });

    if (files_to_process.size > 0) {
        wait_to_finish_condition.hang;
        "Done. Took % seconds".format(Date.new.rawSeconds - before).postln;
    } {
        "No files to process.".postln;
    };
};
)