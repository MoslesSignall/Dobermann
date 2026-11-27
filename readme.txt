======Version: 1.0.0.a1, Add More Resources======
More resources from Univ. Texas are added into the repository, using MATLAB to process it, rather than storaged in a .bin file, which makes the origin code hard to run on this dataset.
Run code "loadAndPlotExemplarFrames.m" to start. By the way, it requires a GREAT memory, or you will as enjoyable as having bullshit when seeing the "Insufficient Memory" error.
Here is the original link: https://zenodo.org/records/21404931
Hope that it will work for us.

Done by: Mosles Signall (Y.D. Bai)
Version: 1.0.0.a1, on date 1155-27Nov2026-Fri

======Version 1.0.0======
This project processes the STARLINK downlink signal, whose name is exemplar250-257.bin initially, and is referred to here as mystery.bin.
According to the original infomation, the data contains a signal from subchannel 6, covering 50 ms, sampled at 250 MHz.
Using the known PSS/SSS as the beacon, this project generate the ideal signal which is used to find the highest peak of the correlation function between itself and the original signal and locate the beginning of a frame, and, naturally, it helps in counting the number of the frames contained in.
There are 9 full frames and 1 frame cut by the time limit. The 9 full frames ahead are numbered from 0 to 8.
More infomation in the excel.
We hope that the SpaceX company hasn't used some unknown set of constellation diagram. If the GOD belss the USA, we can only hope that He could be fair.
GPT 6.2-sol is used in the program. Every submodel has been ckecked to prove the effectiveness of its code.

Done by: Mosles Signall (Y.D. Bai)
Version: 1.0.0, on date 1353-26Nov2026-Thu
