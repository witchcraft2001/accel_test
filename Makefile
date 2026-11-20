.PHONY: all exe img run test clean

all: exe

exe:
	tools/build.sh

img: exe
	tools/image.sh

# MAME window, the image on B: (type B:\ACCTEST.EXE in the DSS file manager)
run: img
	tools/run_mame.sh run build/acctest.img

# MAME without a window: runs B:\ACCTEST.EXE /A /Q, collects the log and screenshots
test: img
	tools/run_mame.sh test build/acctest.img build/ACCTEST.sym

clean:
	rm -rf build
