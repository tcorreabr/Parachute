# Parachute

<p align="center">
  <img src="parachute.svg">
</p>

Look at your windows and desktops from above. I think the opening animation resembles a parachute opening too.

This *KWin* script was inspired by the excellent work of several projects like: [KWin (Present Windows and Desktop Grid effects)](https://github.com/KDE/kwin), [kwinOverview](https://github.com/astatide/kwinOverview), [qOverview](https://gitlab.com/bharadwaj-raju/QOverview), [Gnome](https://www.gnome.org/), [Deepin](https://www.deepin.org/).

The most promising feature isn't implemented yet. I think that the possibility of working with *Plasma* activities in a faster and more natural way can be game changing in their daily use. In the future, this script may allow you to insert/delete activities, move windows between them, etc. For now, it works with virtual desktops and just ignores activities because I think some changes in *KWin's* source code may be needed for the support.

![](parachute.png)

## Installation or upgrade

  ```
  git clone https://github.com/tcorreabr/Parachute.git
  kpackagetool5 --type KWin/Script --install ./Parachute || kpackagetool5 --type KWin/Script --upgrade ./Parachute
  ```

To install the configuration dialog you must execute the following commands, even if you have installed through Plasma's Get Hot New Stuff or [Kde Store](https://store.kde.org/). You only need to do this once.

  ```
  mkdir -p ~/.local/share/kservices5
  ln -s ~/.local/share/kwin/scripts/Parachute/metadata.desktop ~/.local/share/kservices5/Parachute.desktop
  ```

## Usage

After activate the script in *KWin Scripts* window you can use the default registered global shortcut **Ctrl+Super+D (Ctrl+Meta+D)** to show/hide *Parachute*.
  
You can also invoke the script with: *qdbus org.kde.kglobalaccel /component/kwin invokeShortcut Parachute*. Similarly you can: integrate it with [easystroke](https://github.com/thjaeger/easystroke), [configure it to be invoked with meta key](https://github.com/tcorreabr/Parachute/issues/30), etc.

Controls:
* Left mouse button - Select window.
* Middle mouse button - Close window.
* Right mouse button - (Un)pin window.
* Arrow keys - Navigate through windows.
* Home/End - Select first/last window.
* Enter - Select window.
* Esc - Deactivate Parachute.
* F5 - Reload config options.

## Notes

* Developed and tested in *Plasma* 5.18, but **not ready for daily use**.
* Not tested on *Wayland*. I'm pretty sure it doesn't work on it.
* If you are using "Slide" animation to switch desktops, you may want to switch to "Desktop Cube Animation" or "Fade Desktop" to avoid some [unwanted visual effects](https://github.com/tcorreabr/Parachute/issues/1).
* For now, you have to [click on a empty desktop to show the backgrounds](https://github.com/tcorreabr/Parachute/issues/6).
* You can use KWin's global shortcuts normally while using this script. To navigate between your desktops for example.
* If you have [Virtual Desktop Bar](https://github.com/wsdfhjxc/virtual-desktop-bar) installed, [Parachute keyboard shortcut may be ineffective](https://github.com/tcorreabr/Parachute/issues/14) until KWin restart or dynamic desktop operations.

## Possible improvements

* Insert, move and delete *Plasma* activities and virtual desktops.
* Option to work with *Plasma* activities OR virtual desktops.
* Option to top/left/right/bottom desktops bar positioning.
* More plasma theming support.
* Click on desktops bar to animate it to fullscreen (simulating *KWin's* Desktop Grid effect).
* One more shortcut to invoke Parachute in this Desktop Grid like mode.
