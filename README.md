# Applecorn

<img src="applecorn_v8.png" alt="Applecorn Logo" height="200px"/>

Applecorn is a ProDOS application for the Apple //e Enhanced which provides
an environment for Acorn BBC Microcomputer language ROMs to run.  This
allows BBC BASIC and other Acorn languages to run on the Apple //e and
compatible systems.

The language ROMs run as-is, without any modification required.

## Hardware Requirements

The minimum requirement for Applecorn is an Apple II system with 128KB
of memory and a 65C02 processor.  This includes the following:

- Apple //e Enhanced (but not the original \]\[e, which has a 6502.)
- Apple //c and //c+
- Apple IIgs
  - You must enable the Alt Text Mode CDA!
  - ROM1: Only `MODE 1` (40 cols) works
  - ROM3: Both `MODE 0` and `MODE 1` work

## How to Run the Software

Boot the diskette `applecorn.po` which is an 800KB bootable ProDOS
diskette.  I use version 2.4.2 of ProDOS for my testing, but the software
should run on other versions of ProDOS.

Run `BASIC.SYSTEM` and at the Applesoft BASIC prompt type:
```
BRUN APPLECORN
```
to start the software.  Alternatively, you can simply select `APPLECORN`
in the ProDOS 2.4.2 Bitsy Bye file browser.

When first started, Applecorn will display a ROM selection menu.  Choose
the language ROM you wish to load by pressing the associated number key.
Applecorn will then load the requested ROM file from the diskette.  Each
of these files is a dump of a 16KB BBC Micro language ROM.

Once the ROM has loaded, it will automatically be started and you will
see the prompt.  For BBC BASIC, the prompt character is `>`.

Most of the BBC Micro languages (including BBC BASIC) prefer upper case
input.  You may want to keep Caps Lock enabled most of the time!

32 Kilobytes of space is available for your programs and variables. `PAGE`
is set to `&0E0`.

## 'Applecorn MOS' Features

### Compatible ROMs
- In principle any Acorn language ROM should work.
- Currently I have verified operation with:
  - BBC BASIC
  - Acornsoft COMAL
  - Acornsoft FORTH
  - Acornsoft Lisp
  - Acornsoft MicroProlog
  - Acornsoft BCPL
- I have not yet investigated two-ROM languages such as Logo or
  ISO Pascal.  It may be possible to support these also.

### Video Modes

Two text video modes are currently supported:
- 80x24 `MODE 0`
- 40x24 `MODE 1`

We plan to support HGR graphics eventually.

### Escape Key

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

### Special VDU Features

- `Ctrl-S` will pause the screen and `Ctrl-Q` will resume scrolling.
- The BBC Micro 'Copy Editor' function is supported.  Use the Apple II
  cursor keys to move the copy cursor and the `Tab` key to copy a character
  from the copy cursor to the insert cursor.
- BBC Micro function keys are supported.  Use Open Apple with the number
  keys for the unshifted function keys.

### HostFS

Applecorn's HostFS uses the ProDOS MLI to service all Acorn MOS filesystem
calls.  This means that Applecorn works directly with ProDOS volumes, such
as floppy disks, mass storage devices and even network connected drives
using ADT's VEDrive.

Since Acorn's DFS allows filenames beginning with a digit, while ProDOS
requires names to begin with an alphabetic character, Applecorn prefixes
any filenames beginning with a digit with the letter 'N'.

### Star Commands

`*QUIT` - Terminate Applecorn and quit to ProDOS.  Because the 'BBC Micro'
lives in auxiliary memory, you can usually restart Applecorn by running it
again and recover your program with `OLD`.

`*HELP` - Prints out information similar to the same command on the BBC micro.
Specifically it lists the version of Applecorn MOS and the name of the current
language ROM.

`*CAT` (or `*.`) - Simple listing of the files in the current directory.

`*EX` - Detailed listing of files in the current directory showing load
address, length and permissions.

`*DIR pathname` - Allows the current directory to be changed to any ProDOS
path.  Either `^` or `..` may be used to specify the parent directory.
A colon followed by a digit representing the slot and a digit representing
the drive may be used to specify a physical drive.  `*CD` and `*CHDIR` are
synonyms for `*DIR`.

Some examples:
   - `*DIR /H1/APPLECORN` - absolute path
   - `*DIR APPLECORN` - relative path
   - `*DIR ^` - go to parent dir
   - `*DIR ..` - go to parent dir (alternate form)
   - `*DIR ^/^` - go up two levels
   - `*DIR ../..` - go up two levels (alternate form)
   - `*DIR ^/SIBLING` - move to sibling directory
   - `*DIR :61` - set directory to volume in slot 6, drive 1
   - `*DIR :71/UTILS` - set directory to the `UTILS` subdir on the volume
      in slot 7, drive 1.

`*LOAD filename SSSS` - Load file `filename` into memory at hex address
`SSSS`. If the address `SSSS` is omitted then the file is loaded to the
address stored in its aux filetype.

`*SAVE filename SSSS EEEE` - Save memory from hex address `SSSS` to hex
address `EEEE` into file `filename`.  The start address `SSSS` is
recorded in the aux filetype.

`*RUN filename` - Load file `filename` into memory at the address stored
in its aux filetype and jump to to it.  This is used for loading and
starting machine code programs.

`*DELETE filename` - Delete file `filename` from disk.

`*RENAME oldfilename newfilename` - Rename file `oldfilename` to
`newfilename`.

`*CDIR dirname` - create directory `dirname`.  `*MKDIR` is a synonym.

`*FX a[,x,y]` - invokes `OSBYTE` MOS calls.

`*OPT` - sets file system options.  Currently does not do anything.

## How to Build

Applecorn is built natively on the Apple //e using the Merlin 8 assembler
v2.58.  It may also be built using Merlin-32 on Windows, Linux or Mac if
preferred.  (Note: I am currently using Merlin-16 3.53 on my 65816-equipped
//e.  This version permits sligtly longer comments so it may be necessary
to trim some comments to get the code to compile in Merlin 8.  Applecorn
may also be built using Merlin-32 on Windows, Linux or MacOS.)

In Merlin-8:
- Press `D` for disk commands and enter the prefix of the build directory:
  `PFX /APPLECORN`
- Press `L` to load a file and enter the filename `APPLECORN`.
- Merlin will enter the editor automatically (or press `E`).  Issue the
  following command a the editor's `:` prompt: `asm`
- Once assembly is complete, enter the command `q` to quit the editor.
- Press `Q` to quit Merlin-8.

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
- An 80 column screen is configured using PAGE2 memory from $800 to $bff
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

## Limitations

Applecorn currently has the following limitations:
- Not all MOS calls are implemented.
- There is file I/O support for file-orientated (`OSFILE`) file
  operations.  This allows `LOAD` and `SAVE` to work in languages such as
  BASIC or COMAL.
- There is also support for the character orientated operations (`OSFIND`,
  `OSBGET` `OSBPUT`) which allows all the disk file operations in the Acorn
  languages to work correctly.  For example in BBC BASIC the following
  commands work: `OPENIN`, `OPENOUT`, `OPENUP`, `BGET#` `BPUT#` `PTR#=`,
  `EOF#`, `EXT#`.
- The VDU driver is quite primitive at present.  Is supports 80 column
  text mode (`MODE 0`) and 40 column text mode (`MODE 1`).  There is
  currently no graphics support.
- Only a limited number of `OSBYTE` and `OSWORD` calls are implemented.
  More will be added in due course.
- Special BBC Micro functions such as sound, A/D interfaces, programmable
  function keys and so on are currently not supported.
- The Applecorn MOS command line is currently quite limited.  More commands
  will be added in due course.



