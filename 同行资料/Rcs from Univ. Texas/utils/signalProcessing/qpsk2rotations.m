function rotations = qpsk2rotations(qpsk)

phase = angle(qpsk);
rotations = round(phase/(pi/2));
rotations = mod(rotations,4);

end