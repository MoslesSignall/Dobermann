function C = gen4QAMconst()

spacing = [-1 1];

% Generate all possible combinations with given spacing.
[realComps, imagComps] = meshgrid(spacing, spacing*1j);
C = realComps+imagComps;
C = C(:);

% Normalize power 
C = C/sqrt(max(conj(C).*C));
assert(abs(max(conj(C).*C)-1) < 1e-10);

end