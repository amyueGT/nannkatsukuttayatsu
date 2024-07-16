const fs = require('fs');
// const readLine = require('readline');
// // const fetch = require('node-fetch');
// const { JSDOM } = require("jsdom");
// const dom = new JSDOM(`<!DOCTYPE html><div id="message">Hello world</div>`);


let currentWorkingDirectory = process.cwd();
console.log(currentWorkingDirectory);


// let file = "./tweets-part1.js";
// let reader = new FileReader();
// reader.readAsText(file);

// var file = fs.readFileSync("./tweets-part1.js",'utf8').toString();


function lengthSort(a,b){
	return a.length - b.length;
}
function numberSort(a,b){
	let an,bn;
	bn=parseInt(b.charAt(b.length-1))
	return an=parseInt(a.charAt(a.length-1))?an-bn:true;
}
function csvSort(a,b){
	return parseInt(b[3].substring(4,b[3].length-1))-parseInt(a[3].substring(4,a[3].length-1));

}
function countChars(a,b){
	let chars={};
	// let inputFile=process.argv[2];
	let inputFile=fs.readFileSync('./tweets.csv','utf8').toString();

	inputFile.split('\n').forEach(f=>{
		let line=f.split(',');
		for(l=0;l<line[0].length;l++){
			// for(c=0;c<chars.length;c++){
			let key=line[0].charAt(l);
		  if(chars[key]=== undefined)chars[key]=1;
		  else chars[key]++;
			// }
		}
	})

	// let r=Object.entries(chars);エントリーでソートされない
	// console.log(r);
	// r.sort((a,b)=>{
	// 	const [key,value]=a;
	// 	[keyB,valueB]=b;
	// 	// console.log(a[0]+' : '+b[0]+' '+a[1]+' : '+b[1]+' '+key+' : '+value+' '+keyB+' : '+valueB);
	// 	return value<valueB;
	// 	}
	// );
	// console.log(r);
	// // console.log(chars);

	let arr = Object.keys(chars).map((e)=>({ key: e, value: chars[e] }));
	// console.log(arr);
	arr.sort((a,b)=>{
		// console.log(a.key+' : '+a.value+' '+b.key+' : '+b.value);
		return a.value<b.value;
	});
	console.log(arr);
	arr.sort(function(a,b){
	  if(a.value < b.value) return 1;
	  if(a.value > b.value) return -1;
	  return 0;
	});
	console.log(arr);
	let result="";
	// for([key,value] in Object.entries(r)){
	arr.forEach((a)=>{
		// result+=k+" : "+ chars[k]+(key%10==0?"\n":"");
		result+=a.key+" : "+ a.value+"\n";
	})
	// console.log('result:'+result);
	fs.writeFile('./文字カウント.txt', result, (err) => {
										if (err) throw err;
										console.log('./文字カウント.txt作成おっけ');
									});
}


// let inputFile=process.argv[2]
let inputFile=fs.readFileSync('./tweets.csv','utf8').toString();
// csv[0]tweet,csv[1]日本語日付,csv[2]ミリ秒,csv[3]ツイートid:

let tmp=null;
let stuck=null;
inputFile.split('\n').forEach((ln,index)=>{
	console.log("index:"+index);
	start=null;
	let line=ln.split(',');
	if(stuck==null){
		stuck=line;
	}else{
		let s=stuck[0].length-1;
		let l=line[0].length-1;
		let shead=stuck[0].length-line[0].length;

		while(s>=shead&&l>=0){

		// for(s=stuck[0].length-1;s>=stuck[0].length-line[0].length;s--){
		// 	// console.log("s:"+s);
		// 	for(l=line[0].length-1;l>=0;l--){
		// 		// console.log("l:"+l);
				
				if(line[0].charAt(l)==stuck[0].charAt(s)){
					
					start=l;
					while(s>=shead&&l>=0&&line[0].charAt(l)==stuck[0].charAt(s)){
						s--;l--;
					}

					if(s-(stuck[0].length-line[0].length)<=10){//&&l=<10){
						let date=stuck[1].split(',');
						let mil=stuck[2].split(',');
						let id=stuck[3].split(',');

						stuck[0]+=l!=0||start-l<10?"\n（結合失敗）\nここまで 日付:"+date[date.length-1]+" 末尾の発言id:"+id[id.length-1]+"\n次の発言 日付:"+line[1]+" 次の発言id:"+line[3]+"\n"+line[0]:line[0].substring(start,line[0].length-1);
						stuck[1]+=","+line[1];
						stuck[2]+=","+line[2];
						stuck[3]+=","+line[3];

						s=stuck[0].length-1;
						
						// console.log("stuck[0].length:"+stuck[0].length);
					}else if(start-l<5){//||l!=0)

					}
			// 	}
		}
			
		}
	}
})
	fs.writeFile('./結合.txt', stuck[0].toString(), (err) => {
										if (err) throw err;
										console.log('./結合.txt作成おっけ');
									});


function makeCsvorTxt(mode){
	let fileName=new Array();

	fs.readdir("./", (err, files) => {
		let pattern=new RegExp(/^tweets(-part)?\d?\.js/g);
		files.forEach(f=> {
			if(f.match(pattern))fileName.push(f);
		})


		// fileName.push("tweets-part30.js");
		// fileName.push("tweets-part15.js");
		// fileName.push("tweets-part8.js");
		// console.log(fileName);

		fileName.sort(lengthSort);
		fileName.sort(numberSort);

		// console.log(fileName);


	    // for (let index = 0; index < filesR.length-1; index++) {
	    //     const element = filesR[index];
	    //     const file = fs.readFileSync(path+element, { encoding: "utf8" }, (err, file) => {});
	    //     fs.appendFileSync("./docs/index.md", file+"\n"+element.replace(".md","")+"\n"+"<hr>"+"\n", (err) =>{
	    //         if (err) throw err;
	    //         console.log("書き込みOK！");
	    //     })
	    // }
	let csv=[];
	console.log("fileName[0]:"+fileName[0]);
	fileName.forEach(f=> {
		console.log(f);

			let file = fs.readFileSync(f,'utf8').toString();
			var i=0;
			while(1){
				if(file.charAt(i)=='{')break;
				i++;
			// {}
			}
			// console.log(i);
			// console.log(file.length);
			// console.log(file.charAt(0));
			// console.log(file.charAt(i));

			// let obj=eval(file.substring(file.charAt(i),file.charAt(--file.length)));
			// console.log(typeof obj);
			var end=0;

			var start=i;
			let obj=new Array();
			let parentheses=0;
			// while(i!=file.length){
			while(file.charAt(start)=='{'){
				if(file.charAt(i)=='{')parentheses++;
				if(file.charAt(i)=='}')parentheses--;
				if(parentheses==0){
					obj.push(file.substring(start,i+1));
					start=i;
					while(file.charAt(start)!='{'&&start<file.length)start++;
					i=start;
			// {}
					// if(file.charAt(start+1)==','&&file.charAt(start+2)=='{')start+=2;
						/*break;
						}*/
					// start=++i;
				}else{i++;}
			}
			console.log("${file}obj作成完了");
			/*	console.log(start);
					console.log(file.charAt(i));
					console.log(file.charAt(start));
					console.log(obj.length);
					console.log("----------");
					if(obj.length>3){*/
						// let csv=[];
						obj.forEach(function( json ) {
							let tweet=JSON.parse(json).tweet;
							let date = new Date(Date.parse(tweet.created_at));
							let weekday = ['日','月','火','水','木','金','土'];
							let hour=date.getHours();
							// let tw =[tweet.full_text.replace("\n","\\n"),(hour/12 >1?"午後":"午前")+hour%12+':'+date.getMinutes()+' · '+date.getFullYear()+'年'+(date.getMonth()+1)+'月'+date.getDate()+'日',date.toString(),'ミリ秒:'+date.getTime(),'ツイートid:'+tweet.id]
							
							let tw =[new String(tweet.full_text),(hour/12 >1?"午後":"午前")+hour%12+':'+date.getMinutes()+' · '+date.getFullYear()+'年'+(date.getMonth()+1)+'月'+date.getDate()+'日',date.toString(),'ミリ秒:'+date.getTime(),'ツイートid:'+tweet.id]



							csv.push(tw);
						});
						// console.log(csv.join("\n"));
						csv.sort(csvSort);

						// console.log("currentfile:"+(f));
						// console.log("fileName[0]:"+(fileName[0]));
						// console.log("currentfile==fileName[0]:",f===fileName[0]);
						// if(f==fileName[0]){
						// 	fs.writeFile('./tweets.csv', csv.join("\n"), (err) => {
						// 		if (err) throw err;
						// 		console.log('ファイル一つ目完了');
						// 	});
						// }else{
						// 	fs.appendFile('./tweets.csv', csv.join("\n"), (err) => {
						// 		if (err) throw err;
						// 		console.log('The file has been saved!');
						// 	});
						// }
		})
		csv.sort(csvSort);
		let resultFile='./tweets.csv';
		let resultlog='csv出力完了';

		// if(process.argv[2]=="txt"){
		if(mode=="txt"){
			resultFile='./tweets.txt';
			resultlog='txt出力完了';
			csv.forEach((tweet,index,array)=>{
				// let tweet=row.split(',');
				array[index]=tweet[0]+'\n'+tweet[1]+' | '+tweet[2]+' | '+tweet[3]+' | '+tweet[4];
			})
		}
		fs.writeFile(resultFile, csv.join("\n"), (err) => {
									if (err) throw err;
									console.log(resultlog);
								});


	});
}

/*
var i=0;
while(1){
	if(file.charAt(i)=='{')break;
	i++;
// {}
}
console.log(i);
console.log(file.length);
console.log(file.charAt(0));
console.log(file.charAt(i));

// let obj=eval(file.substring(file.charAt(i),file.charAt(--file.length)));
// console.log(typeof obj);
var end=0;

var start=i;
let obj=new Array();
let parentheses=0;
// while(i!=file.length){
while(file.charAt(start)=='{'){
	if(file.charAt(i)=='{')parentheses++;
	if(file.charAt(i)=='}')parentheses--;
	if(parentheses==0){
		obj.push(file.substring(start,i+1));
		start=i;
		while(file.charAt(start)!='{'&&start<file.length)start++;
		i=start;
// {}
		// if(file.charAt(start+1)==','&&file.charAt(start+2)=='{')start+=2;
		
		console.log(start);
		console.log(file.charAt(i));
		console.log(file.charAt(start));
		console.log(obj.length);
		console.log("----------");
		if(obj.length>3){
			// console.log(obj);
			// let tweet=JSON.parse(obj[1]).tweet;
			// console.log(tweet.full_text);
			// // console.log(new Date(tweet.created_at));
			// var date = new Date(tweet.created_at);
			// var date = new Date(Date.parse(tweet.created_at));
			// let weekday = ['日','月','火','水','木','金','土'];
			// let hour=date.getHours();
			// console.log((hour/12 >1?"午後":"午前")+hour%12+':'+date.getMinutes()+' · '+date.getFullYear()+'年'+date.getMonth()+'月'+date.getDate()+'日');
			// console.log(date.toString());
			// console.log('ミリ秒:'+date.getTime());
			// console.log('ツイートid:'+tweet.id);
			// console.log();


			let csv=[];
			obj.forEach(function( json ) {
				let tweet=JSON.parse(json).tweet;
				let date = new Date(Date.parse(tweet.created_at));
				let weekday = ['日','月','火','水','木','金','土'];
				let hour=date.getHours();
				let tw =[tweet.full_text.replace("\n","\\n"),(hour/12 >1?"午後":"午前")+hour%12+':'+date.getMinutes()+' · '+date.getFullYear()+'年'+date.getMonth()+'月'+date.getDate()+'日',date.toString(),'ミリ秒:'+date.getTime(),'ツイートid:'+tweet.id]
				csv.push(tw);
			});
			
			console.log(csv.join("\n"));


			fs.writeFile('./tweets.csv', csv.join("\n"), (err) => {
				if (err) throw err;
				console.log('The file has been saved!');
			});

			break;
			}
		// start=++i;
	}else{i++;}
	
// {} ()
}*/
// console.log(obj[0]);
// // console.log(obj[obj.length-1]);

// let tweet=JSON.parse(obj[1]).tweet;
// console.log(tweet.full_text);
// // console.log(new Date(tweet.created_at));
// var date = new Date(tweet.created_at);
// var date = new Date(Date.parse(tweet.created_at));
// let weekday = ['日','月','火','水','木','金','土'];
// let hour=date.getHours();
// console.log((hour/12 >1?"午後":"午前")+hour%12+':'+date.getMinutes()+' · '+date.getFullYear()+'年'+date.getMonth()+'月'+date.getDate()+'日');
// console.log(date.toString());
// console.log('ミリ秒:'+date.getTime());
// console.log('ツイートid:'+tweet.id);




/*const path = "./posts/"

fs.readdir(path, (err, files) => {
  const filesR = files.reverse()
    for (let index = 0; index < filesR.length-1; index++) {
        const element = filesR[index];
        const file = fs.readFileSync(path+element, { encoding: "utf8" }, (err, file) => {});
        fs.appendFileSync("./docs/index.md", file+"\n"+element.replace(".md","")+"\n"+"<hr>"+"\n", (err) =>{
            if (err) throw err;
            console.log("書き込みOK！");
        })
    }
});
*/

// const options={
// 	year: "numeric",
// 	month:"numeric",
// 	day:"numeric",
//     hour: "numeric",
//     minute: "numeric",
//     hourCycle: "h12",
//     dayPeriod: "short",
//     timeZone: "UTC",
//   }

//   //午前0:09 · 2023年10月19日


// // let dateStr="Sat Feb 26 08:48:20 +0000 2022".split(" ");
// let dateStr="Sun Oct 01 19:14:44 +0000 2023";

// var date1 = new Date(Date.UTC(2012, 11, 20, 3, 0, 0));
// var date2 = new Date(Date.parse("Sat Feb 26 08:48:20 GMT+0000 2022"));

// var date3 = new Date(Date.parse("Sun Oct 01 19:14:44 +0000 2023"));

// let weekday = ['日','月','火','水','木','金','土'];
// console.log(dateStr);

// console.log(date3.getDay());
// console.log(weekday[date3.getDay()]);
// console.log(date3.getFullYear());
// console.log(date3.getMonth());
// console.log(date3.getDate());
// let hour=date3.getHours();
// console.log(hour/12 >1?"午後":"午前");
// console.log(hour%12);
// console.log(hour);
// console.log(date3.getMinutes());
// console.log(date3.getSeconds());
// console.log(date3.getTime());

// console.log(hour/12 >1?"午後":"午前"+hour%12+':'+date3.getMinutes()+' · '+date3.getFullYear()+'年'+date3.getMonth()+'月'+date3.getDate()+'日');

// // console.log(date3.);
// // console.log(date3.);
// // console.log(date3.);



// console.log();

// // toLocaleString without arguments depends on the implementation,
// // the default locale, and the default time zone
// console.log(new Intl.DateTimeFormat("ja-jp").format(date3));
// console.log(date2.toLocaleTimeString("ja-jp"),"ja-jp");


// input_format = '%a %b %d %H:%M:%S %z %Y'
// output_format = '%Y'

//  "created_at" 



// "+9時間"



// var json = JSON.stringify(file);
// console.log(JSON.parse(json)[1].tweet);
// obj.type='[object Array]';

// console.log(obj[0].tweet);
// var rl = readLine.createInterface({
//     input : fs.createReadStream(file),
//     output : process.stdout,
//     terminal: false
// });
// rl.on('line', function (text) {
//   console.log(text);
// });

// let obj=eval(text);
// .window.YTD.tweets.part0[0];

// console.log(file.substr(-1));
// var files = fs.readdirSync(currentWorkingDirectory);
// console.log(files);
// console.log(files[12]);
// let f="file://"+currentWorkingDirectory+"/"+files[12];

// fetch("https://www.google.co.jp/").then(o=>{return o.window.YTD.tweets.part0[0];}).then(t=>{console.log(t);});

// let fet =fetch("https://www.google.co.jp/");
// // let fet =fetch("/"+files[12]);
// 	fet.then(o=>{return o.window.YTD.tweets.part0[0]});
// 	fet.then(t=>{console.log(t);
//     // "t"にimport.jsのファイル内容が格納されているので
//     //eval(t); //その内容を実行する
// });