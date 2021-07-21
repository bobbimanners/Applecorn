# Applecorn

<img src="applecorn_v8.png" alt="Applecorn Logo" height="200px"/>

Applecorn is a ProDOS application for the Apple //e Enhanced which provides
an environment for Acorn BBC Microcomputer language ROMs to run.  This
allows BBC BASIC and other Acorn languages to run on the Apple //e.

The language ROMs run as-is, without any modification required.


## Hardware Requirements

Enhanced (65C02) Apple //e with 128KB of memory.

## How to Run the Software

Boot the diskette `applecorn.po` which is a 143KB Disk ][ bootable ProDOS
diskette.  I use version 2.4.2 of ProDOS for my testing, but the software
should run on other versions of ProDOS.

Run `BASIC.SYSTEM` and at the Applesoft BASIC prompt type:
```
BRUN APPLECORN
```
to start the software.

Applecorn will then load the content of the file `BASIC.ROM` from the
diskette.  This is a 16KB file containing BBC BASIC v2 from the BBC Micro.
Once the ROM has loaded, it will automatically be started and you will
see the `>` prompt of BBC BASIC.

32 Kilobytes of space is available for your programs and variables. `PAGE`
is set to `&0E0`.

## How to Build

Applecorn is built natively on the Apple //e using the Merlin 8 assembler
v2.58.

## Theory of Operation

### BBC Micro 

On the BBC Micro, language ROMs have a very clean interface to the Machine
Operating System (MOS).  Syscalls are used for all accesses to the hardware,
rather than poking at memory mapped addresses directly, as is common in
other 6502 systems.  This was done partly to enable programs to run on a 
second processor connected to the main BBC Micro over an interprocessor
interface called The Tube.

On the BBC Micro, the 64K address space looks like this:

```
                 +----------------------+ $ffff
                 |                      |
                 | MOS ROM (16KB)       |
                 |                      |
                 +----------------------+ $c000
                 |                      |
                 | Language ROM (16KB)  |
                 |                      |
                 +----------------------+ $8000
                 |                      |
                 | User RAM (32K)       |
                 |                      |
                 |                      |
                 |                      |
                 |                      |
                 |//////////////////////|
                 +----------------------+ $0000
```
The hatched area at the bottom represents reserved space such as zero page,
the stack and pages two through seven which are used by the language ROM for
various purposes.

Display memory on the BBC Micro is allocated at the top of user RAM, from
$8000 down.  Higher resolution modes use more memory, reducing the user RAM
available for BASIC programs.

The BBC Micro uses a unique paging mechanism referred to as 'Sideways ROM',
which allows up to 16 language and filing system ROMs to be banked into the
16KB space from $8000 to $bfff.

### Apple //e

The Apple //e, with 128KB has two 64KB banks of memory.  The main memory bank
is as follows:
```
   +----------------------+ $ffff +----------------------+
   | BASIC/Monitor ROM    |       | Language Card        |
   |                      |       |                      | +-4K Bank Two----+
   |###I/O Space (4KB)####|       +----------------------+ +----------------+
   +----------------------+ $c000
   |                      |
   |                      |
   |                      |
   |                      |
   |                      |
   | User RAM (48K)       |
   |                      |
   |                      |
   |                      |
   |                      |
   |//////////////////////|
   +----------------------+ $0000
```
Here there is 48KB of RAM rather than 32KB, and the total ROM is just 12KB,
starting at $d000.  The 4KB from $c000 to $cfff is all memory mapped I/O.

An additional 16KB of memory is available, which is referred to as the
Language Card (LC henceforth.)  This memory can be banked into the space
where the ROM usually resides from $d000 up.  Note that this address space
is only 12KB so the 16KB LC memory is itself banked with the bottom 4KB of
LC space having two banks.

When an Extended 80 Column card is installed in the aux slot of the Apple
//e, an additional 64KB of RAM is added, for a total of 128KB.  The entire
arrangement described above is duplicated, so there is 64KB of main memory
(divided between the 'lower 48K' and 16KB of LC memory) and 64KB of
auxiliary memory (divided in exactly the same manner.)

The Apple //e has softswitches to select whether to address the main or aux
bank for the main portion of RAM (ie: the 48KB up to $bfff).  Reading and
writing may be switched separately so it is possible to execute code and
read data from one bank while writing to the other.  A separate softswitch
controls whether zero page, the stack, and LC memory addresses will be passed
to main or aux banks.

The ProDOS operating system resides primarily in the main bank Language
Card memory, so this memory is not available to Applecorn if we wish to
retain the facilties provided by ProDOS.

The Apple //e screen normally resides from $400 to $7ff in main memory (for
40 column mode) or at $400 to $7ff in both main and aux memory (for 80
column mode.)  There is a softswitch to switch to text page two from $800
to $bff.

### Applecorn Architecture

```
MAIN BANK:

   +----------------------+ $ffff +----------------------+
   | BASIC/Monitor ROM    |       | Language Card        |
   |                      |       | ProDOS               | +-4K Bank Two----+
   |###I/O Space (4KB)####|       +----------------------+ +-Unused---------+
   +----------------------+ $c000
   |                      |
   |                      |
   |                      |
   |                      |
   | Applecorn loader &   |
   | Applecorn code to    |
   | interface with       |
   | ProDOS               |
   |                      |
   |                      |
   |//////////////////////|
   +----------------------+ $0000

AUX BANK:

   +----------------------+ $ffff 
   | Language Card        |
   | Applecorn MOS        |       +-4K Bank Two----+
   |###I/O Space (4KB)####|       +-Unused---------+
   +----------------------+ $c000
   |                      |
   | Acorn Language ROM   |
   |                      |
   +----------------------+
   |                      |
   | Acorn language       |
   | user code/data       |
   | space                |
   |                      |
   |                      |
   |//////////////////////|
   +----------------------+ $0000
```

- Applecorn maintains a 'BBC Micro virtual machine' in the Apple //e auxiliary
  memory. In particular, the 'BBC Micro' has its own zero page and stack in
  auxiliary memory, so there is no contention with ProDOS or with Applecorn.
- Applecorn primarily uses the main memory for servicing ProDOS file system
  requests for the 'BBC Micro virtual machine'.
- The Acorn language ROM is loaded to $8000 in aux memory.
- The Language Card memory is enabled and used to store the 'Applecorn MOS'
  from $d000 up in aux memory.  (The main bank LC memory contains ProDOS.)
- Applecorn copies its own 'Applecorn MOS' code to $d000 in aux memory and
  relocates the MOS entry vectors to high memory.
- An 80 column screen is configured using PAGE2 memory from $800 to $bfff
  in both main and aux memory.  This conveniently just fits in above page 7,
  which is the highest page used as Acorn language ROM workspace.
- The only real difference between the Apple //e aux memory map and that of
  the BBC Micro is the Apple //e has a 'hole' from $c000 to $cfff where memory
  mapped I/O resides.  Fortunately this does not really matter because the 
  language only uses well-defined entry points to call into the MOS, so we
  can simply avoid this address range.
- The memory map for the main and aux banks is illustrated in the diagram
  above.  For the aux bank, the LC is always banked in since no Apple monitor
  or BASIC ROM routines are called, so this is omitted from the diagram.

## 'Applecorn MOS' Features

- In principle any Acorn language ROM should work.
- Currently I have verified operation with:
  - BBC BASIC
  - Acornsoft COMAL
  - Acornsoft FORTH

## Limitations

Applecorn currently has the following limitations:

- A number of MOS calls relating to file I/O are not yet implemented including
  `OSFIND`, `OSGBPB`. `OSBPUT`, `OSBGET`, `OSARGS`.  This means that file
  operations such as the BBC BASIC `OPENIN` and `OPENOUT` do not work in the
  Acorn languages.  `OSFILE` is (partially) implemented however, so BASIC and
  COMAL can `LOAD` and `SAVE` programs.
- The VDU driver is quite primitive at present.  In particular it only
  supports 80 column text mode.  There is currently no graphics support.
- Only a few `OSBYTE` calls are implemented.  More will be added in due
  course.
- The only implemented `OSWORD` call is A=&00, to read a line of input from
  the console.  More will be added as needs arise.
- Special BBC Micro functions such as sound, A/D interfaces, programmable
  function keys and so on are currently not supported.
- The Applecorn MOS command line is currently quite limited.  More commands
  will be added in due course (for example `*FX`, `*LOAD`, `*SAVE` etc.).

### Escape

The BBC Micro uses interrupts extensively and the Escape key is handled
asynchronously.  The language ROM code simply checks an 'escape flag' in
zero page ($FF) from time to time to detect if Escape has been pressed.

The Apple //e does not use interrupts in its keyboard handling and the basic
machine include no sources of interrupts at all (there is no system timer.)
This prevents Escape from being handled in the same manner.

As a partial workaround, Applecorn checks whether the Escape key is pressed
from time to time when it has control, but there are cases where a program
can run forever without ever making a MOS call.  In these cases the only
way to interrupt the program is to press Ctrl-Reset.

### Ctrl-Reset

The Ctrl-Reset key combination is the only asynchronously handled keyboard
event on the Apple //e.  Applecorn sets up a reset handler which will restart
the ROM after Ctrl-Reset.  Any user program in aux memory will be untouched.

For ROMs such as BASIC or COMAL, the `OLD` command can be used to recover the
program in memory.

### Star Commands

`*QUIT` - Terminate Applecorn and quit to ProDOS.  Because the 'BBC Micro'
lives in auxiliary memory, you can usually restart Applecorn by running it
again and recover your program with `OLD`.

`*HELP` - Prints out information similar to the same command on the BBC micro.
Specifically it lists the version of Applecorn MOS and the name of the current
language ROM.

`*CAT` (or `*.`) - Simple listing of the files in the current directory.

`*DIR pathname` - Allows the current directory to be changed to any ProDOS
path.  For example `*DIR /H1/APPLECORN`.

