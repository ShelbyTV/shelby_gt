var tag = document.createElement('script');
tag.src = "http://www.youtube.com/player_api";
var firstScriptTag = document.getElementsByTagName('script')[0];
firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

var iframes=document.getElementsByTagName("iframe");

var currentVideo = null;

function onPlayerReady(event) {
  //event.target.playVideo();
  console.log("ready")
}

var done = false;

function stopVideo() {
  player.stopVideo();
}


function onYouTubePlayerAPIReady() {
  for (var i = 0; i < iframes.length; i++) {
    if (iframes[i].src.match("youtube")) {
    //iframes[i].src = "http://www.youtube.com/embed/uQtjU1a5wKo"
    var playerNode = document.createElement("div");
    playerNode.id="player" + i
    //iframes[i].parentNode.replaceChild(playerNode, iframes[i]) 
   // var player;
      iframes[i].parentNode.replaceChild(playerNode, iframes[i]);
        var player = new YT.Player("player" + i, {
          height: iframes[i].height,
          width: iframes[i].width,
          videoId: "vXu1lEa-NuQ",
          events: {
            'onReady': onPlayerReady,
            'onStateChange': function(value) {
              return function() {
                currentVideo = value;
                console.log("current vid is " + currentVideo);
              }
            }(i)
              
          }
        });

    }
  }
}

