set terminal postscript eps enhanced color "Arial,22"
filename = sprintf("%s_r.eps",name)
set output filename # ファイル名で保存場所を指定可能
replot                    # 必要
set output                # 必要。これで、先ほど作ったepsがcloseされる。
set terminal windows          # ターミナルをもとに戻す(wxtでなくても良い)
