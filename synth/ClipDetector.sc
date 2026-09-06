ClipDetector {
    classvar <oscPath = '/clip_detector_print_warning';

    *initClass {
        OSCdef(\clipDetectorListener, { |msg|
            var nodeID = msg[1];
            var busOrID = msg[3];
            var peakValue = msg[4];

            "In ClipDetector: clipping detected on bus %: %".format(
                busOrID.asInteger,
                peakValue
            ).warn;

        }, ClipDetector.oscPath).permanent_(true);
    }

    *ar { arg signal, busOrID = 0, oscID = -1;
        ^this.prMakeDetector(signal, busOrID, oscID, \ar);
    }

    *kr { arg signal, busOrID = 0, oscID = -1;
        ^this.prMakeDetector(signal, busOrID, oscID, \kr);
    }

    *prMakeDetector { arg signal, busOrID, oscID, rate;
        var absSig, reduced, runningMax, trigger;

        absSig = signal.asArray.abs;
        reduced = absSig.reduce('max');

        runningMax = RunningMax.perform(rate, reduced, DetectSilence.perform(rate, reduced));
        trigger = (HPZ1.perform(rate, runningMax) > 0) * (runningMax >= 1.0);

        SendReply.perform(
            rate,
            trigger,
            oscPath,
            [ busOrID, runningMax ],
            oscID
        );
    }
}