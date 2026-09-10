ClipDetector {
    classvar <oscPath = '/clip_detector_print_warning';

    *initClass {
        OSCdef(\clipDetectorListener, { |msg|
            var nodeID = msg[1];
            var busOrID = msg[3];
            var peakValue = msg[4];
			var threshold = msg[5];

			"In ClipDetector: bus % : %".format(
                busOrID.asInteger,
                peakValue
            ).warn;
        }, ClipDetector.oscPath).permanent_(true);
    }

    *ar { arg signal, threshold = 1.0, reset = 2.0, busOrID = 0, oscID = -1;
        ^this.prMakeDetector(signal, busOrID, oscID, \ar, threshold, reset);
    }

    *kr { arg signal, threshold = 1.0, reset = 2.0, busOrID = 0, oscID = -1;
        ^this.prMakeDetector(signal, busOrID, oscID, \kr, threshold, reset);
    }

    *prMakeDetector { arg signal, busOrID, oscID, rate, threshold, reset;
        var absSig, reduced, runningMax, trigger;

        absSig = signal.asArray.abs;
        reduced = absSig.reduce('max');

        runningMax = RunningMax.perform(rate, reduced, DetectSilence.perform(rate,
			in: reduced,
			time: reset
		));
        trigger = (HPZ1.perform(rate, runningMax) > 0) * (runningMax >= threshold);

        SendReply.perform(
            rate,
            trigger,
            oscPath,
            [ busOrID, runningMax, threshold ],
            oscID
        );
    }
}