// copy folder structure of `synth/export` to `assets/sounds`
// convert any .wav file to .ogg

var server = Server.default;

var inPath = PathName(thisProcess.nowExecutingPath.dirname +/+ "export");
var outPath = PathName(thisProcess.nowExecutingPath.dirname +/+ ".." +/+ "assets" +/+ "sounds");

var inHeaderFormat = AutoRecorder.headerFormat;
var inExtension = "wav";

var outHeaderFormat = "OGG"; //"WAV";
var outSampleFormat = "vorbis"; //"int16";
var outExtension = "ogg"; //"wav";

var tempPrefix = "tmp";

var useExternal = true;  // use ffmpeg for conversion
var useThreading = false; // `false` results in nicer tty output
var vorbisQuality = 7; // 1 - 10

var mkdirJobs = List.new();
var convertJobs = List.new();

var export = { |pathname|
    var relativePath = pathname.fullPath.drop(inPath.fullPath.size);
    var targetPath = outPath.fullPath ++ relativePath;

	if (pathname.isFolder) {
		mkdirJobs.add((path: targetPath, relativePath: relativePath));
        pathname.entries.do { |sub|
            export.(sub);
        };
    } {
        var fromPath = pathname.fullPath;
		var toPath = targetPath.replace("." ++ inExtension, "." ++ outExtension);
		if (fromPath.endsWith(inExtension)) {
            convertJobs.add((in: fromPath, out: toPath));
        };
    };
};

server.waitForBoot {
	var before = Main.elapsedTime;

	var condition = Condition.new(false);
	var chunkSize = 2**27; // ~64 mb
	var semaphore = Semaphore.new(1024 / 64); // ~1gb peak ram usage
	var convertJobsDone = 0;
	var messages = [];

	var log = { |string, isWarning = false|
		if (useThreading.not) {
			if (isWarning) { ("\n" ++ string).warn } { ("\n" ++ string).postln };
		} {
			messages = messages.add(string -> isWarning);
		}
	};

	inPath.entries.do { |sub|
		export.(sub);
	};

	mkdirJobs.do { |job|
		var print = job.relativePath.keep(job.relativePath.size - 1);
		if (File.exists(job.path)) {
			File.deleteAll(job.path);
			log.("In export.scd: rmdir `%`".format(print));
		};

		File.mkdir(job.path);
		log.("In export.scd: mkdir `%`".format(print));
	};

	convertJobs = convertJobs.reject({ |job| job.in.beginsWith(tempPrefix) });
	condition.test = convertJobsDone >= convertJobs.size;

	convertJobs.do { |job|
		fork {
			var tempPath;

			protect {
				try {
					var file = SoundFile.new;
					var pathname = PathName.new(job.in);
					var valid = false;

					try {
						if (file.openRead(job.in).not) {
							Error("In export.scd: file at `%` cannot be opened".format(job.in)).throw;
						};

						if (file.numFrames == 0 or: { file.numChannels == 0 }) {
							Error("In export.scd: file at `%` contains only silence".format(job.in)).throw;
						};
					} {
						file.close;
					};

					if (pathname.fileName.beginsWith(tempPrefix)) {
						log.("In export.scd: skipping `%`".format(pathname.fileName));
					} {
						log.("In export.scd: converting `%` -> `%`".format(
							job.in.drop(inPath.fullPath.size + 1),
							job.out.drop(outPath.fullPath.size + 1)
						));

						if (useExternal.not) {
							SoundFile.normalize(
								job.in, job.out,
								outHeaderFormat, outSampleFormat,
								chunkSize: chunkSize,
								threaded: useThreading
							);
						} {
							var finished = Condition.new(false);
							var exitCode = nil;

							var cmd;

							tempPath = Platform.defaultTempDir +/+ "%_%.%".format(
								tempPrefix, UniqueID.next, inExtension
							);

							// normalize using SC first
							SoundFile.normalize(
								job.in, tempPath,
								chunkSize: chunkSize,
								threaded: false
							);

							// then convert using ffmpeg
							cmd = "ffmpeg -nostdin -y -i % -c:a libvorbis -q:a % %".format(
								tempPath.quote,
								vorbisQuality,
								job.out.quote
							);

							cmd.unixCmd({ |res|
								exitCode = res;
								finished.test = true;
								finished.signal;
							}, false);

							finished.wait;

							if (exitCode != 0) {
								log.("In export.scd: command failed (exit %): %".format(exitCode, cmd), true);
							};
						}
					}
				} { |error|
					log.("In export.scd: %".format(error.errorString), \warn);
				};
			} {
				semaphore.signal;

				if (tempPath.notNil and: { File.exists(tempPath) }) {
					File.delete(tempPath);
					tempPath = nil;
				};

				convertJobsDone = convertJobsDone + 1;
				condition.test = convertJobsDone >= convertJobs.size;
				condition.signal;
			};
		};
	};

	condition.wait;

	server.sync;
	log.("done. Took %s".format((Main.elapsedTime - before).round(0.01)));

	if (useThreading) {
	    messages.do { |assoc|
		    if (assoc.value) { assoc.key.warn } { assoc.key.postln };
	    };
	};
};