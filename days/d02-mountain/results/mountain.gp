set datafile separator comma
set terminal pngcairo size 1100,800
set output png
set title 'Memory mountain'
set xlabel 'stride (x8 bytes)' offset 0,-1
set ylabel 'size (bytes)' offset 8,0
set zlabel 'MB/s' rotate parallel
set view 60, 30
set xrange [*:*] reverse
set yrange [*:*] reverse
set xyplane 0
set grid
set pm3d depthorder border lc 'black'
set palette rgbformulae 33,13,10
unset colorbox
splot csv matrix columnheaders rowheaders using 1:2:3 with pm3d notitle
