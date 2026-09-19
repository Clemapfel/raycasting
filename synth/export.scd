// copy folder structure of `synth/export` to `assets/sounds`
// convert any .wav file to .ogg

var server = Server.default;

var inPath = PathName(thisProcess.nowExecutingPath.dirname +/+ "export");
var outPath = PathName(thisProcess.nowExecutingPath.dirname +/+ ".." +/+ "assets" +/+ "sounds");

var inHeaderFormat = AutoRecorder.headerFormat;
var inSampleFormat = AutoRecorder.sampleFormat;
var inExtension = "wav";

var outHeaderFormat = "OGG";
var outSampleFormat = "vorbis";
var outExtension = "ogg";

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
        var toPath = targetPath.replace(inExtension, outExtension);
		if (fromPath.endsWith(inHeaderFormat)) {
            convertJobs.add((in: fromPath, out: toPath));
        };
    };
};

server.waitForBoot {
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

	convertJobs.do { |job|
        var buffer = Buffer.read(server, job.in);
		buffer.write(job.out, headerFormat: outHeaderFormat, sampleFormat: outSampleFormat);
		"In export.scd: converted `%` -> `%`".format(
			job.in.drop(inPath.fullPath.size + 1),
			job.out.drop(outPath.fullPath.size + 1)
		).postln;
	};
};

Date.getDate;
