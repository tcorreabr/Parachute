PROJECT_VER = 0.9.1

install:
	git checkout v$(PROJECT_VER)
	kpackagetool5 --type KWin/Script --install . || kpackagetool5 --type KWin/Script --upgrade .
	mkdir -p ~/.local/share/kservices5
	ln -s ~/.local/share/kwin/scripts/Parachute/metadata.desktop ~/.local/share/kservices5/Parachute.desktop
	git checkout -

uninstall:
	kpackagetool5 --type KWin/Script --remove Parachute
