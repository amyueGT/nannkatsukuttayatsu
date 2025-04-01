#!/usr/bin/bash

##
## このシェルはツイッターのアーカイブファイルから日付本文を検索し日付とURLまたは某ブログサイト用のhtml形式で日付と本文をリストするシェル
## 基本的に自分用学習用。自分の程度の指標として見せる用
## ここまでの作成期間は2025年3月13日ぐらい?から2025年4月1日の18日ぐらい。作業日数は半分の9日ぐらい。
## 他に修正する可能性はヘルプとログを関数化と内容の整理ぐらい（？）
##

output_file_name=output_list_$(date +'%Y%m%d%H%M%S')
archive_home_dir='/archive/home/dir'
archive_source_dir="${archive_home_dir}/archive/source/dir" #like this: twitter-yyyy-mm-dd-hash_num
archive_data_dir=${archive_source_dir}/data
tweets_files=tweets*.js
account_file=account.js

list_length=0

###
### 実行モード（テスト実行）　開始日、終了日、検索ワード（AND、OR）、アーカイブディレクトリ　dataディレクトリ　出力ファイル
###
date_default="1970/01/01"
input_date_begin=$date_default
input_date_end=""
and_search_word=""
and_search_word_length=0
or_search_word=""
or_search_word_length=0
mode=""
mode_plane_url=1

for arg in $@;do
	if [[ $arg =~ -m ]];then
		mode=${arg#-m}
		if [[ $mode =~ trace ]];then
			set -o xtrace
		elif [[ $mode =~ plane|url ]];then
			mode=$mode_plane_url
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
	echo run outputTweetList

	list="$1"
	#list=`echo -e $list|sort`
	echo sort list
	list="$(echo -e "${list}"|sort -r|uniq)"
	echo -e "list=$list"
	list=`echo -e "$list"|awk 'BEGIN{ FS=",," } {print $2"\n"$3"\n\n";}'`


	echo
	echo ===head 
	echo -e "${list}"|head
	echo
	echo
	echo ===tail
	echo -e "${list}"|tail

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


	local awk_lineend_gsub=""
	local awk_url_gsub=""
	pipe_account_command=""
	if [[ ! $mode == $mode_plane_url ]];then
		pipe_account_command="|grep -e\"username\" -e\"accountDisplayName\""
		pipe_account_command+="|awk 'BEGIN{ FS=\" : \"; } {
			gsub(/\,|\"/,\"\");
			if(match(\$0,\"username\")){
				printf\"\\\"\";
				printf\"%s\",\$2;
				printf\",,\";
			}else if(match(\$0,\"accountDisplayName\")){
				printf\"%s\",\$2;
				printf\"\\\"\";
				printf\"%s\",RS;
		}'"
		echo "pipe_account_command= ${pipe_account_command}"

		#"https?://[a-zA-Z0-9\041\042\043\044\045\046\047\050\051\052\053\054\055\056\057\072\073\074\075\077\100\133\134\135\137\176]*"

		#\041 -> ! , #\042 -> " , #\043 -> # , #\044 -> $ , #\045 -> % , #\046 -> & , #\047 -> ' ,
		#\050 -> ( , #\051 -> ) , #\052 -> * , #\053 -> + , #\054 -> , , #\055 -> - , #\056 -> . ,　#\057 -> / ,
		#\072 -> : , #\073 -> ; , #\074 -> < , #\075 -> = , #\077 -> ? , 
		#\100 -> @ , #\133 -> [ , #\134 -> \ , #\135 -> ] , #\137 -> _ , 
		#\176 -> ~

		#awk_gsub_begin=" FS=\",,\"; url_reg=https?://[a-zA-Z0-9*\047\072();:@&=+$,/\?%25%22%23~-_\[!\].]*; "
		awk_gsub_begin='FS=",,"; url_reg="https?://[a-zA-Z0-9\041\042\043\044\045\046\047\050\051\052\053\054\055\056\057\072\073\075\077\100\133\134\135\137\176]*";';
		awk_gsub_chars="gsub(/%/,\"\\045\");"
		awk_gsub_lineend="gsub(/\\\n/,\"<br>\");${awk_gsub_chars}"
		
		#awk_gsub_gsub="gsub(/(https?[[:alnum:][:punct:]]*)/,\"\\<a href=\"\\1\">\\1\\</a\\>\");"
		#awk_gsub_gsub="gsub(/\\n/,\"<br>\");match(\$0,\"https?://[^<[:space:][^ぁ-んァ-ヴ０-９Ａ-Ｚ]]*\"); url=substr(\$0,RSTART,RLENGTH);printf(\"<a href=\"%s\">%s</a>\",url,url);"
		awk_gsub_url="if(match(\$0,url_reg)){ \
			url=substr(\$0,RSTART,RLENGTH); \
			html=\"<a href=\\\"\"url\"\\\">\"url\"</a>\"; \
			gsub(url,html,\$0);}"
			#gsub(/url_reg/,html,\$3);"

		pipe_awk_gsub_to_html="|awk 'BEGIN{ ${awk_gsub_begin} } { ${awk_gsub_lineend}${awk_gsub_url} print }'"
		echo pipe_awk_gsub_to_html= $pipe_awk_gsub_to_html
	fi

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


embed_text='<blockquote class=\"twitter-tweet\" data-conversation=\"none\" data-lang=\"ja\"><p lang=\"ja\" dir=\"ltr\">%s</p>&mdash; %s (%s) <a href=\"%s?ref_src=twsrc\0455Etfw\">%s</a></blockquote><p><script async src=\"https://platform.twitter.com/widgets.js\" charset=\"utf-8\"></script></p>'
function makeEmbedText(){
	tweet_date=$(date -d@$created_date $embed_tweet_date_format)
	embed_text=$(printf $embed_text $account_name $tweet_text)
}


#local twitter_date_format='+%a %b %d %H:%M:%S %z %Y'
output_date_format='+%Y/%m/%d %H:%M:%S'
embed_tweet_date_format='+%Y年%m月%d日'

function getList(){
	echo call getList

	local file=$1
	echo "reading file : $file"
	echo "\$2=$2" "\$3=$3" "\$4=$4" "\$5=$5" "\$6=$6"
	rt=">"
	repeat=$2
	if (( repeat > 0 ));then rt='>>'; fi


	echo input_date_begin=$input_date_begin input_date_end=$input_date_end
	if (( input_date_begin>input_date_end ));then echo end date is before than begin date. end shell ;return; fi
	

	local created_date=""
	local tweet_url=""
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

		additional_txt=""
		tweet_text=`echo ${line}|awk 'BEGIN{FS=",,"} {print $3}'`
		tweet_url=`echo ${line}|awk 'BEGIN{FS=",,"} {print $1}'`
		if [[ ! $mode == $mode_plane_url ]];then
			echo "eval echo '${tweet_text}'${pipe_awk_gsub_to_html}"
			tweet_text=`eval "echo '${tweet_text}'${pipe_awk_gsub_to_html}"`
			tweet_date=$(date -d@$created_date $embed_tweet_date_format)
			tweet_url=$(echo ${line}|awk 'BEGIN{FS=",,"} {print $1}')

			echo "printf \"${embed_text}\" \"${tweet_text}\" \"${account_name}\" \"${account_id}\" \"${tweet_url}\" \"${tweet_date}\""
			tweet_url="$(printf "${embed_text}" "${tweet_text}" "${account_name}" "${account_id}" "${tweet_url}" "${tweet_date}")"
		fi
		if [[ $tweet_text =~ 休み ]];then
			additional_txt=" &mdash; 発言休み"
		fi
		date_text="<p>発言日:$(date -d"@$created_date" "$output_date_format")$additional_txt</p>"

		line="${created_date},,${date_text},,${tweet_url}\n"
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
function getAccountFile(){
	echo run getAccountFile
	eval "$1=(`find $archive_data_dir/$account_file`);"
}

echo "\$1=$1" "\$2=$2" \$3="$3" \$4="$4" #"\$5=$5"


declare -a files
acnt_file=""
getTweetFiles files
getAccountFile acnt_file
repeat=0
grep_result=""

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
echo "cat \"${archive_data_dir}/${account_file}\"|grep username |awk 'BEGIN{ FS=\" : \" }{gsub(/\,|\"/,\"\"); printf(\$2) }'"
account_id=$(eval "cat \"${archive_data_dir}/${account_file}\"|grep username |awk 'BEGIN{ FS=\" : \" }{gsub(/\,|\"/,\"\"); print(\$2) }'")
echo eval "cat \"${archive_data_dir}/${account_file}\"|grep accountDisplayName |awk 'BEGIN{ FS=\" : \" }{gsub(/\,|\"/,\"\"); print(\$2) }'"
account_name=$(eval "cat \"${archive_data_dir}/${account_file}\"|grep accountDisplayName |awk 'BEGIN{ FS=\" : \" }{gsub(/\,|\"/,\"\"); print(\$2) }'")
echo account_id=$account_id  account_name=$account_name

for file in ${files[@]};
do
	getList "$file" $repeat
	if [[ $? > 0 ]];then return;fi
	((repeat++))

	file=${file##*/}
	echo or_search_result:liines ${#or_search_result}
	echo and_search_result:liines ${#and_search_result}

	grep_result+=$(echo ${or_search_result}|sort -r|awk "BEGIN{ FS=\",,\" }{printf\"%s,,%s\n\n\",\$2,\$1}")
	grep_result+=$(echo ${and_search_result}|sort -r|awk "BEGIN{ FS=\",,\" }{printf\"%s,,%s\n\n\",\$2,\$1}")
done
echo loop end

outputTweetList "${list}" #"${list[@]}"


echo -e `date`=====================search_result > $archive_home_dir/greped_tweets
echo -e "${grep_result}" >> $archive_home_dir/greped_tweets

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
