AutoRecorder {
	classvar <>headerFormat = "wav";
	classvar <>sampleFormat = "int16";
    classvar <>sampleRate = 48000;

    var <>path;
    var <>defID;
    var <>server;
    var <>recordEndOSC;
    var <>recordEndOSCdef;
    var <>doneCondition;
    var <>buffer;
    var <>synth;

    var <state = \idle;

    *new { arg server;
        ^super.new.init(server);
    }

    init { arg inServer, numChannels = 1;
        var id = UniqueID.next;
        server = inServer;

        doneCondition = Condition.new(true);
        recordEndOSC = ("/recordEnd" ++ id).asSymbol;
        defID = ("autoRecorder_Disk" ++ id).asSymbol;

        SynthDef(defID, { arg bufnum, bus;
            DiskOut.ar(bufnum, In.ar(bus, numChannels));
        }).add;

        recordEndOSCdef = OSCdef(("recordEndOSCdef" ++ id).asSymbol, {
            this.stop();
        }, recordEndOSC);

        ^this;
    }

    record { arg filename, f, bus = 0, numChannels = 1;
        if (f.isKindOf(Function).not && f.respondsTo(\play).not) {
            Error("In AutoRecorder.record: argument #2 is not callable").throw
        };

        if (filename.isKindOf(PathName)) {
            filename = filename.fullPath
        };

        if (state != \idle) {
            "AutoRecorder is currently busy. Skipping.".warn;
            ^this;
        };

        state = \recording;
        doneCondition.test = false;

        fork {
            buffer = Buffer.alloc(server,
                sampleRate.nextPowerOfTwo,
                numChannels
            );

            server.sync;

            buffer.write(filename, headerFormat, sampleFormat,
                0, 0, true // disk out config
            );

            server.sync;

            synth = Synth.tail(server.defaultGroup, defID, [
                \bufnum, buffer,
                \bus, bus
            ]);

            path = PathName.new(filename);
            "In AutoRecorder: recording `%` to `%`".format(
                path.fileNameWithoutExtension,
                path.fullPath
            ).postln;

            if (f.isKindOf(Function)) {
                f.value;
            } {
                f.play;
            }
        }

        ^this;
    }

    stop {
        if (state != \recording) { ^this };
        state = \stopping;

        if (buffer.notNil) {
            var bufToClose = buffer;
            buffer = nil; // clear immediately to prevent UI race conditions

            bufToClose.close({ arg buf;
                buf.free;
                state = \idle;
                doneCondition.test = true;
                doneCondition.unhang;

                "In AutoRecorder: finished  `%` to `%`".format(
                    path.fileNameWithoutExtension,
                    path.fullPath
                ).postln;
            });
        } {
            state = \idle;
			"called".postln;
            doneCondition.test = true;
            doneCondition.unhang;
        };

        if (synth.notNil) {
            synth.free;
            synth = nil;
        };
    }

    ar { arg signal, doneAction = 0;
        ^SendReply.ar(DetectSilence.ar(signal, doneAction: doneAction), recordEndOSC);
    }

    kr { arg signal, doneAction = 0;
        ^SendReply.kr(DetectSilence.kr(signal, doneAction: doneAction), recordEndOSC);
    }

    hang {
        doneCondition.hang;
    }

    free {
        if (recordEndOSCdef.notNil) { recordEndOSCdef.free; };
        if (buffer.notNil) { buffer.free; };
    }
}