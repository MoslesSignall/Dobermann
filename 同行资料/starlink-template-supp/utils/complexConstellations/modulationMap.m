function symModulations = modulationMap(modEst)

nSymbols = size(modEst,1);
nFrames  = size(modEst,2);

% Make a filter to get only QPSK signals.
CQPSK  = genQPSKconst;
% C8PSK  = gen8PSKconst;
C4QAM  = gen4QAMconst;
% C16QAM = gen16QAMconst;
% C32QAM = gen32QAMconst;

Modulation = modEnum();

% Manual fix: frames 1004 and 1005 have 45° misrotation (QPSK <-> 4QAM swapped).
MISROTATED_FRAMES = [1004, 1005];

symModulations = nan(nSymbols, nFrames);
for iFrame = 1:nFrames

    isMisrotated = ismember(iFrame, MISROTATED_FRAMES);

    for iSymbol = 1:nSymbols

        currentSymbolModulation = modEst{iSymbol, iFrame};

        % SSS is QPSK.
        if iSymbol==1
            symModulations(iSymbol, iFrame) = Modulation.QPSK;

        elseif isempty(currentSymbolModulation)
            symModulations(iSymbol, iFrame) = Modulation.Default;
            
        % QPSK/4QAM.
        elseif length(currentSymbolModulation) == 4
            if all(ismember(currentSymbolModulation, CQPSK))
                if isMisrotated
                    symModulations(iSymbol, iFrame) = Modulation.FQAM;  % Swap to 4QAM
                else
                    symModulations(iSymbol, iFrame) = Modulation.QPSK;
                end
            elseif all(ismember(currentSymbolModulation, C4QAM))
                if isMisrotated
                    symModulations(iSymbol, iFrame) = Modulation.QPSK;  % Swap to QPSK
                else
                    symModulations(iSymbol, iFrame) = Modulation.FQAM;
                end
            else
                error('[modulationMap] Modulation is 2 BPS but not QPSK or 4QAM.')
            end

        elseif length(currentSymbolModulation) == 8
            symModulations(iSymbol, iFrame) = Modulation.EPSK;

        elseif length(currentSymbolModulation) == 16
            symModulations(iSymbol, iFrame) = Modulation.STQAM;

        elseif length(currentSymbolModulation) == 32
            symModulations(iSymbol, iFrame) = Modulation.TTQAM;

        else
            symModulations(iSymbol, iFrame) = Modulation.Default;

        end
    end
end

end