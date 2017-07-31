load "setFont.gp"
set xlabel 't[s]'
set ylabel 'th[rad]'
set xrange [0:15]
set  terminal windows enhanced 0
plot "CalcError_dt1.mat" using 1:3 with lines linewidth 2 linecolor rgbcolor "red" title "error1 th"
replot "CalcError_dt2.mat" using 1:3 with lines linewidth 2 linecolor rgbcolor "green" title "error2 th"