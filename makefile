PRG_NAME := SUPERBALL

ALL_ASM = $(wildcard *.asm) $(wildcard *.inc)

all: $(ALL_ASM)
	cl65 -t cx16 -o $(PRG_NAME).prg -l $(PRG_NAME).list $(PRG_NAME).asm
	@if [ -e $(PRG_NAME).prg ]; then \
		x16emu -scale 2 -debug -prg $(PRG_NAME).prg; \
	fi

clean:
	rm -f *.PRG *.list *.o
