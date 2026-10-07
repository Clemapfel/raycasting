// copy folder structure of `synth/export` to `assets/sounds`
// convert any .wav file to .ogg

var server = Server.default;

var inPath = PathName(thisProcess.nowExecutingPath.dirname +/+ "export");
var outPath = PathName(thisProcess.nowExecutingPath.dirname +/+ ".." +/+ "assets" +/+ "sounds");

var inHeaderFormat = AutoRecorder.headerFormat;
var inExtension = "wav";

var outHeaderFormat = "OGG";
var outSampleFormat = "vorbis";
var outExtension = "ogg";

var tempPrefix = "tmp";

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
	var semaphore = Semaphore.new(1);
	var convertJobsDone = 0;

	inPath.entries.do { |sub|
		export.(sub);
	};

	mkdirJobs.do { |job|
		var print = job.relativePath.keep(job.relativePath.size - 1);
		if (File.exists(job.path)) {
			File.deleteAll(job.path);
			"In export.scd: rmdir `%`".format(print).postln;
		};

		File.mkdir(job.path);
		"In export.scd: mkdir `%`".format(print).postln;
	};

	convertJobs = convertJobs.reject({ |job| job.in.beginsWith(tempPrefix) });
	condition.test = convertJobsDone >= convertJobs.size;

	convertJobs.do { |job|
		fork {
			var buffer;

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
						"In export.scd: skipping `%`".format(pathname.fileName).postln;
					} {
						buffer = Buffer.read(server, job.in);
						server.sync;
						buffer.write(job.out, headerFormat: outHeaderFormat, sampleFormat: outSampleFormat);
						server.sync;

						"In export.scd: converted `%` -> `%`".format(
							job.in.drop(inPath.fullPath.size + 1),
							job.out.drop(outPath.fullPath.size + 1)
						).postln;
					}
				} { |error|
					"In export.scd: %".format(error.errorString).warn;
				};
			} {
				if (buffer.notNil) { buffer.free; buffer = nil };

				semaphore.signal;

				convertJobsDone = convertJobsDone + 1;
				condition.test = convertJobsDone >= convertJobs.size;
				condition.signal;
			};
		};
	};

	condition.wait;
	"done. Took %s".format((Main.elapsedTime - before).round(0.01)).postln;
};