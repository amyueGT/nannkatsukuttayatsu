#!/usr/bin/bash


archive_home_dir='/archive/home/dir'
archive_source_dir="${archive_home_dir}/archive/source/dir" #like this: twitter-yyyy-mm-dd-hash_num
archive_data_dir=${archive_source_dir}/data
tweets_files=tweets*.js


###
### 実行モード（テスト実行）　開始日、終了日、検索ワード（AND、OR）、アーカイブディレクトリ　dataディレクトリ　出力ファイル
###
output_file_name=output_list_$(date +'%Y%m%d%H%M%S')
date_default="1970/01/01"
input_date_begin=$date_default
input_date_end=""
and_search_word=""
and_search_word_length=0
or_search_word=""
or_search_word_length=0
mode=""

for arg in $@;do
	if [[ $arg =~ -m ]];then
		mode=${arg#-m}
		if [[ $mode =~ trace ]];then
			set -o xtrace
		fi
		continue;
	fi
	if [[ $arg =~ -hoem_dir ]];then
		archive_home_dir=${arg#-home_dir}
		continue;
	fi
	if [[ $arg =~ -source_dir ]];then
		archive_source_dir=${arg#-source_dir}
		continue;
	fi
	if [[ $arg =~ -output ]];then
		output_file_name=${arg#-output}
		continue;
	fi
	if [[ $arg =~ (-d|-date|-b|-begin) ]];then
		input_date_begin=${arg#-[d|b]}
		if [[ $input_date_begin =~ (-d|-b) ]]; then
			input_date_begin=${arg#-date}
		fi
		if [[ $input_date_begin =~ (-date|-begin) ]]; then
			input_date_begin=${arg#-begin}
		fi
		if [[ -z $input_date_begin ]]; then
			input_date_begin=$date_default
		fi
		continue;
	elif [[ $arg =~ (-e|-end) ]];then
		input_date_end=${arg#-e}
		if [[ $input_date_end =~ (-end) ]]; then
			input_date_end=${arg#-end}
		fi
		continue;	
	fi
	if [[ $arg =~ -or ]];then
		or_search_word=${arg#-or}
		or_search_word_length=${#or_search_word}
		continue;
	fi
	if [[ $arg =~ -and ]];then
		and_search_word=${arg#-and}
		and_search_word_length=${#and_search_word}
		continue;
	fi
done


function organaizeDateStr(){ #日時文字列と変数名を引数 "organaizeDateStr begin/end $変数名(yyy/dd~) 変数名"
	echo -n run organaizeDateStr:
	local beginend=$1
	local target=$2
	local minsec=:00
	local hour=' 00'
	if [[ $beginend == 1 ]];then
		minsec=:59
		hour=' 23'
	fi


	local reg_year_month='[0-9]{4}/[0-9]{1,2}'
	local reg_day='/[0-9]{1,2}'
	local reg_hour='\ [0-9][1,2]'
	local reg_min=':[0-9]{1,2}'
	local reg_sec=':[0-9]{1,2}'
#	echo $reg_year_month$reg_day$reg_hour$reg_min$reg_sec

	if [[  $target =~ $reg_year_month$reg_day$reg_hour$reg_min$reg_sec ]];then
		echo -n match1:;
		echo -n ${BASH_REMATCH[0]};
	elif [[ $target =~ $reg_year_month$reg_day$reg_hour$reg_min ]];then
		echo -n match2:;
		echo -n ${BASH_REMATCH[0]};
		target="$target$minsec"
	elif [[ $target =~ $reg_year_month$reg_day$reg_hour ]];then
		echo -n match3:;
		echo -n ${BASH_REMATCH[0]};
		target="$target$minsec$minsec"
	elif [[ $target =~ $reg_year_month$reg_day ]];then
		echo -n match4:;
		echo -n ${BASH_REMATCH[0]};
		target="$target$hour$minsec$minsec"
	elif [[ $target =~ $reg_year_month ]];then
		echo -n match5:;
		echo -n ${BASH_REMATCH[0]};
		if [[ $beginend == 1 ]];then
			#翌月1日00:00:00のepoch秒から-1で月末日時を求める
			local year=`echo $target|awk 'BEGIN{FS="/"} {print $1}'`
			local month=`echo $target|awk 'BEGIN{FS="/"} {print $2}'`
			month=$((month+1))
			if (( month > 12 ));then
				year=$((year+1))
			fi
			target=`date -d"$year$month/1" +"%s"`
			target=$((target-1))
			target=`date -d"@$target"`
		else
			target="$target/1$hour$minsec$minsec"
		fi
	else
		echo "date fromat is wrong. arg style-> 'yyyy/mm/dd hh:mm:ss' or 'yyyy/mm'"
		return 1
	fi
	echo -n "\$3=$3"
	eval "$3='$target'"
	echo end
}


declare -a list
function outputTweetList(){
	echo call outputTweetList

	list="$1"
	#list=`echo -e $list|sort`
	echo -e "list=$list"
	list=$(echo -e "${list}"|sort -r|uniq)
	echo -e "list=$list"
	list=`echo -e "$list"|awk 'BEGIN{ FS=",," } {print $2"\n"$3"\n\n";}'`


	echo
	echo ===head 
	eval "echo -e \"${list}\"|head"
	echo
	echo
	echo ===tail
	eval "echo -e \"${list}\"|tail"

	echo ========updated at:$(date) >$archive_home_dir/$output_file_name
	echo -e "${list}" >> $archive_home_dir/$output_file_name
	echo end outputTweetList
}


pipe_or_grep=""
pipe_and_grep=""
function makePipeCommand(){
	echo call makePipeCommand
	echo "or_search_word= $or_search_word"
	echo "and_search_word= $and_search_word"


	pipe_cat_grep="|grep -E --color=no -ecreated_at -e'^\s{6}\"id_str\"' -efull_text"
	pipe_grep_awk="|awk 'BEGIN{ FS=\" : \"; } {
			gsub(/\,|\"/,\"\");
			if(match(\$0,\"id_str\")){
				printf\"\\\"\";
				printf\"http://twitter.com/amyueGT/status/%s\",\$2;
				printf\",,\";
			}else if(match(\$0,\"create\")){
				printf\"%s\",\$2;
				printf\",,\";
			}else if(match(\$0,\"full_text\")){
				printf\"%s\",\$2;
				printf\"\\\"\";
				printf\"%s\",RS;
			}}'"

	pipe_command=${pipe_cat_grep}${pipe_grep_awk}
	echo "pipe_command= ${pipe_command}"
	local tweets=""

	if (( or_search_word_length>0 ));then
		pipe_or_grep="|grep -E `echo ${or_search_word//\,/\ }|sed "s/\([[:alnum:][:punct:][:graph:]]*\)/\-e,,.*\\\1.*/g"`" #grep用
		echo "pipe_or_grep= ${pipe_or_grep}"
	fi
	if (( and_search_word_length>0 ));then
		pipe_and_grep="`echo ${and_search_word//\,/\ }|sed "s/\([[:alnum:][:punct:][:graph:]]*\)/\|grep -E \-e,,.*\\\1.*/g"`" #grep用
		echo "pipe_and_grep= ${pipe_and_grep}"
	fi
	echo makePipeCommand end
}


list_length=0
function getList(){
	echo call getList

	local file=$1
	echo "reading file : $file"
	echo "\$2=$2" "\$3=$3" "\$4=$4" "\$5=$5" "\$6=$6"
	rt=">"
	repeat=$2
	if (( repeat > 0 ));then rt='>>'; fi

	#local twitter_date_format='+%a %b %d %H:%M:%S %z %Y'
	local output_date_format='+%Y/%m/%d %H:%M:%S'


	echo input_date_begin=$input_date_begin input_date_end=$input_date_end
	if (( input_date_begin>input_date_end ));then echo end date is before than begin date. end shell ;return; fi
	

	local created_date=""
	local tweet_url
	local id=""

	command_file_cat="cat ${file}"
	command=${command_file_cat}${pipe_command}
	local tweets=""
	if (( and_search_word_length <= 0 && or_search_word_length <= 0 ));then
		echo "eval execute: ${command}"
		search_result+="`eval ${command}`"
	fi
	if (( or_search_word_length>0 ));then
		command+=${pipe_or_grep}
		echo "eval execute: ${command}"
		or_search_result="`eval ${command}`"
		echo -n or_search_result chars:${#or_search_result}
		echo -n " "or_search_result lines:`echo -e "$or_search_result"|wc -l `
		echo " "${file##*/}
		echo ↓↓↓or_search_result↓↓↓
		echo "${or_search_result}"
		echo or_search_result end
	fi
	command=${command_file_cat}${pipe_command}
	if (( and_search_word_length>0 ));then
		command+=${pipe_and_grep}
		echo "eval execute: ${command}"
		and_search_result="`eval ${command}`"
		echo -n and_search_result chars:${#and_search_result}
		echo -n " "and_search_result lines:`echo -e "$and_search_result"|wc -l `
		echo " "${file##*/}
		echo ↓↓↓and_search_result↓↓↓
		echo "${and_search_result}"
		echo and_search_result end
	fi

	# レコードセパレータRSを差し込むにはechoしかなかった
	tweets=$(echo "$search_result";echo "$or_search_result";echo "$and_search_result")
	tweets=$(echo "$tweets"|grep -v ^$)
	
	eval echo ${file##*/} ${#tweets} update at:$(date) $rt $archive_home_dir/grep_lines
	echo "${tweets}" >> $archive_home_dir/grep_lines
	echo make list
	local total_l=`wc -l <(echo -e "$tweets")|awk 'BEGIN{FS=" "} {print $1}'`
	echo total_l=$total_l
	local count=0;
	while read -r line;
	do
		line=$(echo "$line"|xargs echo) #クォーテーション外し
		echo grep line: $line
		
		created_date=`echo ${line}|awk 'BEGIN{FS=",,"} {printf"%s\n",$2}'`
		echo -n created_date=$created_date 
		created_date=$(date -d"$created_date" +'%s')
		echo -n " -->to epochsec: $created_date"
		if (( created_date < input_date_begin || created_date > input_date_end ));then
			echo " --> out of date. continue"
			continue;
		fi
		echo "" #改行を差し込むためのエコー
		tweet_url=`echo ${line}|awk 'BEGIN{FS=",,"} {print $1}'`
		tweet_text=`echo ${line}|awk 'BEGIN{FS=",,"} {print $3}'`

		additional=""
		if [[ $tweet_text =~ 休み ]];then
			additional=::発言休み
		fi
		#echo ===== $created_date $tweet_url =====
		line="$created_date,,発言日:$(date -d"@$created_date" "$output_date_format")$additional,,$tweet_url\n"
		echo " --> rewrited: $line"

		list+="$line"
		((list_length++))

	done<<EOF
		$tweets
EOF
	echo end getList
}


function getTweetFiles(){
	echo run getTweetFiles
	arr=(`find $archive_data_dir/$tweets_files|awk 'ORS=" " {print}'`);
	eval "$1=(${arr[@]})"
}


echo "\$1=$1" "\$2=$2" \$3="$3" \$4="$4" #"\$5=$5"



repeat=0
grep_result=""

#local input_date_begin=`LANG=ja_US.UTF-8 date -u -d"$2" +'%a %b %d %H:%M:%S %z %Y'`
#local input_date_end=`LANG=ja_US.UTF-8 date -u -d"$3" +'%a %b %d %H:%M:%S %z %Y'`
if [[ -z $input_date_end ]];then input_date_end="$input_date_begin"; fi
if [[ ! $input_date_begin =~ ^[0-9]$ ]];then
	echo input_date_begin=$input_date_begin input_date_end=$input_date_end
	organaizeDateStr 0 $input_date_begin input_date_begin
	if [[ $? > 0 ]];then echo fail organizeDateStr. end shell;return 1; fi
	organaizeDateStr 1 $input_date_end input_date_end
	if [[ $? > 0 ]];then echo fail organizeDateStr. end shell;return 1; fi
	echo input_date_begin=$input_date_begin input_date_end=$input_date_end
	input_date_begin=`date -d"$input_date_begin" +'%s'`
	input_date_end=`date -d"$input_date_end" +'%s'`
fi

makePipeCommand

declare -a files
getTweetFiles files
for file in ${files[@]};
do
	getList "$file" $repeat
	if [[ $? > 0 ]];then return;fi
	((repeat++))

	file=${file##*/}
	echo or_search_result:liines ${#or_search_result}
	echo and_search_result:liines ${#and_search_result}

done
echo loop end

outputTweetList "${list}" #"${list[@]}"

echo ==========================================
echo
echo
echo list:${#list}
echo list_length=$list_length

echo output_file_name=$archive_home_dir/$output_file_name

echo files:${files[@]}
unset files


unset list
if [[ $mode =~ trace ]];then
	set +o xtrace
fi
