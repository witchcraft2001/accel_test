# ACCTEST — Sprinter accelerator test and benchmark

`ACCTEST.EXE` is a DSS program. It checks every accelerator command for correctness and measures how fast each one runs. Use it to:

- confirm that a new FPGA firmware is correct;
- compare its speed against the base firmware;
- decide whether drawing by rows or by columns is the better approach.

## Build

```
make            # build/ACCTEST.EXE   (sjasmplus 1.22+)
make img        # build/acctest.img   (FAT12 1.44M, mtools)
make run        # MAME window, the floppy on B:
make test       # MAME without a window: runs B:\ACCTEST.EXE /A /Q, writes build/mame/
```

`make test` writes these files to `build/mame/`:

- `report.txt`
- `ACCTEST.LOG`, copied from the floppy
- `visualN.png`, one per visual screen
- `result.png`, the screen with the RESULT line
- `final.png`, the file manager after the exit

`make test` uses the DSS image `sp_hdd_sys_0726.chd`; override it with `DSS_IMAGE`. Set `ACC_ARGS` to change the options it passes to the program (default `/A /Q /L=B:\ACCTEST.LOG`). `ACC_HEARTBEAT=N` logs progress every N emulated seconds; `ACC_TRACE_FROM=T` logs PC every frame from T seconds on.

Under MAME the decoder tests `DD 49`, `FD 49` and `FD 5B` fail; `make test` treats these three as known and passes if nothing else fails. The program is right and the emulator is wrong here: MAME's Z80 core is built with `LOG_UNDOC`, so for an undocumented `DD xx` or `FD xx` it re-reads the opcode through the M1 space to log it. That extra, unprefixed fetch of `#49` or `#5B` switches the accelerator on. A real Z80 makes no such fetch, and on a real Sprinter all the decoder tests pass.

The Lua script reads the program's flags straight from the RAM buffer. It cannot read through the address space: in this driver a read at `#0000..#FFFF` counts as an M1 fetch and feeds the accelerator decoder, and a read at `#1xxxx` goes through the accelerator tap. Either one would corrupt a running test.

**MAME checks logic only.** Its accelerator model charges `(N-1)·6` ticks per phase, with no start latency and no parity effects. It also leaves the ALU aliases unmodelled. Timing numbers, and the observations (INFO lines), only mean something on a real Sprinter.

## Running

```
ACCTEST [/T] [/V] [/B] [/A] [/Q] [/4] [/NOH] [/N] [/L=file]
```

| Option | Meaning |
|---|---|
| `/T` | correctness tests: RAM, then VRAM in 320×256 |
| `/V` | visual screens |
| `/B` | benchmarks: micro, CPU baselines, VRAM, rows versus columns, summary |
| *(none of `/T /V /B`)* | all three |
| `/A` | automatic: no key waits; each visual screen is held for 0.5 s |
| `/Q` | quick: smaller size matrices |
| `/4` | start offsets `addr & 3` = 0..3 instead of 0..1 |
| `/NOH` | skip the `LD H,H` probe |
| `/N` | no log file |
| `/L=file` | log file name or path, up to 63 characters; the default is `ACCTEST.LOG` in the current directory |

Exit codes:

| Code | Meaning |
|---|---|
| 0 | all tests passed |
| 1 | at least one test failed |
| 2 | setup error (memory, options) |
| 3 | aborted with Esc |

Esc stops the run between tests. On a long listing, "more" pauses the screen.

A run with `/A /Q` takes about a minute (measured in MAME). Write the log to the hard disk: on a floppy the log alone adds about a minute and a half.

### Comparing two firmwares

On the base firmware run `ACCTEST /L=BASE.LOG`, then on the new firmware run `ACCTEST /L=NEW.LOG`, both with the same turbo setting. Then, on a PC:

```
tools/compare.py BASE.LOG NEW.LOG          # changes above 1 % and 0.5 cycles
tools/compare.py BASE.LOG NEW.LOG --all    # every line
```

`compare.py` prints four things:

- the environment of both runs, with a warning if the CPU speed differs;
- for each operation, the cost per byte in both logs and the mean change;
- every line that changed;
- the rows-versus-columns table of both logs.

Keep the logs outside `build/`: `make clean` deletes that directory. The logs of the two firmwares measured so far are in `results/`.

## What is tested

The correctness tests write a background pattern, run the operation, and then compare every byte of a window around the source and the destination with a model. The background depends on the address, so a byte that lands in the wrong place is visible. Guard bytes are always `< #80`, and fill values and copied bytes are always `>= #80`, so an extra or missing byte at either end is always detected.

- **Linear RAM.** The program allocates two pages and maps them into WIN2/WIN3, so there is a real `#BFFF/#C000` boundary between two physical pages.
  - fill and copy for every combination of address parity and size `{1,2,3,4,5,15,16,17,127,128,129,255,256}`;
  - 256-byte and window boundaries;
  - overlapping copies; the whole block is read before it is written, so the result is a memmove;
  - the size latch persists, one load can be written three times, and the buffer survives `LD B,B`+`EI`+`HALT`;
  - `XOR`/`OR`/`AND (HL)`, and XOR applied twice;
  - vertical modes on plain RAM;
  - the decoder: `DD 49`, `FD 49`, `CB 49`, `#49` as an operand, `FD 6D`, `ED 52`, and `HALT` switching the mode off.
- **VRAM, 320×256.** Results are read back through the DRAM mirror on page `#50`.
  - horizontal fill and vertical fill (including the wrap from row 255 to row 0) for each x parity and size;
  - rectangles;
  - RAM→VRAM, VRAM→RAM and buffer 0→1;
  - column writes: a horizontal load, then an `LD A,A` write;
  - `LD A,A` copy and `LD A,A`+`LDIR`;
  - pages `#58` (transparent), `#54` and `#5C` (VRAM only);
  - fill and copy across the RAM `#BFFF` / VRAM `#C000` boundary;
  - XOR into VRAM;
  - the decoder on VRAM: `FD 5B` and `ED 5B` must not start a vertical fill. This runs on VRAM because in RAM a vertical fill looks the same as a plain write.
- **Observations (INFO).** These are printed and are not counted as pass/fail:
  - what `LD H,H` does at an even and at an odd address;
  - what `ADD/ADC/SUB/SBC/CP (HL)` do in the logic slot (per byte: `&` and, `^` xor, `|` or, `s` copy, `d` unchanged);
  - loading 16 then latching 8 (and the reverse): which buffer bytes get written;
  - a size taken from a memory read;
  - `PORT_Y` after vertical operations, and the rows an `LD A,A` copy of 16 actually writes.
- **Visual screens.** Each screen draws the left half with CPU code and the right half with the accelerator. The bar at the bottom is green when the two halves are identical. Screen 6 copies buffer 0 to buffer 1 with `LD A,A`+`LDIR` and switches the display to buffer 1.

## Reading the benchmarks

**Units.** The program never changes the CPU speed; it measures whatever turbo setting it was started with.

- A *cycle* is an accelerator cycle, not a CPU cycle. The accelerator moves one byte per 6 ticks of the 42 MHz crystal, which is 7 MHz or 142.9 ns, and this does not depend on the CPU clock. On the base firmware one cycle is one byte.
- `T@21` is the same time in T-states of the 21 MHz CPU clock: one cycle is exactly 3 T.
- The `CPU:` line at startup is the measured speed of a 98304 T loop, memory waits included. A turbo machine shows about 8.8 MHz there, not 21, and the line says "turbo on" above 4 MHz.

**Timer.** The timer is CTC ch2→ch3, a free-running 16-bit counter with no interrupts. One count is 1/875 kHz, which is 1.143 µs, 8 accelerator cycles, or 24 T at 21 MHz. At startup the program prints the frame period (expected 17920 counts).

**Micro-benchmarks.** Each line is the net cost of one operation. The program times `R` repetitions of the kernel, then times the same instruction stream with `LD B,B` in place of the mode. That second stream makes only the plain single-byte accesses. Net cost = (kernel time − plain time) / R.

- The plain stream already makes one access per phase, so the net cost of N bytes at one byte per cycle is N−1 cycles for a fill and 2N−2 for a copy.
- The `T@21`, `ns`, `ns/B` and `KB/s` columns follow from `cycles`.
- `aK` is the destination address `& 3`; `sKdL` gives source and destination.
- `~` marks two runs that differ by more than 1 %.

**Summary.** The summary fits N = 16..256. It prints:

- the per-byte slope;
- the fixed cost per operation;
- the mean extra cost of odd addresses;
- the speed-up over CPU `LDIR` code at N = 256.

**Rows versus columns.** The same picture is drawn three ways:

- by rows (fills or copies of up to 256 bytes per row);
- by columns (`LD E,E` vertical fill, or a horizontal buffer load followed by an `LD A,A` vertical write);
- by plain CPU code.

The scenarios are:

- a full-screen clear: 256+64 per row, 160+160 per row, or 320 columns;
- a full-screen picture from RAM;
- a buffer 0→1 copy;
- rectangles and sprites from 8×200 to 128×128: opaque, and transparent on `#5C`.

`cols/rows` greater than 1 means columns are slower. `CPU/rows` is how much the row method gains over the CPU. Raw values are in the log as `C;name;rows;cols;cpu`, in µs×10.

One CPU rectangle must fit the 74.9 ms period of the timer. The CPU column of a 128×128 line is therefore measured only if the 64×64 rectangle of the same kind took less than 15 ms; otherwise it shows `-`.

## Results so far

Two firmwares were measured on a real Sprinter in turbo (logs in `results/`): the base firmware (`base.LOG`) and a firmware with a 16-bit data path (`acc16.LOG`). Both pass every test, and their observations are identical.

Net cycles for N = 256:

| Operation | Base | 16-bit path |
|---|---|---|
| fill: RAM, VRAM, vertical | 255 | 255 |
| copy RAM→RAM | 510 | 254–256 |
| `XOR (HL)` in RAM | 765 | 381–384 |
| copy RAM→VRAM, also on `#5C`, and column load + `LD A,A` | 510 | 382–383 |
| copy VRAM→VRAM | 510 | 510 |
| CPU `LDIR`, for scale | 3656 | 3656 |

- **The new firmware halves every phase that reads or writes plain RAM.** A phase costs `ceil((N + (address & 1)) / 2)` cycles instead of N. An odd start costs at most one extra cycle per phase. Crossing `#xxFF` or `#BFFF/#C000` costs nothing extra.
- **VRAM accesses and fills are unchanged.** A copy from RAM to VRAM gains 25 % (N/2 to read, N to write), a VRAM→VRAM copy and every fill gain nothing.
- **A vertical operation costs the same per byte as a horizontal one**, on both firmwares. Rows and columns differ only in the number of operations: squares are equal within 1 %, an 8×200 fill is 4.4 times faster by columns, a 200×8 fill 4.5 times faster by rows. Sprites by columns are 13–40 % slower than by rows, because each column takes two phases.
- A full-screen clear takes 16.6 ms by rows and 14.8 ms by columns. A full-screen picture from RAM went from 29.3 to 23.4 ms.

## Memory map

| Address | Contents |
|---|---|
| `#4000` | EXE header |
| `#4200` | hot segment: kernels, test runner, timer, benchmark bodies, visual primitives, variables, 2 KB scratch |
| up to `#7FFE` | stack |
| `#8000` | cold segment: UI, test lists, report, strings; this is the second page of the EXE, in WIN2 |

While a test runs, interrupts are off and WIN2/WIN3 hold the arena or VRAM. Cold code is never called during that time.

All accelerator sequences are in `src/kernels.asm` and `src/scen_hot.asm`.
