function [Modulation, modNames, modValues] = modEnum()

Modulation.QPSK    = 0;
Modulation.FQAM    = 1;
Modulation.EPSK    = 2;
Modulation.STQAM   = 3;
Modulation.TTQAM   = 4;
Modulation.Default = NaN;

modValues = struct2array(Modulation);
modValues = modValues(~isnan(modValues));

modNames = {'QPSK'
            '4QAM'
            '8PSK'
            '16QAM'
            '32QAM'};

end