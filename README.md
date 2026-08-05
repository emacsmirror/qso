# Emacs-QSO-Logger
This LISP code provides some basic functions for Emacs to rapidly capture and log amateur radio contacts (QSOs) into an ADIF file.

qso.el provides a fuction that generates a customizable, dynamic form (qso-log-form) to log amateur radio QSOs using almost any combination of ADIF fields in the ADIF 3.1.4 specification. This allows 
the user to customize the form for use in contests or general logging. All customizations are accessible in the 
QSO group, whose parent is the Emacs "Applications" group, accessed with `M-x customize`.

Further processing of the logs can be done within Emacs or by importing the ADIF file into another logging program.  

## Features
- Simple, customizable text interface for real-time ham radio QSO logging or even to rapidly convert paper log entries to an ADIF
- Runs entirely in a Linux terminal environment, allowing for its use in ultra-light, low-power HW/SW configurations (e.g. terminal-only mode on a Raspberry Pi Zero 2W)
- No mouse required (using tab or shift-tab to change fields or hover over buttons)
- Log entries are appended to a user-specified ADIF log file
- Any field in the ADIF 3.1.4 specification can be selected to appear on the form, in whatever order is desired
- Each field has an option to preserve the most recent information after a QSO submission
   - Example: For situations where frequency and mode unchanged between QSOs
   - Also useful for repeating sent information reports in contests
- Automatically populates BAND based on FREQ for commonly used bands, if otherwise left blank or not shown on the form
- Optional live radio synchronization through Hamlib's rigctld: FREQ, MODE and SUBMODE follow the radio as the operator tunes or changes mode, and the current reading is shown in the header line above the form
- Option to lookup callsign information and show the information (text) in another buffer (requires an internet connection)
- Option to check the log for duplicates before recording the QSO
- Option to clear the form without saving the information (e.g. for incomplete QSOs)

## Manual Installation
1) Place qso.el in the load path. If one hasn't been established, you can place it in `~/.emacs.d/lisp/` and
   then, in the init.el file (located in ~/.emacs.d/) add: `(add-to-list 'load-path "~/.emacs.d/lisp/")`
2) Add to the init.el file: `(require 'qso)`
3) Restart Emacs

## Getting Started
1) Execute `M-x customize`, select "Applications" and then select "QSO" to see the customization options.
2) Enter your callsign in the QSO Operator field.
3) Enter the path to the ADIF file you will be using (e.g. `~/qsolog.adi`).
4) Add, remove, or reorder the fields you wish to have on the form.
5) Select or deselect form fields that you wish you have cleared after a QSO submission (especially helpful for contests).
6) Click "Apply" or "Apply and Save" as appropriate.
7) Execute `M-x qso-log-form` to bring up and begin using the log entry form.

## Reading Frequency and Mode From the Radio (optional)
FREQ, MODE and SUBMODE can be read directly from a transceiver through
[Hamlib](https://hamlib.github.io/), so they follow the radio as you tune or change mode
rather than being typed for every contact. This is off by default.

1) Install Hamlib and start its `rigctld` daemon against your radio. Example (FXDX10):

   ```
   rigctld -m 1042 -r /dev/ttyUSB0 -s 38400
   ```

   Run `rigctl -l` to find the model number (`-m`) for your radio. `rigctld` is used rather
   than a direct serial connection so that the radio can be shared with other software
   (WSJT-X, fldigi, and so on) and so that reading it never blocks Emacs.
2) Turn on "QSO Hamlib Enable" in the QSO customization group, and set the host and port if
   `rigctld` is not on the default `localhost:4532`.
3) Add FREQ, MODE and (optionally) SUBMODE to the form fields so that the values are visible
   while logging. SUBMODE is written to the ADIF record whether or not it appears on the form.
4) Within the form, `C-c C-r` reads the radio once and `C-c C-t` turns synchronization on or off.

The radio's frequency and mode are also shown in the header line above the form. That display
comes straight from the radio and is never edited, so it stays accurate even where a field has
been typed over, and it reports connection trouble instead of failing silently.

### How fields are filled in
A field is updated only when it is empty or still holds the value the radio last put there, and
never while the cursor is inside it, so anything you type is left alone. Clearing a field hands
it back to the radio, which is what makes "clear after submission" work well with a rig that is
tuned between contacts.

Hamlib mode names are translated into ADIF MODE and SUBMODE values through the customizable
"QSO Hamlib Mode Map". For example `USB` is logged as MODE `SSB` with SUBMODE `USB`, and `CWR`
is logged as MODE `CW`.

The packet modes (`PKTUSB`, `PKTLSB`, `PKTFM`) map to nothing by default. The radio reports only
that it is in a data mode and cannot know whether you are running FT8, JS8, PSK31 or anything
else, so guessing would file contacts under the wrong mode. If you work one digital mode for a
whole session, set `PKTUSB` to that mode in the mode map and it will be filled in automatically.

If `rigctld` is not running, the form works exactly as it always has and the header line says so.
