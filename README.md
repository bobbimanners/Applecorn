# Applecorn

<img src="applecorn_v8.png" alt="Applecorn Logo" height="200px"/>

Applecorn is a ProDOS application for the Apple //e Enhanced which provides
an environment for Acorn BBC Microcomputer language ROMs to run.  This
allows BBC BASIC and other Acorn languages to run on the Apple //e and
compatible systems.  Applecorn implements the Acorn MOS (Machine Operating
System) API on top of Apple ProDOS.

The language ROMs run as-is, without any modification required.

Any BBC Micro software that follows Acorn's coding guidelines and uses
approved MOS system calls should work on Applecorn, subject to the
limitations imposed by the different capabilities of the Apple II
hardware.

## Hardware Requirements

The minimum requirement for Applecorn is an Apple II system with 128KB
of memory and a 65C02 processor.  This includes the following:

- Apple //e Enhanced (but not the original \]\[e, which has a 6502.)
- Apple //c and //c+
- Apple IIgs

Note, for the Apple IIgs, you should NOT enable the "Alternate Text Mode"
CDA!

## How to Run the Software

Boot the diskette `applecorn.po` which is an 800KB bootable ProDOS
diskette.  Applecorn is a .SYSTEM program and should start automatically
when this disk is booted.

You can optionally boot your system from other ProDOS media, and then simply
select to start `APLCORN.SYSTEM` from your favorite ProDOS selector, such as
Bitsy-Bye.  I use version 2.4.2 of ProDOS for my testing, but the software
should run on other versions of ProDOS.

When first started, Applecorn will display a ROM selection menu.  Choose
the language ROM you wish to load by pressing the associated number key.
Applecorn will then load the requested ROM file from the diskette.  Each
of these files is a dump of a 16KB BBC Micro language ROM.

Once the ROM has loaded, it will automatically be started and you will
see the prompt.  For BBC BASIC, the prompt character is `>`.

Most of the BBC Micro languages (including BBC BASIC) prefer upper case
input.  You may want to keep Caps Lock enabled most of the time!

32 Kilobytes of space is available for your programs and variables. `PAGE`
is set to `&0E00`.

## 'Applecorn MOS' Features

### Compatible Language ROMs
- In principle any Acorn language ROM should work.
- 'Sideways ROMs' are now emulated (see below).  This allows languages
   which were supplied in more than one ROM to be supported.
- Currently I have verified operation with:
  - BBC BASIC
  - Acornsoft COMAL
  - Acornsoft Forth
  - Acornsoft Lisp
  - Acornsoft MicroProlog
  - Acornsoft BCPL
  - Acornsoft ISO-Pascal (supplied on two 16KB ROMs)
  - Acornsoft View (word processor)

All of the language manuals are provided in a separate GitHub repo:
https://github.com/bobbimanners/Applecorn-Manuals

The Applecorn diskette includes all of the example programs
which were provided on diskette with COMAL, Forth, Lisp and ISO Pascal.  The
main BCPL diskette, which contains tools that are essential for using the
BCPL ROM, is also included on the Applecorn diskette.

<img src="Applecorn-Collage.png" alt="Applecorn Collage" height="432px" width="768px"/>

### Video Modes

Two text video modes and one graphics mode are currently supported:
- `MODE 6` and `MODE 7` - 40x24 text (in mode 7, chars $80 to $9F are converted
  to spaces)
- `MODE 3` - 80x24 text.
- `MODE 1` - Apple II high resolution mode.  The physical resolution is 280x192
  pixels.  This is mapped onto the normal BBC Micro 1280x1024 virtual resolution,
  with the origin at the bottom left of the screen.

_NOTE:_ You can set the startup video mode by holding down the appropriate number
key while Applecorn starting (while it is loading the ROM file.)

Andy McFadden's [FDraw library](https://github.com/fadden/fdraw) is used for 
efficient high resolution line and point plotting.

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
- BBC Micro function keys are supported.
  - Use Open Apple with the number keys for the unshifted function keys.
  - Use Closed Apple with the number keys for the function keys with Shift.
  - Use both Open Apple and Closed Apple together with the number keys for
    the function keys with Ctrl.

### 'Sideways ROM' Support

The BBC Micro allows multiple ROMs to be banked into the 16KB space between
$8000 to $BFFF.  Acorn referred to such ROMs as 'sideways ROMs'.  The BBC
Micro architecture allows up to 16 sideways ROMs to be connected to the
system and paged into this address space (although the original BBC Micro
only featured four physical sockets.)

A sideways ROM may be either a 'language ROM' or a 'service ROM'.  Language
ROMs include a user interface, and are typically programming
languages.  However, note that ROM-based applications such as Acorn's View
word processor are also considered to be language ROMs.  Service ROMs do
not contain a user interface but instead provide additional star commands
to the operating system.  Utility and filing system ROMs fall into this
category.

When a star command is entered, the operating system first offers it to
the currently active language ROM.  If the current language does not support
the command, the system pages in the ROMs one at a time, starting from the
highest slot, offering the command to each of them.  If none of the ROMs
services the command an error is displayed.

Sideways ROMs are used in a number of ways:
- Support for multiple programming languages.  For example, a BBC Micro
  may have the COMAL ROM in addition to the BASIC ROM.  The machine normally
  boots into the highest numbered ROM (BASIC typically).  In this case,
  COMAL could be selected using the `*COMAL` command.  In COMAL, one could
  return to BASIC using `*BASIC`.
- Support for languages which are too large to fit in a single ROM such as
  Acornsoft ISO-Pascal, which occupies two 16KB ROMs.
- Utility and filesystem ROMs.

Applecorn emulates sideways ROMs by simply loading the ROM images from disk
into the $8000 to $BFFF space.  Unlike switching physical ROMs in the BBC
Micro, this is not instantaneous.  While it is possible to configure up to
16 ROMs, fewer are recommended in order to keep response times down.  This
mechanism allows multi-ROM languages such as ISO-Pascal to be supported.

The `*HELP` command displays information about each of the available
sideways ROMs.  (Note that the BCPL ROM does not print any `*HELP` info.
This is a bug in the ROM, not Applecorn!)

### HostFS

Applecorn's HostFS uses the ProDOS MLI to service all Acorn MOS filesystem
calls.  This means that Applecorn works directly with ProDOS volumes, such
as floppy disks, mass storage devices and even network connected drives
using ADT's VEDrive.

#### HostFS Pathnames

Pathnames used within Applecorn are regular ProDOS paths.  The
directory separator is forward slash `/` and every ProDOS filesystem has
a volume name which is used to access the top level ('volume') directory.
For example, a volume with the name 'TEST' would be mounted under ProDOS
as `/TEST`.

Applecorn adds a few extra features to ProDOS paths, as follows:
- A notation is provided for physical drive numbers, identifed by slot (1-7)
and drive (0 or 1).  This is very useful when you insert a floppy disk
with an unknown volume name.  The syntax for physical device specifiers
is a colon followed by two digits - one for the slot number and the other
for the drive number.  So, for example, `:61` would refer to slot 6,
drive 1.  Applecorn uses the ProDOS `ON_LINE` MLI call to find the 
volume associated with the physical device.  If slot 6, drive 1, contains
the volume 'FLOPPY', then a path `:S61/TESTFILE` will be converted to
`/FLOPPY/TESTFILE`.
- It is possible to refer to the current working directory (current prefix
in ProDOS terms) using `.` (like Linux or Windows) or `@` (like BBC ADFS.)
The current working directory notation is only supported at the beginning
of pathnames.
- Support is provided for easily accessing the parent directory.  This
may be denoted using `..` (like Linux or Windows) or `^` (like BBC ADFS.)
The parent directory notation is only supported at the beginning of
pathnames, but it may be applied multiple times to navigate further up
the tree.
- Some examples:
   - `/H1/APPLECORN` - absolute path
   - `APPLECORN` - relative path
   - `./APPLECORN` - relative path (explicit)
   - `^` - parent dir
   - `..` - parent dir (alternate form)
   - `^/^` - up two levels
   - `../..` - up two levels (alternate form)
   - `^/MYSTUFF` - file or directory in parent
   - `../MYSTUFF` - alternative way to refer to sibling directory
- Since Acorn's DFS allows filenames beginning with a digit, while ProDOS
requires names to begin with an alphabetic character, Applecorn prefixes
any file or directory names beginning with a digit with the letter 'N'.
An Applecorn path such as `/FOO/0DIR/50DIR/FILE01` would be converted to
`/FOO/N0DIR/N50DIR/FILE01`, for example, in order to make it a legal
ProDOS path.

#### HostFS Wildcards

Applecorn HostFS provides support for wildcards.  The following wildcard
characters are used:
   - `#` or `?` - matches any single character
   - `*` - matches zero or more characters

The HostFS tries to follow the same conventions as Acorn's ADFS, which 
allows wildcards to be used in some cases to abbreviate long pathnames
and in others to specify a list of files to operate on at once.

Like ADFS, HostFS commands accept several different types of file argument.
Following Acorn's convention, these may be described as follows:
   - `<obspec>` is an 'object specification'.  This is a pathname without
     any wildcard characters, as described in the previous section.
   - `<*obspec*>` is an 'wildcard object specification'.  This is a
     pathname which may include the wildcard characters.  If the
     wildcard characters specified result in multiple matching objects,
     the first one is used.
   - `<listspec>` is an 'list specification'.  This is also a
     pathname which may include the wildcard characters.  However, if the
     wildcard results in multiple matches, the command will operate
     on all of these files.
   - `<drv>` is a drive number.  (For example, `:61`).

Wildcards are expanded wherever they appear in the path with one
exception.  For non-leaf nodes, the first match will be always be 
substituted.  In the case of `<*objspec*>` the first match for the leaf
node will always be used.  However for `<listspec>` all matches of the 
leaf node will be operated upon.

Examples: `:71/T*DIR/TEST??.TXT`, `*A*/FILES/C*/TEST*.TXT`

Wildcards may also be used for `OSFILE` and `OSFIND` system calls, so
BASIC command like `LOAD""`, `CHAIN""`, `OPENIN""` and `OPENUP""` can
use wildcards to specify the file to open.

The attentive reader will have noticed that I mention an exception to
wildcard matching.  Volume directory names are not currently subject
to wildcard search.  Either type them in full, or use the colon
notation to specify physical drive as an abbreviation.

### Star Commands

Applecorn implements the command line interface for MOS built-in functions
and also for accessing the filingsystem.  Following Acorn conventions, these
commands are all invoked with a leading asterix `*`.

#### Applecorn Commands

These commands are specific to Applecorn.

`*QUIT` - Terminate Applecorn and quit to ProDOS.  Because the 'BBC Micro'
lives in auxiliary memory, you can usually restart Applecorn by running it
again and (assuming you are using BBC BASIC) recover your program with `OLD`.

`*FAST` - turn Apple II accelerator on (supports GS, Ultrawarp and ZipChip).

`*SLOW` - turn Apple II accelerator off (supports GS, Ultrawarp and ZipChip).

#### MOS Commands

The following commands correspond to those in the original Acorn MOS.

`*HELP [topic]` - Prints out information in a manner similar to the same
 command on the BBC micro.
  - `*HELP` with no argument shows the Applecorn MOS version number and the
    current language ROM in use, followed by a list of any other 'sideways
    ROMs' in the virtual system.
  - `*HELP FILE` shows the available filing system star commands.
  - `*HELP HOSTFS` shows the available HostFS star commands.
  - `*HELP MOS` shows the MOS star commands unrelated to the filing system.

`*BASIC` - Start the BASIC language (assuming it is present as one of the
virtual Sideways ROMs.)  BASIC is the only language ROM which does not 
provide its own startup command, so MOS provides it.

`*ECHO This is some text` - echo a line of text to the screen.

`*FX a[,x,y]` - Invokes `OSBYTE` MOS calls.

`*OPT` - Sets file system options.  `*OPT 255,x` may be used to enable or
disable debugging output.

`*KEY n <text>` - Programs a user-defined function key.  n can take values
from 0 to 15.  Values of 0 through 9 refer to the function keys (Open Apple
plus number key 0 through 9), while higher numbers may be used to program the
cursor keys and Copy key.  For example `*KEY 1 LIST|M` (note the special
syntax to insert a control character.)

`*CODE x,y` - Invokes user machine code through the user vector `USERV`.
6502 registers X and Y are initialized according to the value of the two
numeric arguments provided.

`*LINE <text>` - Invokes user machine code through the user vector `USERV`.
6502 registers X and Y are initialized to point at the command-line text
provided (X is least significant byte, Y most significant byte.)

`*TV n` - This command does nothing. It is provided for compatibility because
it is common for BBC Micro programs to use the `*TV` command to adjust the
vertical position of the picture on the monitor.

`*ROM` - On the real BBC Micro, this selects the ROM Filing System. This
command is accepted by Applecorn but does nothing.

`*TAPE` - On the real BBC Micro, this selects the Cassette Filing System.
This command is accepted by Applecorn but does nothing.

#### Filing System & HostFS Commands

This set of commands relates to filesystem operations, which would correspond
to the Disk Filing System (DFS) or Advanced Disk Filing System (ADFS) of the
BBC Micro.

`*CAT [<*objspec*>]` (or `*. [*objspec*]`) - Simple listing of the files in the
specified directory, or the current working directory ('current prefix') if
no directory argument is given.

`*EX [<*objspec*>]` - Detailed listing of files in the current directory 
showing the load address, length and permissions.  `*EX` expects a directory
as an argument, for example `*EX :71/MYDIR`.

`*INFO [<listspec>]` - Displays the same detailed file listing as `*EX`,
but accepting a `<listspec>`.  `*INFO` expects a list of objects as an
argument, so `*INFO :71/MYDIR/*` would display the same info as the `*EX`
example above.

`*DIR <*objspec*>` - Allows the current directory to be changed to any ProDOS
path.  `*CD` and `*CHDIR` are synonyms for `*DIR`.  The argument is expected
to be a directory.

`*LOAD <*objspec*> SSSS` - Load file `<*objspec*>` into memory at hex address
`SSSS`. If the address `SSSS` is omitted then the file is loaded to the
address stored in its aux filetype.

`*SAVE <objspec> SSSS EEEE` - Save memory from hex address `SSSS` to hex
address `EEEE` into file `<objspec>`.  The start address `SSSS` is
recorded in the aux filetype.  (Note, no wildcards when saving.)

`*RUN <*objspec*>` - Load file `filepath` into memory at the address stored
in its aux filetype and jump to to it.  This is used for loading and
starting machine code programs.  You can also simply do `*<*objspec*>` or
`*/<*objspec*>` (the latter form is useful if the name is the same as that
of a ROM routine.)

`*DELETE <objspec>` - Delete file `<objspec>` from disk.  This command
can also delete directories, provided they are empty.  No wildcards are
allowed.

`*REMOVE <objspec>` - Delete file `<objspec>` from disk.  This command
is identical to `*DELETE` except that no error message is shown if the file
to be deleted does not exist.

`*DESTROY <listspec>` - Deletes multiple files as specified by
`<listspec>`. For example, `*DESTROY PROJECT/*.ASM`.

`*RENAME <objspec1> <objspec2>` - Rename file or directory `<objspec1>`
to `<objspec2>`.  No wildcards are allowed.

`*TITLE [<drv>] <title>` - Change the disk title (or volumename in ProDOS
terms.)  If no drive is specified, the name of the volume in the
drive corresponding to the current ProDOS prefix is changed.

`*DRIVE <drv>` - Switch to the specified physical drive.  This is equivalent
to using `*DIR` but does not allow subdirectories to be specified.  The
working directory will be set to the volume directory corresponding to
the physical device specified.

`*FREE [<drv>]` - Shows blocks used and blocks free on the specified physical
device.  If no drive is specified, the free space on the drive corresponding
to the current ProDOS prefix is returned.

`*CDIR <objspec>` - create directory `dirname`.  `*MKDIR` is a synonym.

`*ACCESS <listspec> attribs` - change file permisions.  The string `attribs`
can contain any of the following:
  - `R` - File is readable
  - `W` - File is writeable
  - `L` - File is locked against deletion, renaming and writing.
For example: `*ACCESS *.ASM WR`

`*COPY <listspec> <*objspec*>` - Copy file(s).  There are two forms of
the `*COPY` command:
  - `*COPY <objspec> <*objspec*>` - Copy a single file.  The first argument
    must refer to a file and the second can be a file or a directory.
    If the target file exists and is writeable it will be overwritten.
    If a directory is specified as the destination then the file will
    be copied into the directory using the same filename.  No wildcards
    are allowed in the source filename in this case.  An example of
    this type of usage is `*COPY TEXT/ABC.TXT ../BACKUPS/ABC.BACKUP.TXT`
  - `*COPY <listspec> <*objspec*>` - Copy multiple files.  The first
    argument refers to a list of files, specified using wildcards.  The
    second argument must refer to a directory.  All the files included
    in the wildcard pattern will be copied into the destination
    directory.  For example of copying multiple files is 
    `*COPY :71/DOCS/*.TXT :72/TEXTDIR`
  - Recall that `@` or `.` may be used to specify the current working
    directory, while `^` or `..` may be used to specify the parent
    directory.

`*TYPE <*objspec*>` - type a text file to the screen.

`*DUMP <*objspec*>` - print a hexdump of a file to the screen.

`*BUILD <objspec>` - provides a quick and dirty way to create small text
files, one line at a time.  This is quite useful for making small files
for use with `*EXEC`.  Press Escape to finish editing and close the file.

`*SPOOL <objspec>` - copies all screen output to the filename given.
Issuing the `*SPOOL` command with no filename stops spooling and closes any
open spool file.

`*EXEC <*objspec*>` - reads input from the filename given, and executes
it, as though it were being typed on the keyboard.

`*CLOSE` - close any open files (including spool file, if open.)


### Audio Support

Applecorn includes an audio engine which emulates that of the Acorn MOS.
The audio facilities may be used from BBC BASIC using the `SOUND` and
`ENVELOPE` commands.  There are equivalents in other Acornsoft languaes,
should you wish to conduct your sonatas in Forth or Pascal.

Applecorn supports two different audio systems:
- Ensoniq DOC, which is standard equipment on all Apple IIgs systems.
- Mockingboard, a common add-on board for the Apple //e.

If Applecorn is run on a IIgs, Ensoniq audio will be enabled, otherwise a
Mockingboard will be assumed to be present in slot 4 (or you will have no
audio.)

Applecorn implements to core features of the BBC Micro audio engine:
- Three square-wave tone channels
- One noise channel
- Pitch and amplitude (ADSR) envelopes updated at 100Hz

The BBC Micro utilizes the Hitachi SN76489 sound generator chip. The
Ensoniq DOC is a more powerful sound chip, based on a wavetable, which
allows it to emulate teh SN76489 quite closely.  The Mockingboard uses
the popular General Instruments AY-3-8910 chip, which has slightly
different capabilities, especially with regard to the noise channel.
As a result, the Ensoniq emulation is closer to the BBC Micro original
than the Mockingboard.

Up to 16 envelopes are supported without having to worry about any
memory conflicts with other functions.

The audio code relies on an interrupt service routine being invoked
100 times a second.  This ISR also updates the pseudo-realtime clock
which may be read (and set) in BASIC using the `TIME` variable.  For
a //e with no Mockingboard there are is no source of interrupts, so
`TIME` remains at zero.

## How to Build

Applecorn is built natively on the Apple //e using the Merlin 16 assembler
v3.53 (requires a 65816 though.)  It may also be built using Merlin-32 on
Windows, Linux or Mac if preferred.  The code should also assemble on
Merlin-8 2.58 provided some of the longer comments are trimmed (Merlin-16
allows longer lines.)

To build in Merlin-32, use the `m32build` provided.

In Merlin-16 (Merlin-8 in parenthesis, where different):
- Press `D` for disk commands and enter the prefix of the build directory:
  `PFX /APPLECORN`
- Press `L` to load a file and enter the filename `APPLECORN`.
- Merlin will enter the editor automatically (or press `E`).  Open Apple-A
  starts assembly. (Merlin-8: Issue the following command a the editor's
  `:` prompt: `asm`
- Once assembly is complete, enter the command `q` to quit the editor.
- Press `Q` to quit Merlin.

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

Applecorn MOS is relatively complete.  Most limitations reflect the different
hardware capabilities of the BBC Micro and the Apple II.
- Most MOS calls are implemented.
- There is disk I/O support for file-orientated (`OSFILE`) file
  operations.  This allows `LOAD` and `SAVE` to work in languages such as
  BASIC or COMAL.
- There is also support for the character orientated operations (`OSFIND`,
  `OSBGET` `OSBPUT`) which allows all the disk file operations in the Acorn
  languages to work correctly.  For example in BBC BASIC the following
  commands work: `OPENIN`, `OPENOUT`, `OPENUP`, `BGET#` `BPUT#` `PTR#=`,
  `EOF#`, `EXT#`.
- `OSGBPB` calls with A=1 through 4 are supported.  These allow reading
  and writing a range of bytes from a file that is already open.  The
  Forth ROM uses this system call for loading and saving screens of
  code.
- Many `OSBYTE` and `OSWORD` calls are implemented.
- The VDU driver is has most of the important functions for working in text
  modes.  Since the Apple II can not display colour text, VDU codes
  related to colour are not implemented.  The VDU driver is sufficient to
  run full screen editors such as the ISO Pascal editor and the View
  word processor.
- Special BBC Micro functions such A/D interfaces, programmable
  function keys and so on are currently not supported.


