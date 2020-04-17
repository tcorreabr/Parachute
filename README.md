# Parachute

<p align="center">
  <img src="parachute.svg">
</p>

Look at your windows and desktops from above. I think the opening animation resembles a parachute opening too.

This *Kwin QML/Javascript* script was inspired by the excellent work of several projects like: [Kwin (Present Windows and Desktop Grid effects)](https://github.com/KDE/kwin), [kwinOverview](https://github.com/astatide/kwinOverview), [qOverview](https://gitlab.com/bharadwaj-raju/QOverview), [Gnome](https://www.gnome.org/), [Deepin](https://www.deepin.org/).

The most promising feature isn't implemented yet. I think that the possibility of working with *Plasma Activities* in a faster and more natural way can be game changing in their daily use. In the future, this script may allow you to insert/delete activities, move windows between them, etc. For now, it works with *Virtual Desktops* and just ignores activities because I think some changes in *Kwin's* source code may be needed for the support.

![](parachute.png)

## Installation

  ```
  git clone https://github.com/tcorreabr/Parachute.git
  cd Parachute
  kpackagetool5 --type KWin/Script --install .
  ```

## Usage

After activate the script in *Kwin Scripts* window you can use the default registered global shortcut **Ctrl+Super+D (Ctrl+Meta+D)** to show/hide *Parachute*.
  
You can also invoke the script with: *qdbus org.kde.kglobalaccel /component/kwin invokeShortcut Parachute*. That way you can use it with *Easystroke*, for example.

Mouse buttons:
* Left button - Select window.
* Middle button - Close window.
* Right button - (Un)pin window.

## Notes

* Developed and tested in *Plasma* 5.18, but **not ready for daily use**.
* Not tested on *Wayland*. I'm pretty sure it doesn't work on it.
* If you are going to contribute to the code, please contact me first so that we don't have duplicate work. Unless it's a small contribution.
* If you are using "Slide" animation to switch desktops, you may want to switch to "Desktop Cube Animation" to avoid some [unwanted visual effects](https://github.com/tcorreabr/Parachute/issues/1).
* For now, you have to [click on a empty desktop to show the backgrounds](https://github.com/tcorreabr/Parachute/issues/6).
* You can use KWin global shortcuts normally while using this script. To navigate between your desktops for example.

## Possible improvements

* Config dialog with internationalization support.
* Insert, move and delete *Plasma Activities* and *Virtual Desktops*.
* Option to work with *Plasma Activities* OR *Virtual Desktops*.
* Option to top/left/right/bottom desktops bar positioning.
* Option to enable/disable background blur.
* More plasma theming support.
* Click on desktops bar to animate it to fullscreen (simulating *Kwin's Desktop Grid* effect).
* One more shortcut to show/hide the script in this *Desktop Grid* like mode.

