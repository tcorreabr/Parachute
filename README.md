# Parachute

<p align="center">
  <img src="parachute.svg">
</p>

Look at your windows and desktops from above.

This *KWin* script was inspired by the excellent work of several projects like: [KWin (Present Windows and Desktop Grid effects)](https://github.com/KDE/kwin), [kwinOverview](https://github.com/astatide/kwinOverview), [qOverview](https://gitlab.com/bharadwaj-raju/QOverview), [Gnome](https://www.gnome.org/), [Deepin](https://www.deepin.org/).

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
* Left mouse button - Activate window.
* Middle mouse button - Close window.
* Right mouse button - (Un)pin window.
* Arrow keys - Select a window.
* Home/End - Select first/last window.
* Enter - Activate selected window.
* Esc - Hide Parachute.
* F5 - Update settings.

## Notes

* Developed and tested in *Plasma* >= 5.18 and *Qt* >= 5.14.
* For now it doesn't work on *Wayland*.
* For now you may have to [click on a empty desktop to show it's wallpaper](https://github.com/tcorreabr/Parachute/issues/6). This should be fixed only when *KWin* 5.20 arrives.
* You can use *KWin's* global shortcuts normally while using this script. To navigate between your desktops for example.
* If you are using "Slide" animation to switch desktops, you may want to switch to "Desktop Cube Animation" or "Fade Desktop" to avoid some [unwanted visual effects](https://github.com/tcorreabr/Parachute/issues/1).
* If you are having poor performance on animations, try to change "Scale method" to "Smooth" or "Crisp" in Compositor settings.
* If you have [Virtual Desktop Bar](https://github.com/wsdfhjxc/virtual-desktop-bar) installed, [Parachute keyboard shortcut may be ineffective](https://github.com/tcorreabr/Parachute/issues/14) until KWin restart or dynamic desktop operations.

## Possible improvements

* Insert, move and delete *Plasma* activities and virtual desktops. This should be supported only when *KWin* 5.20 arrives.
* More *Plasma* theming support.
* Click on desktops bar to animate it to fullscreen (simulating *KWin's* Desktop Grid effect).
* One more shortcut to invoke Parachute in this Desktop Grid like mode.
