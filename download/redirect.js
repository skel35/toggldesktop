var basePath = '/toggldesktop/download/';
var pathName = window.location.pathname;
if (pathName.startsWith(basePath)) {
  var platformChannel = pathName.substring(basePath.length);
  if (platformChannel == 'windows64-dev/') {
    location.href = 'https://github.com/toggl-open-source/toggldesktop/releases/download/v7.4.1023/TogglDesktopInstaller-7.4.1023.exe';
    setTimeout(() => {
      close();
    }, 4000);
  }
}