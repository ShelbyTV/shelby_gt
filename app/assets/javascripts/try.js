var tag = document.createElement('script')
tag.src = "http://localhost:3003/assets/jquery.js"
var tag2 = document.createElement('script')
tag2.src = "http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/jquery-ui.min.js"
var firstScriptTag = document.getElementsByTagName('script')[0];
firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
firstScriptTag.parentNode.insertBefore(tag2, firstScriptTag);



sidebar = document.createElement('div');
sidebar.style.position = 'fixed'; 
sidebar.style.bottom = '5px';
sidebar.style.left = '5px';
sidebar.id = "sidebar";
ul = document.createElement('ul');
for (var i = 0; i < 5; i++) {
  li = document.createElement('li');
  li.innerHTML = i + "a;slfj";
  ul.appendChild(li);
}
sidebar.appendChild(ul);
document.body.appendChild(sidebar);


iframes = document.getElementsByTagName("iframe")
var yt_links = new Array();
for (var i = 0; i < iframes.length; i++) {
  if (iframes[i].src.match("youtube")) {
    yt_links.push(iframes[i].src)
  }

}
