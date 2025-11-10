#!/usr/bin/bash

<<"memo"
1インチあたり96px : 1インチ25.4mm : "96 / 25.4" 1mmあたり3.7795275590551181102362204724409448818897637795275590551181102362204724409448818897637795275590551181px
文字サイズ72pt=96px 1ptあたり1.3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333px


文字サイズ72pt=96px 10ptあたり13.3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333px

文字サイズ10ptあたりのピクセル数(13.3...px)x1インチあたりのミリ(25.4mm)/1インチ(96px) 3.5277777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777mm
↑が一行あたりの縦幅(mm)

10ptあたりのピクセル数(13.3....)/1インチあたりのピクセル数(96px) = .1388888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888in.
コンソールを画面いっぱいにタテに伸ばした$LINESは10px時でたぶん54行
10ptあたりのピクセル数(13.3....)x1インチあたりのミリ(25.4mm)x54行/1インチあたりのピクセル数(96px) = 190.4999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999995mm

10ptあたりのピクセル数(13.3....)x54行/1インチあたりのピクセル数(96px) = 7.4999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999in.
190.5mm と7.5in.が画面の縦幅（もう1行あるっぽいからプラス約4ミリ約194.mmが実際のサイズ
memo

CHAR_POINTS=10
DEFAULT_DOTS_PER_INCHIS=96 

MM_PER_INCH=25.4 
POINTS_PER_DPI=72 # google にて「文字サイズ ピクセル数」等で検索

DPI=$(xdpyinfo | grep -e"resolution"|cut -d' ' -f7|cut -d"x" -f1) #96
DPI=${DPI:=$DEFAULT_DOTS_PER_INCHIS}

FILE=/home/oreore/.csl-log
FILE_LINES=$(wc -l $FILE|cut -d' ' -f1)

CURRENT_CHAR_POINTS=${1}
CURRENT_CHAR_POINTS=${CURRENT_CHAR_POINTS:=$CHAR_POINTS}

echo FILE=$FILE
echo DPI=$DPI
echo POINTS_PER_DPI=$POINTS_PER_DPI
echo CURRENT_CHAR_POINTS=$CURRENT_CHAR_POINTS
echo FILE_LINES=$FILE_LINES
echo MM_PER_INCH=$MM_PER_INCH
echo

# points per DPI:ppd
# DPI:dot/in.   DPI/mm:dot/(in.*mm)  mm/DPI:96DPI=1in なため25.4mm--1/(DPI/(in.*mm))*DPI=((in.*mm)/DPI)*DPI
# mm/pt:25.4/ppd  mm/dot:25.4/DPI

# DPI/POINTS_PER_DPI = 1ポイントあたりのドット数
dots_per_pt=$(echo "scale=10;$DPI/$POINTS_PER_DPI"|bc|sed 's/^\./0./') #DPI/ptpDPI
pt_per_dots=$(echo "scale=10;$POINTS_PER_DPI/$DPI"|bc|sed 's/^\./0./') # ptpDPI/DPI   pt:1.333dot/in.=DPI/pt=ppd

in_per_dots=$(echo "scale=10;1/$DPI"|bc|sed 's/^\./0./') # in/DPI
mm_per_dots=$(echo "scale=10;($MM_PER_INCH/$DPI)"|bc|sed 's/^\./0./') # mm/dot:25.4/DPI

in_per_pt=$(echo "scale=10;$in_per_dots*$dots_per_pt"|bc|sed 's/^\./0./')
mm_per_pt=$(echo "scale=10;$mm_per_dots*$dots_per_pt"|bc|sed 's/^\./0./')
# mm/pt:25.4/ppd
echo "1ポイントあたりのドット数:${dots_per_pt}px"
echo "1ドットあたりのポイント数:${pt_per_dots}pt"
echo
echo "1ポイントあたりの高さ(in):${in_per_pt}in"
echo "1ポイントあたりの高さ(mm):${mm_per_pt}mm"
echo
echo "1ドットあたりの高さ(in):${in_per_dots}in"
echo "1ドットあたりの高さ(mm):${mm_per_dots}mm"
echo

# 1ポイントあたりのDPI*CURRENT_CHAR_POINTS = 文字サイズでのドット数(行の高さ) 
pt_current_char_size=$CURRENT_CHAR_POINTS
dots_current_char_size=$(echo "scale=10;${dots_per_pt}*$pt_current_char_size"|bc|sed 's/^\./0./') # dot/pt*cpt
# 1行の高さ
in_current_line_size=$(echo "scale=10;${in_per_dots}*$dots_current_char_size"|bc|sed 's/^\./0./') # in/dot*cdot=(in*dot)/dot 1行の高さin
mm_current_line_size=$(echo "scale=10;${mm_per_dots}*$dots_current_char_size"|bc|sed 's/^\./0./') # mm/dot*cdot=(mm*dot)/dot 1行の高さmm

echo "文字サイズ(${pt_current_char_size}pt)でのドット数(px):${dots_current_char_size}px"
echo "文字サイズ(${pt_current_char_size}pt)での行の高さ(in):${in_current_line_size}in"
echo "文字サイズ(${pt_current_char_size}pt)での行の高さ(mm):${mm_current_line_size}mm"
echo

# ログファイルの高さ
meter_file_height=$(echo "scale=10;${mm_current_line_size}*$FILE_LINES/1000"|bc)
in_file_height=$(echo "scale=10;${in_current_line_size}*$FILE_LINES"|bc)
feet_file_height=$(echo "scale=10;${in_file_height}/12"|bc)
echo "文字サイズ(${pt_current_char_size}pt)での文字だけのファイルの高さ(m):${meter_file_height}m"
echo "文字サイズ(${pt_current_char_size}pt)でのログファイルの高さ(in):${in_file_height}in"
echo "文字サイズ(${pt_current_char_size}pt)でのログファイルの高さ(feet):${feet_file_height}feet"

echo 
echo "ファイルの行数と画面に10pt時に最大表示可能な行数(55行)から求めた高さ:$(echo "scale=10;(22406/55)*194/1000"|bc)m"
