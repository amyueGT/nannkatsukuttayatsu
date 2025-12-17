#!/usr/bin/bash

#BACKUP_SOURCE_ROOT=/home/backup
BACKUP_SOURCE_specified=
BACKUP_DEST_HOME=/home/backup/dest/home
#BACKUP_DEST_HOME=/home/backup
BACKUP_DEST_ROOT=${BACKUP_DEST_HOME}/backup_root


if [[ $(whoami) == root ]];then
	LOG_FILE=/backup_shell_202511/tmp/backup_sudo_log
	LOG_TMP_FILE=/backup_shell_202511/tmp/backup_log_sudo_tmp
else
	LOG_FILE=/backup_shell_202511/tmp/backup_log
	LOG_TMP_FILE=/backup_shell_202511/tmp/backup_log_tmp

	while true;do
		read -p"sudo権限がついてないけど実行する？ e + enter で続行:" res
		if [[ $res == e ]];then 
			break
		else
			if [[ "${BASH_SOURCE[0]}" != "$0" && "${FUNCNAME[@]}" == *source ]]; then
				# ソース実行
				echo ソース実行
				return
			else #if [[ "${FUNCNAME[@]}" == *main ]]; then
				echo スクリプト実行
				exit
			fi
		fi
	done

fi


TYPE_F=0
TYPE_HF=1
TYPE_D=2
TYPE_HD=3

EXCEPTION=()

function backup_202511_help(){
	echo "################# ${BASH_SOURCE##*/} help ###################"
	echo
	echo "-c  --source[=dir1,dir2,..dirN] : バックアップのソースを指定。カンマ区切り"
	echo "-i  --ignore[=word1,word2,..wordN] : 除外するワードを指定。カンマ区切り"
	echo "-s  --simulation : ログだけを表示で作成されるパスの確認 デフォ設定"
	echo "-e  --execute : 実際にバックアップをとる"
	echo "-d  --detail : 詳細なログを出力 (ログを減らして速度アップ"
	echo "    --whole_home : ${HOME}をすべてバックアップ @[${BACKUP_DEST_ROOT}/yyyyddmm/${HOME} ]"
	echo "    --bind_dir : ディレクトリの場合内部を見ずに[dir_name_bkyyyyddmm]のようにまとめる"
	echo "    --bind_hidden_dir : 隠しディレクトリの場合内部を見ずに[.hidden_dir_name_bkyyyyddmm]のようにまとめる"
	echo "    --only_dir : ディレクトリのみをfindする"
	echo "    --only_file : ファイルのみをfindする"
	echo "    --only_hidden : 隠しファイル/ディレクトリのみをfindする"
	echo "-f  --confirm : ファイル一つ一つ実行するか確認する "
	echo "-g  --grep[=regex] : egrep で対象ファイルの絞り込み。"
	echo "-G  --GREP : 大抵のバックアップファイルは [ _20[0-9]{10,12}$|bkup|~$ ]で絞り込み可能なためオプション化"
	echo "-l  --logfile : ログファイルのパスを指定 デフォ:[$LOG_FILE]"
	echo "-h  --help : helpを出力"
	echo
	echo "   --debug[=num] : デバッグ用に回数を制限して実行する"
	echo "-b --break_words[=word1,word2,..wordN] : ブレークするワード。カンマ区切り。関数break_point()指定時のみ" ##この行はどっか別のところへ
	echo
	echo "== 今後の課題 =="
	echo "・ --bind_dir時等にtarを作成する処理を追加できたらやる。tarアーカイブを作成して全部そこに追加する形にする（？）20251128"
	echo "・ find時ディレクトリのみとファイルのみを分けてリスト上では一つにしたほうが良いかも(?)２重ループがおかしい 20251203"
	echo "・ 以前にアップしたバックアップ用のシェルも全然使ってないがそのバックアップファイルを別の場所に移行するシェルに続けて"
	echo "			移行先で常時使える形のシェルを思いつきですぐできるつもりのところから作り始めて想定を大幅に上回る作業試行をした。"
	echo "				そもそも何が必要かがわかってないとも言えるが完成形をちゃんと設計想定せずに作ってるため後から後から修正の連鎖になってると言えなくもない。20251203"
	echo "・ ロガーやbashでのデバッグのやり方が他の作成中のシェルにバラけて存在してるため全部まとめて色々付け加えたらたらシェルのデバッガーやロガーとしてそれっぽいのができそう 20251203"
	echo 
	echo "################# ${BASH_SOURCE##*/} help end ###################"
}

REGEX_grep=
mode_at_status+="simulation "
is_only_dir=false
is_only_file=false
is_only_hidden=false
is_detail=false
is_grep=false
is_bind_dir=false
is_bind_hidden_dir=false
is_sim=true
is_debug=false
is_ignore=false
is_break_point=false
is_command_confirm=false
for arg in $@;do
	if [[ $arg =~ ^(-h|--help) ]];then
		backup_202511_help
		exit
	fi

	if [[ $arg =~ ^(-e|--execute) && ! "$@" =~ ^(-s|--simulation) ]];then
		is_sim=false
		set -- ${@//$arg/};
		continue;
	fi
	if [[ $arg =~ ^(-s|--simulation) ]];then
		is_sim=true
	fi
	if [[ $arg =~ ^(-d|--detail) ]];then
		is_detail=true
		mode_at_status+="detail "
	fi
	if [[ $arg =~ ^(--bind_dir) ]];then
		is_bind_dir=true
		mode_at_status+="bind_dir "
	fi
	if [[ $arg =~ ^(--bind_hidden_dir)$ ]];then
		is_bind_hidden_dir=true
		mode_at_status+="bind_hidden_dir "
	fi
	if [[ $arg =~ ^(-l|--logfile)$ ]];then
		arg="${arg#*logfile}"
		arg="${arg#*l}"
		arg="${arg#*=}"
		LOG_FILE="$arg"
	fi
	if [[ $arg =~ ^(-g|--grep) ]];then
		is_grep=true
		arg="${arg#*grep}"
		arg="${arg#*g}"
		arg="${arg#*=}"
		#arg="${arg#[\'\""]}"
		#arg="${arg%[\'\""]}"
		REGEX_grep="${arg}"
	fi
	if [[ $arg =~ ^(-G|--GREP) ]];then
		is_grep=true
		REGEX_grep="_20[0-9]{10,12}$|bkup|~$"
	fi
	if [[ $arg =~ ^(--debug)$ ]];then
		arg=${arg#*debug}
		arg=${arg#*=}
		#debug_count="${arg:-5}"
		debug_count="${arg}"
		is_debug=true
		mode_at_status+="debug "
	fi
	if [[ $arg =~ ^(-c|--source) ]];then
		if [[ $arg =~ ^--source ]];then
			arg="${arg#*source}"
		elif [[ $arg =~ ^-c ]];then
			arg="${arg#*c}"
		fi
		if [[ $arg =~ ^= ]];then
			arg="${arg#*=}"
		fi
		BACKUP_SOURCE_specified=(${arg//,/$'\n'})
		mode_at_status="${mode_at_status}sources=(${arg//,/|}) "
	fi
	if [[ $arg =~ ^(-i|--ignore) ]];then
		is_ignore=true
		if [[ $arg =~ ^--ignore ]];then
			arg="${arg#*ignore}"
		elif [[ $arg =~ ^-i ]];then
			arg="${arg#*i}"
		fi
		if [[ $arg =~ ^= ]];then
			arg="${arg#*=}"
		fi
		IGNORE_words=${arg//,/|}
		mode_at_status="${mode_at_status}ignores=(${IGNORE_words}) "
	fi
	if [[ $arg =~ ^(-f|--confirm) ]];then
		is_command_confirm=true
		mode_at_status="${mode_at_status}confirm "
	fi
	if [[ $arg =~ ^(-b|--break_words) ]];then
		is_break_point=true
		if [[ $arg =~ ^--break_words ]];then
			arg="${arg#*break_words}"
		elif [[ $arg =~ ^-b ]];then
			arg="${arg#*b}"
		fi
		if [[ $arg =~ ^= ]];then
			arg="${arg#*=}"
		fi
		break_words="${arg//,/|}"
		mode_at_status="${mode_at_status}break_words=(${break_words}) "
	fi
	if [[ $arg =~ ^(--only_dir) ]];then
		is_only_dir=true
		mode_at_status="${mode_at_status}only_dir "
	fi
	if [[ $arg =~ ^(--only_file) ]];then
		is_only_file=true;
		mode_at_status="${mode_at_status}only_file "
	fi
	if [[ $arg =~ ^(--only_hidden) ]];then
		is_only_hidden=true;
		mode_at_status="${mode_at_status}only_hidden "
	fi
done

function backup_202511_confirm(){
	if [[ -z $BACKUP_SOURCE_specified  ]];then
		echo "-c --source が設定されてないため終了"
		exit
	fi
	if ! $is_sim;then
		mode_at_status=${mode_at_status//simulation /execute }
	fi

	if [[ -z ${COLUMNS} || -z $LINES ]];then
		eval "$(stty size|sed -En 's/(.*) (.*)/COLUMNS=\1;LINES=\2;/')"
	fi

	printf " %*s: %s\n" 9 "mode" "${mode_at_status}"
	printf " %*s: %s\n" 9 "sources" "${BACKUP_SOURCE_specified[*]}"
	printf " %*s: %s\n" 9 "log file" "$LOG_FILE"
	#echo -n "以上の設定で"
	if $is_sim;then
		for sec in {5..1};do
			echo -en "以上の設定でcpの空打ちが\e[1;91m${sec}\e[0m秒後に実行されるぞ。すぐに実行するなら y + enter:"
			read -t 1 res
			if [[ $res == y ]];then 
				echo "y が入力されたからcpのからうちをすぐに実行するぞ。"
				break;
			fi
			echo -en "\r"
		done;
	else
		echo "以上の設定で実際にバックアップが実行されるぞ。okならyそうでないならそれ以外"
		read res ;
		if [[ $res == y ]];then
			#mode_at_status+="execute "
			:
		else
			echo y以外が選択されたため終了
			exit
		fi
	fi
}

function backup_202511_init(){
	#if [[ ! -e $BACKUP_DEST_ROOT && -e /dev/sda2 ]];then
	if ! df|grep $BACKUP_DEST_HOME;then
		if ! mkdir --parents $BACKUP_DEST_ROOT|| mount -am;then
			mkdir --parents $BACKUP_DEST_ROOT
		else
			echo "宛先対象ディレクトリ(外付けストレージ)がないため終了:[$BACKUP_DEST_HOME]"
			exit
		fi
	fi
	if [[ ! -e $BACKUP_DEST_HOME ]];then
		if ! mount -am;then
			echo "宛先対象ディレクトリ(外付けストレージ)がないため終了:[$BACKUP_DEST_HOME]"
			exit
		fi
	fi

	begin_date=$(date)

	dest_dir_root=$BACKUP_DEST_ROOT
	append_text="bkup$(date +'%Y%m%d%H%M%S')"
	append_text="_${append_text}";

	tmp_IFS=$IFS
	IFS=$'\n'
	pwd=$PWD

	#eval "$start_fd"
	echo > $LOG_FILE #内容をリセット
	echo > $LOG_TMP_FILE
	#pid=$BASHPID
	exec 40>$LOG_FILE
	exec 44>$LOG_TMP_FILE
#	ls -l /proc/$BASHPID/fd/44 /proc/$BASHPID/fd/40
	LOG_TMP_FILE_fd="/proc/$BASHPID/fd/44"
	printf "\e7\033[%d;%dr\e8\e[5S\e[3A\e[?25l" "1" "$((LINES-1))" #スクロールの範囲を指定してカーソルを隠す

	excuting_source_root_count=0;
	source_home_list_size=0;
	excuting_source_count=0;
	source_path_list_size=0;
	fail_count=0;
	print_status
	#printf "\e[%sS\e[2A" $
	#printf "\e7\033[%d;%dr\e8" "1" "$((LINES))"
	#printf "\033[2J\033[H" #画面をクリアしてカーソルをホームポジに移動
	# detail_logechoはここから使用

	is_sig_tstop=false
	# SIGTSTP 中断からのfinallyはうまく行かない
	#ctrl+z:SIGTSTP ctrl+c:SIGINT fg:SIGCONT
	trap 'backup_202511_finally SIGINT;' SIGINT
	trap 'is_sig_tstop=true;' SIGTSTP
	trap "is_sigwinch=true;console_ctrl $CCTRL_WIN_SIZE" SIGWINCH
	#trap 'fg;kill -SIGINT $BASHPID;' SIGTSTP
	#trap 'backup_202511_finally SIGTSTP;' SIGTSTP
	#trap 'echo $BASHPID;backup_202511_finally SIGTSTP $BASHPID;kill -SIGCONT $BASHPID;' SIGTSTP
	detail_logecho "init done"
}

CCTRL_SAVE=1
CCTRL_STATUS=2
CCTRL_WIN_SIZE=3
function console_ctrl(){
	#save_cursor_pos(){
	#	printf "\e7"
	#}
	#load_cursor_pos(){
	#	printf "\e8"
	#}
	#init_window(){
	#	printf "\033[%d;%dr" 1 "$((LINES-1))"
	#}
	#move_cursor_pos_status(){
	#	printf "\e[%s;1H" $LINES
	#}
	set_window_size(){
		LINES=$(tput lines)
		COLUMNS=$(tput cols)
		#eval "$(stty size|sed -En 's/(.*) (.*)/COLUMNS=\1;LINES=\2;/')"
		#if [[ $1 -eq $CCTRL_WIN_SIZE ]] || $is_sigwinch;then
		if $is_sigwinch;then
			printf "\e7\033[%d;%dr\e8\e[5S\e[3A" "1" "$((LINES-1))" #スクロールの範囲を指定
			is_sigwinch=false
		fi
	}

	# trap "is_sigwinch=true;console_ctrl $CCTRL_WIN_SIZE" SIGWINCH
	#if [[ $1 -eq $CCTRL_WIN_SIZE ]] || $is_sigwinch;then
	#	set_window_size
	#	is_sigwinch=false
	#fi

	set_window_size
}

function backup_202511_finally(){
	end_date=$(date)
	printf "\e8\e[?25h\e[3S" #print_statusで\e7した場所に戻してカーソルを再度表示
	logecho ""
	logecho "===============${BASH_SOURCE}"

	if [[ -n $source_path_list_size ]];then
		if [[ $1 == SIGINT ]];then
			logecho "recieve signal:SIGINT"
		# 	logecho "executing  dirs :$excuting_source_root_count/$source_home_list_size"
		#	logecho "executing files :$excuting_source_count/$source_path_list_size"
		#else
		fi
		logecho "executed   sources :$excuting_source_root_count/$source_home_list_size"
		logecho "executed sub_files :$excuting_source_count_total/$source_path_list_size_total"
	fi
	if [[ -n ${EXCEPTION[@]} || $1 == SIGINT ]];then
		logecho 
		((${#EXCEPTION[@]} > 0)) && logecho "<< 発生したエラー >>" && for e in ${EXCEPTION[@]};do
			logecho "$e"
		done && logecho ""
		if [[ $source_path_list_size -gt 0 && -n ${EXCEPTION[@]} ]];then
			logecho それ以外は多分全部実行できた
		elif $is_sim;then
			logecho "simulation モードだから実際のバックアップはまだやってないぞ"
		else
			logecho まだバックアップは何も実行してないぞ #successをカウントして件数表示
		fi
	else
		logecho "たぶん全部実行できた"
	fi
	logecho
	logecho "mode was :$mode_at_status"
	logecho "fail count was :$fail_count"
	logecho "backup_log output at :$LOG_FILE"
	logecho "begin at :$begin_date"
	logecho "end at :$end_date"
	logecho "finally done"
	#eval "$stop_fd"

	exec 40>&-
	exec 44>&-
	IFS=$tmp_IFS
	rm $LOG_TMP_FILE
	# printf "\033[%d;%dr\e[%dB" "1" "$LINES" "$LINES"
	printf "\033[%d;%dr" "1" "$LINES"
	printf "\e[%dB" "$LINES"
	printf "\e[K" # printf "%*s" $COLUMNS
	exit
}

function backup_202511(){
	# 重複する要素の削除
	BACKUP_SOURCE_specified=($(echo "${BACKUP_SOURCE_specified[@]}"|sed -E 's/ /\n/g'|sort -r));
	for ((x=0;x<${#BACKUP_SOURCE_specified[@]};x++));do 
		y=$((x+1))
		num1=$(echo ${BACKUP_SOURCE_specified[$x]}|wc -c)
		num2=$(echo ${BACKUP_SOURCE_specified[$x]#${BACKUP_SOURCE_specified[$y]}}|wc -c)
		if [[ -d ${BACKUP_SOURCE_specified[$y]} && $num1 -ne $num2 ]];then
			detail_logecho "指定されたパス[${BACKUP_SOURCE_specified[$x]}]は指定されたパス[${BACKUP_SOURCE_specified[$y]}]に内包されるため検索から省くぞ"
			EXCEPTION+=("指定されたパス[${BACKUP_SOURCE_specified[$x]}]は指定されたパス[${BACKUP_SOURCE_specified[$y]}]に内包されるため検索から省くぞ")
			unset BACKUP_SOURCE_specified[$x];
		fi 
	done;
	BACKUP_SOURCE_specified=($(printf "%s\n" ${BACKUP_SOURCE_specified[@]}));

	for name in ${BACKUP_SOURCE_specified[@]};do
		source_tmp_list=()
		name=${name%/}
		# このシェルというより端末の問題で
		# このセクションがターミナル上ではスクロールで画面外に出た後に一部表示が消える
		logecho -n "/${name#/}の有無確認..." 
		
		#source_tmp_list=($(find /${name#/} -maxdepth 0 2> /dev/null))
		#if [[ -z ${source_tmp_list[@]} ]];then
		if [[ ! -e /${name#/} ]];then
			logecho " : not found"
			logecho -n "${PWD%/}/${name#/}の有無確認..."
			#source_tmp_list=($(find $PWD/${name#/} -maxdepth 1 2> /dev/null));
			#if [[ -z ${source_tmp_list[@]} ]];then
			if [[ ! -e "$PWD/${name#/}" ]];then
				logecho " : not found"
				EXCEPTION+=("\"/${name#/}\"は見つからなかったぞ")
				detail_logecho "\"/${name#/}\"は見つからなかったぞ"
			else
				logecho " : exist"
				source_home_list+=($PWD/${name#/})
			fi
		else
			logecho " : exist"
			source_home_list+=(/${name#/})
		fi
		#source_home_list+=(${source_tmp_list[@]})
	done
	logecho
#break_point
	source_home_list_size=${#source_home_list[@]}
	excuting_source_root_count=0;
	fail_count=0;
	source_path_list_size=

	if $is_bind_hidden_dir;then
		grep_invert_exp_bind_hidden="-e'\..*/.*'"
	fi
	if $is_bind_dir;then
		grep_invert_exp_bind="-e'($(echo ${BACKUP_SOURCE_specified[@]}|sed -E 's/ /|/g'))/.*'"
	fi
	if $is_only_dir;then
		find_option=" -type d"
	elif $is_only_file;then
		find_option=" -type f"
	fi
	if $is_only_hidden;then
		find_option=" -maxdepth 1 ${find_option} -regex '.*\/\..*'"
	fi

	excuting_source_count_total=0
	for source_home in "${source_home_list[@]}";do
		((excuting_source_root_count++))
		source_path_list=
		logecho -n "${source_home}内をfind..."

		if $is_bind_hidden_dir || $is_bind_dir;then
			#logecho "find $source_home|grep -Ev $grep_invert_exp_bind $grep_invert_exp_bind_hidden|sort"
			detail_logecho -n " : eval \"find ${source_home} ${find_option}|grep -Ev $grep_invert_exp_bind $grep_invert_exp_bind_hidden|sort\""
			source_path_list=($(eval "find ${source_home} ${find_option}|grep -Ev $grep_invert_exp_bind $grep_invert_exp_bind_hidden|sort" ))
		else
			detail_logecho -n " : eval find ${source_home} ${find_option}|sort"
			source_path_list=($(eval "find ${source_home} ${find_option}|sort"))
		fi
		logecho " : ${#source_path_list[@]}件取得"
		if [[ -z ${source_path_list[@]} ]];then
			if $is_bind_hidden_dir;then
				logecho "--bind_hidden_dirが設定されてるけどhidden_dir内のファイルが指定されたため処理はパスされたぞ.$source_home"
				EXCEPTION+=("--bind_hidden_dirが設定されてるけどhidden_dir内のファイルが指定されたため処理はパスされたぞ.$source_home")
			#elif $is_bind_dir;then
			else
				source_path_list+=($source_home)
				#来ないはずの処理
				## logecho "存在しないファイル/ディレクトリが指定されてるため処理はパス.$source_home"
				## EXCEPTION+=("存在しないファイル/ディレクトリが指定されてるため処理はパス.$source_home");
			fi
		fi
		if $is_grep && [[ -n $REGEX_grep ]];then
			detail_logecho -n "egrep ${REGEX_grep} で絞り込み"
			source_path_list=($(printf "%s\n" ${source_path_list[@]}|grep --color=no -E -e"${REGEX_grep}" ))
			detail_logecho " : ${#source_path_list[@]}件に絞り込み"
			if [[ -z $source_path_list ]];then
				logecho "--grepで絞り込んだ結果${source_home}での対象ファイルは無くなったためパスするぞ"
				EXCEPTION+=("--grepで絞り込んだ結果${source_home}での対象ファイルは無くなったためパスするぞ");
				continue
			fi
		fi
#break_point "is_grep=$is_grep REGEX_grep=$REGEX_grep"
		source_home=${source_home#/}
		source_path_list_size=${#source_path_list[@]};
		excuting_source_count=0;
		
		((source_path_list_size_total+=source_path_list_size))

		for source_path in "${source_path_list[@]}";do
			((excuting_source_count++,excuting_source_count_total++))
			print_status
			logecho "" #行をあける
			#logecho -n "executing(dirs:$excuting_source_root_count/$source_home_list_size files:$excuting_source_count/$source_path_list_size) : $source_home --- $source_path "
			logecho -n "executing(sources:$excuting_source_root_count/$source_home_list_size sub_files:$excuting_source_count/$source_path_list_size) : $source_home --- $source_path "
			file_type=
			if [[ -f $source_path ]];then
				if [[ ${source_path##*/} =~ ^"." ]];then
					#file_type=_HF
					file_type=HF
					is_type=$TYPE_HF
				else
					#file_type=_F
					file_type=F
					is_type=$TYPE_F
				fi
			elif [[ -d $source_path ]];then
				if [[ ${source_path##*/} =~ ^"." ]];then
					#file_type=_HD
					file_type=HD
					is_type=$TYPE_HD
				else
					#file_type=_D
					file_type=D
					is_type=$TYPE_D
				fi
			fi


			if $is_ignore && [[ "${source_path}" =~ (${IGNORE_words}) ]];then
				detail_logecho -n "source_path=$source_path :  : ignore対象のため";
				logecho "continue"
				print_data $@
				continue;
			elif [[ "$source_path" == "/$source_home" ]];then #if [[ $source_path =~ ^(${BACKUP_SOURCE_ROOT//,/|})$ ]];then 
		# ここから宛先パスの作成までもっと簡単になる気がするけど放置20251128
		# 指定ディレクトリでbindか個別かの判定が怪しい
				if [[ $is_type -le $TYPE_HF || $is_bind_dir || $is_bind_hidden_dir ]];then
					source_home=${source_path%/*}
					source_home=${source_home#/}
				else
					detail_logecho -n "source_path=$source_path : 対象ルートディレクトリのため";
					logecho "continue"
					print_data $@
					continue;
				fi
			fi

			dest_dir=$dest_dir_root
			source_home_child="${source_path#/${source_home}\/}"
			source_home_child="${source_home_child#/}"
			hidden_dir=
			if $is_bind_hidden_dir && ((is_type!=TYPE_HD));then 
				# DとFとHFの時
				words=(${source_home_child//\//$'\n'});
				for((x=0;x<${#words[@]};x++ ));do 
					if [[ ${words[$x]} =~ ^"." && -d ${source_path%${words[$x]}*}${words[$x]} ]];then
						is_type=$TYPE_HD
						file_type=HD
						printf -vhidden_dir "/%s" ${words[$x]}
						break
					fi
				done
			fi
			if [[ -n $hidden_dir ]];then
				hidden_dir=${hidden_dir#/}
				source_home_child=${source_home_child%${hidden_dir}*}${hidden_dir}
				if [[ $is_bind_hidden_dir && $source_path != /${source_home}/${source_home_child} ]];then
					EXCEPTION+=("--bind_hidden_dirが指定されてるけどhidden_dir以下のファイルが指定されたためcontinue.指定されたファイル:$source_path")
					detail_logecho "--bind_hidden_dirが指定されてるけどhidden_dir以下のファイルが指定されたためcontinue.指定されたファイル:$source_path"
					logecho "continue"
					print_data $@
					continue
				fi
			fi
			logecho -n " is $file_type."
			logecho "$(if [[ -n $hidden_dir ]];then echo "but in \"$hidden_dir\" so $file_type."; else echo "";fi)"

			# 宛先パスの作成
			source_path_dest=${source_path#/}
			dest_path=
			append_text=${append_text}
			if [[ $is_type -ge $TYPE_D ]];then
				source_path_dirs=${source_path}
				if $is_bind_hidden_dir && ((is_type==TYPE_HD));then #[[ -n $hidden_dir ]];then 
					source_path_dirs=${source_path%${hidden_dir}*}${hidden_dir}
					dest_dir+=${source_path%${hidden_dir}*}${hidden_dir}
					dest_dir+=${append_text}
					dest_path=
				elif $is_bind_dir ;then
					dest_dir+=${source_path}
					dest_dir+=${append_text}
					dest_path=
				else
					# オプション無しでディレクトリを指定した場合
					dest_dir+=$source_path_dirs
					dest_path=${dest_dir_root}${source_path}
				fi
			else
				source_path_dirs=${source_path%/*}
				source_path_tail=${source_path##*/}
				dest_dir+=${source_path_dirs}
				dest_path=${dest_dir_root} #$dest_dir
				dest_path+=${source_path}${append_text}
			fi
			# コピーの実行
			if ((is_type>=TYPE_D));then # || is_type==TYPE_HD));then
				if ((is_type==TYPE_D));then
					if $is_bind_dir && [[ ${BACKUP_SOURCE_specified[@]} != ${source_path} ]];then
						# 来ないはずの処理
						for path in ${BACKUP_SOURCE_specified[@]};do
							if [[ ${path} =~ ${source_path} && ${path} != ${source_path} ]];then
								logecho "\${BACKUP_SOURCE_specified[@]}=${BACKUP_SOURCE_specified[@]}"
								logecho "\${source_path}=${source_path}"
								detail_logecho -n "option:--bind_dir が指定されてるけど配下の要素のため"
								logecho "continue"
								print_data $@
								continue
							fi
						done
					elif ! $is_bind_dir;then
						detail_logecho -n  "option:--bind_dir が指定されてないため"
						logecho "continue"
						print_data $@
						continue
					fi
				elif ((is_type==TYPE_HD)) && ! $is_bind_hidden_dir && ! $is_bind_dir ;then
					detail_logecho -n "option:--bind_hidden_dir が指定されてないため"
					logecho "continue"
					print_data $@
					continue
				fi
				if $is_sim && [[ ${sim_made_dir[@]} =~ ${dest_dir} ]] ||
					 [[ -d ${dest_dir} ]];then
					detail_logecho -n "すでにバックアップ済み$([[ -n $hidden_dir ]] && echo 隠し;)ディレクトリのためスキップ:${dest_dir} --- ${source_path}";
					logecho "continue"
					print_data $@
					continue;
				fi

				if [[ -d $dest_dir || ${sim_made_dir[@]} =~ $dest_dir ]];then
					logecho "$dest_dir is exist."
				else
					logecho -n "${file_type#_} --- mkdir --parents \"${dest_dir}\"";
					if command_confirm "mkdir";then
						if ! $is_sim;then mkdir --parents "${dest_dir}" >&44 2>&44;rtn_CODE=$?;fi
					fi
					result_logecho 
				fi
				logecho -n "move to cd:${source_path_dirs}"
				cd ${source_path_dirs} >&44 2>&44;rtn_CODE=$?;
				result_logecho
				logecho -n "${file_type#_} cp -r --parents --preserve=all -t\"${dest_dir}\" . --@$PWD ${file_type#_} ";
				if command_confirm "cp";then
					if ! $is_sim;then cp -r --parents --preserve=all -t"$dest_dir" . >&44 2>&44;rtn_CODE=$?;fi
				fi
				result_logecho 
				logecho "back to cd:$pwd ";
				cd $pwd
				#if [[ -d $source_path ]];then continue;fi #ただのディレクトリなら何もしない
			else #if [[ -f $source_path ]];then
				#ディレクトリでないなら
				if [[ -d $dest_dir || ${sim_made_dir[@]} =~ $dest_dir ]];then
					logecho "$dest_dir is exist."
				else
					logecho -n "F mkdir --parents $dest_dir F";
					if command_confirm "mkdir";then 
						if ! $is_sim;then mkdir --parents "$dest_dir" >&44 2>&44;rtn_CODE=$?;fi
					fi
					result_logecho
				fi
				logecho -n "F cp --preserve=all $source_path $dest_path --@$PWD F ";
				if command_confirm "cp";then 
					if ! $is_sim;then cp --preserve=all "$source_path" "$dest_path" >&44 2>&44;rtn_CODE=$?;fi
				fi
				result_logecho
			fi

			if [[ -n $debug_count ]] && ((excuting_source_count==debug_count));then
				logecho debug_count=$debug_count
				logecho excuting_source_count=$excuting_source_count
				backup_202511_finally
			fi

			print_data $@
		done
		logecho ""
	done
	logecho ""

}

function detail_logecho(){
	if $is_detail;then logecho "$@";fi
}

function debug_logecho(){
	if $is_debug;then logecho "$@";fi
}

function logecho(){
	#opt=
	new_line="\n"
	if [[ $1 == -n ]];then
		#opt=-n
		new_line=
		shift
	elif [[ $1 == -h ]];then
		#ヒアドキュメントで入力
		shift
		set -- "$(cat $@)"
	fi

#	echo $opt "$@"
#	echo $opt "$@" >&40 2>&40;
	printf "%s$new_line" "$@";
	printf "%s$new_line" "$@" >&40 2>&40;
	#if [[ -z $opt ]];then
	#	tail -n$(echo "$@"| sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'|wc -l) $LOG_FILE;
	#fi

	#echo -ne "abc";echo -en "\n\e[1AABC\e[1BDEF\e[1A";echo -en "XXX\e[1B\n" で以下のABCDEFXXXが出力される
	#	ABC   XXX
	#	  DEF

	#declare ROW COL; IFS=';' read -sdR -p $'\E[6n' ROW COL;  echo "${ROW#*[}";echo -n "${COL#*[}"
}

function logcommand(){ #コマンドのログを出しつつ実行させようとしたやつ。ローカルではこれに応用できそうなものを既に実用してるがこれは未完成。
	echo "$@" >&40 2>&40;
	$@;
	tail -n$(echo "$@"| sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'|wc -l) $LOG_FILE
}

function result_logecho(){
	if $is_sim;then 
		logecho " : simulate done"
		if [[ ! ${sim_made_dir[@]} =~ $dest_dir ]];then
			sim_made_dir=("$dest_dir" "${sim_made_dir[@]}")
		fi
	elif [[ -n $rtn_CODE && $rtn_CODE =~ ^[0-9]+$ ]];then
		if [[ $rtn_CODE -eq 0 ]];then
			logecho ":success"
		else
			logecho -n "	return code is: $rtn_CODE"
			((fail_count++));
			if [[ $rtn_CODE -ne 0 && ! -s $LOG_TMP_FILE ]];then
				logecho ":no command error messages"
			else
				logecho ":\e[1;91merror!!!\e[0m messages at next line"
			fi
		fi
	else
		logecho ":return code is not found or not numeric $@ @lineNo:${BASH_LINENO[0]}"
	fi
	cat <$LOG_TMP_FILE_fd;
	cat <$LOG_TMP_FILE_fd >&40 2>&40;
	printf "" >$LOG_TMP_FILE #空にする echoだと遅い echo-nだと^@が積み重なった

	rtn_CODE=
}

function print_data(){
	if $is_debug;then
		logecho -e "\r"
		logecho -n "####################### print_data lineNo:${BASH_LINENO[0]} "
		logecho -h <<-EOS 
			source_roots:$excuting_source_root_count/$source_home_list_size
			targets     :$excuting_source_count/$source_path_list_size
			fails       :$fail_count

			source_home_list_size=$source_home_list_size
			source_home_list=${source_home_list[@]}
			source_path_list_size=${source_path_list_size}$(if ((source_path_list_size<50));then echo;echo source_path_list=${source_path_list[@]};fi)
			source_home=$source_home
			source_homesed=$(echo $source_home|sed -En 's/.*_([0-9]{8,12}).*/\1/p')
			source_path=$source_path
			source_path_dest=$source_path_dest
			source_path_dirs=$source_path_dirs
			source_path_tail=$source_path_tail
			append_text=$append_text
			file_type=$file_type
			hidden_dir=$hidden_dir
			dest_dir=$dest_dir
			dest_path=$dest_path

			\${words[@]}=${words[@]}
			\${words[$x]}=${words[$x]}
			$(printf "%*s" ${#BACKUP_DEST_ROOT})$source_path: $(if [[ -e $source_path ]];then echo found; else echo not found;fi)
			$dest_dir: $(if [[ -e $dest_dir ]];then echo found; else echo not found;fi)
			$dest_path: $(if [[ -e $dest_path ]];then echo found; else echo not found;fi)
			EOS
		logecho -n "####################### print_data lineNo:${BASH_LINENO[0]} "
		logecho ":$@ :end"
	fi
}

function break_point(){
	if $is_break_point || [[ -n $break_words && "$(print_data)" =~ (${break_words}) ]];then
		logecho
		
		logecho "######################################### break lineNo:${BASH_LINENO[0]} $@"
		logecho "#########################################"
		if [[ $break_words != no ]];then
			if [[ $break_words == print_all ]];then
				# 未完成
				eval "logecho \"$(cat $BASH_SOURCE|sed -n '1,715p'|sed -E 's/(\ |\t)+//'|sed -E 's/(\ |\t)+//'| grep -v -e"echo" -e"if" -e"^[A-Z]" -e"^#" -e"cp" -e"mkdir" -e"for" -e"trap" -e"cd" -e"\\\$" | grep -E "[+-]?="|sed -E "s/[+-]?=.*//"|sort -r|uniq|sed -E "s/(.*)/\1=\$\1/")\""
			else
				print_data "$@"|grep --color -E -e$ -e"(${break_words})"

			fi
			logecho "######################################### break at$(date)"
			logecho "######################################### break lineNo:${BASH_LINENO[0]} $@"
		fi
		logecho "enter :次のブレークポイントへ"
		logecho "f or q + enter :finallyして終了"
		while true;do
			read res;
			if [[ $res == "" ]];then
				logecho "######################################### break end lineNo:${BASH_LINENO[0]} $@"
				break;
			elif [[ $res =~ (f|q) ]];then
				backup_202511_finally
			fi
		done
	fi
}

COMMAND_CONFIRM_OFF=0
COMMAND_CONFIRM_EXECUTE=0
COMMAND_CONFIRM_CANCEL=1
function command_confirm(){
	print_info(){
		logecho -h <<-EOS
				e + enter :このコマンドを実行する $($is_sim && echo "(オプション[--execute]が指定されてないから実行したフリだけ)")
				l + enter :対象ファイルを一覧する
				c + enter :キャンセルして次のファイルへ
				f or q + enter :キャンセルして終了
				EOS
	}
	if $is_command_confirm ;then
		logecho ""
		logecho "######################################### confirm $1 : $2"
		print_info
		while true;do
			read res;
			if [[ $res == "e" ]];then
				logecho -n "######################################### confirm choiced : execute"
				return $COMMAND_CONFIRM_EXECUTE
			elif [[ $res == "l" ]];then
				logecho "######################################### confirm print : list"
				logecho "====== 指定されたパス一覧"
				logecho -h <<-EOS
					$(printf "%s\n" ${source_home_list[@]})
					EOS
				logecho "====== バックアップ対象ファイル一覧"
				logecho -h <<-EOS
					$(printf "%s\n" ${source_path_list[@]})
					EOS
				logecho "######################################### confirm print : list end"
				print_info
			elif [[ $res == "c" ]];then
				logecho -n "######################################### confirm choiced : cancel"
				EXCEPTION+=("${source_path}のバックアップはconfirm時にキャンセルされたぞ")
				return $COMMAND_CONFIRM_CANCEL
			elif [[ $res =~ (f|q) ]];then
				EXCEPTION+=("${source_path}のバックアップはconfirm時にキャンセルされたぞ")
				backup_202511_finally
			else
				printf "\e[1A%*s\r" $COLUMNS
			fi
		done
	else
		return $COMMAND_CONFIRM_OFF
	fi
}

function print_status(){
	# mode:までで53文字+${#mode_at_status}>$COLUMNS then $((53+${#mode_at_status}/$COLUMNS))+$((53+${#mode_at_status%$COLUMNS>0}))then +1
	#status_lines=0;
	#max_chars=53
	#max_chars=57
	trimed_mode_at_status=


	console_ctrl #$CCTRL_WIN_SIZE
	#if (((max_chars+${#mode_at_status})>=${COLUMNS}));then
	#	trimed_mode_at_status=${mode_at_status:0:$(($COLUMNS-max_chars-3))}
	#	colomn_end=">"
	#else
	#	trimed_mode_at_status=${mode_at_status}
	#	colomn_end=
	#fi
	#printf "\033[%d;%dr" "$LINES" "$LINES"
	console_lines=$LINES
	printf "\e7\e[%d;1#!/usr/bin/bash

#BACKUP_SOURCE_ROOT=/home/backup
BACKUP_SOURCE_specified=
BACKUP_DEST_HOME=/home/backup/dest/home
#BACKUP_DEST_HOME=/home/backup
BACKUP_DEST_ROOT=${BACKUP_DEST_HOME}/backup_root




if [[ $(whoami) == root ]];then
	LOG_FILE=/backup_shell_202511/tmp/backup_sudo_log
	LOG_TMP_FILE=/backup_shell_202511/tmp/backup_log_sudo_tmp
else
	LOG_FILE=/backup_shell_202511/tmp/backup_log
	LOG_TMP_FILE=/backup_shell_202511/tmp/backup_log_tmp

	while true;do
		read -p"sudo権限がついてないけど実行する？ e + enter で続行:" res
		if [[ $res == e ]];then 
			break
		else
			if [[ "${BASH_SOURCE[0]}" != "$0" && "${FUNCNAME[@]}" == *source ]]; then
				# ソース実行
				echo ソース実行
				return
			else #if [[ "${FUNCNAME[@]}" == *main ]]; then
				echo スクリプト実行
				exit
			fi
		fi
	done

fi



TYPE_F=0
TYPE_HF=1
TYPE_D=2
TYPE_HD=3

EXCEPTION=()

function backup_202511_help(){
	echo "################# ${BASH_SOURCE##*/} help ###################"
	echo
	echo "-c  --source[=dir1,dir2,..dirN] : バックアップのソースを指定。カンマ区切り"
	echo "-i  --ignore[=word1,word2,..wordN] : 除外するワードを指定。カンマ区切り"
	echo "-s  --simulation : ログだけを表示で作成されるパスの確認 デフォ設定"
	echo "-e  --execute : 実際にバックアップをとる"
	echo "-d  --detail : 詳細なログを出力 (ログを減らして速度アップ"
	echo "    --whole_home : ${HOME}をすべてバックアップ @[${BACKUP_DEST_ROOT}/yyyyddmm/${HOME} ]"
	echo "    --bind_dir : ディレクトリの場合内部を見ずに[dir_name_bkyyyyddmm]のようにまとめる"
	echo "    --bind_hidden_dir : 隠しディレクトリの場合内部を見ずに[.hidden_dir_name_bkyyyyddmm]のようにまとめる"
	echo "    --only_dir : ディレクトリのみをfindする"
	echo "    --only_file : ファイルのみをfindする"
	echo "    --only_hidden : 隠しファイル/ディレクトリのみをfindする"
	echo "-f  --confirm : ファイル一つ一つ実行するか確認する "
	echo "-g  --grep[=regex] : egrep で対象ファイルの絞り込み。"
	echo "-G  --GREP : 大抵のバックアップファイルは [ _20[0-9]{10,12}$|bkup|~$ ]で絞り込み可能なためオプション化"
	echo "-l  --logfile : ログファイルのパスを指定 デフォ:[$LOG_FILE]"
	echo "-h  --help : helpを出力"
H" "$console_lines" # \e[%d;1H と \e[%dd は同じ意味"
	printf "\e[M" # カーソルの行を削除 #printf "\e[K" #カーソル位置から後ろを削除 (前は1K) #printf "%*s\r" $COLUMNS

	printf -vtrimed_mode_at_status "sub_files:%*d/%*d | sources:%*d/%*d | fail:%*d || mode:%s" 5 $excuting_source_count 5 $source_path_list_size 5 $excuting_source_root_count 5 $source_home_list_size 4 $fail_count $mode_at_status
	colm=${COLUMNS}
	if ((${#trimed_mode_at_status}>=colm));then
		colomn_end=">"
	else
		colomn_end=
	fi

	printf "%s\e[7m%s\e[0m" "${trimed_mode_at_status:0:$((colm-1))}" $colomn_end #実行中コンソール窓をサイズ変更するとバグる
	#printf "files:%*d/%*d | dirs:%*d/%*d | fail:%*d || mode:%s\e[7m%s\e[0m" 5 $excuting_source_count 5 $source_path_list_size 5 $excuting_source_root_count 5 $source_home_list_size 4 $fail_count $trimed_mode_at_status $colomn_end #実行中コンソール窓をサイズ変更するとバグる
	#printf "\033[%d;%dr" "1" "$((LINES-1))"
	printf "\e8"
}

function backup_202511_main(){
	# 未使用
	sigttstp_process(){
		local is_not_end=true
		while $is_not_end;do
			if $is_sig_tstop;then
				logecho "in the $FUNCNAME"
				ps |grep $FUNCNAME|cut -d' ' -f1|xargs fg
				sleep 1
				ps |grep ${BASH_SOURCE##*/}|cut -d' ' -f1|xargs kill -9
				return
			else
				backup_202511
				is_not_end=false
			fi
		done
	}
	backup_202511_init
	backup_202511
	backup_202511_finally
}

backup_202511_confirm
backup_202511_init
backup_202511
backup_202511_finally
