(
var before = Date.new.rawSeconds;
var server_options, import_prefix, export_prefix, genders, emotions;
var files_to_process = List.new;
var max_concurrent_jobs = 12; // Aligned with your thread count
var semaphore = Semaphore(max_concurrent_jobs);
var wait_to_finish_condition = Condition.new;
var completed_count = 0;

export_prefix = thisProcess.nowExecutingPath.dirname +/+ "export";
import_prefix = thisProcess.nowExecutingPath.dirname +/+ ".." +/+ "jtalk" +/+ "export";
genders = [ "mei" ]; //, "takumi" ];
emotions = [ "normal" ]; //, "happy", "angry", "sad", "bashful" ];

// 1. Build and save the SynthDef globally ONCE.
// NRT servers read SynthDefs from the synthdefs/ directory.
SynthDef(\jtalk_filter, { arg out=0, bufnum;
    var sig = PlayBuf.ar(1, bufnum); // Assuming mono input based on your original bus channel setup
    Out.ar(out, HPF.ar(sig, 440));
}).writeDefFile;


// 2. Discovery Phase: Collect all jobs synchronously
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
                        in: file.fullPath,
                        out: emotion_dir +/+ file.fileName
                    ));
                };
            });
        };
    });
});

"Found % files to process. Starting render pool...".format(files_to_process.size).postln;

// 3. Render Phase: Controlled Worker Pool
fork {
    files_to_process.do({ arg job;

        // This halts the loop if 12 jobs are currently running
        semaphore.wait;
c
        fork {
            var file_config = SoundFile.new;
            var score;

            if (file_config.openRead(job.in)) {
                // Keep options scoped to the NRT instance
                server_options = ServerOptions.new;
                server_options.numOutputBusChannels = 1;
                server_options.numInputBusChannels = 1;
                // Drastically reduced memSize: a simple HPF NRT needs minimal memory.
                // 1024*1024 per thread will crash your RAM on large batches.
                server_options.memSize = 8192;

                score = Score.new;

                // Construct the score using basic OSC messaging
                score.add([ 0.0, [\b_allocRead, 0, job.in] ]);
                score.add([ 0.0, [\s_new, \jtalk_filter, 1000, 0, 0, \bufnum, 0] ]);
                score.add([ file_config.duration, [\c_set, 0, 0] ]); // Dummy command to pad the end duration

                score.recordNRT(
                    outputFilePath: job.out,
                    headerFormat: file_config.headerFormat,
                    sampleFormat: file_config.sampleFormat,
                    options: server_options,
                    duration: file_config.duration,
                    action: {
                        file_config.close;
                        completed_count = completed_count + 1;

                        if (completed_count % 100 == 0) {
                            "Processed % / % files...".format(completed_count, files_to_process.size).postln;
                        };

                        // Signal the semaphore to release the slot for the next file
                        semaphore.signal;

                        if (completed_count == files_to_process.size) {
                            wait_to_finish_condition.unhang;
                        };
                    }
                );
            } {
                "Failed to read metadata for %".format(job.in).postln;
                completed_count = completed_count + 1;
                semaphore.signal; // Ensure slot releases even on failure
                if (completed_count == files_to_process.size) { wait_to_finish_condition.unhang; };
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