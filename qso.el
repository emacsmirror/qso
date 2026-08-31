;;; qso.el --- Amateur radio QSO logging -*- lexical-binding: t; -*-

;; Copyright (C) 2026, David Pentrack
;; Author: David Pentrack
;; URL: https://github.com/K6SM/Emacs-QSO-Logger
;; Keywords: lisp
;; Version: 1.3.0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Package-Requires: ((emacs "25.1"))

;;; Commentary:

;; This LISP code provides some basic functions for Emacs to rapidly
;; capture and log amateur radio contacts (QSOs) into an ADIF file.
;;
;; qso.el provides a fuction that generates a customizable, dynamic
;; form (qso-log-form) to log amateur radio QSOs using almost any
;; combination of ADIF fields in the ADIF 3.1.4 specification.
;; This allows the user to customize the form for use in contests or
;; general logging.  All customizations are accessible in the "QSO"
;; group, whose parent is the Emacs "Applications" group, accessed
;; with M-x customize.
;;
;; Further processing of the logs can be done within Emacs or by
;; importing the ADIF file into another logging program.

;; Features

;; - Simple, customizable text interface for real-time ham radio QSO
;;   logging or even to rapidly convert paper log entries to an ADIF
;; - Runs entirely in a Linux terminal environment, allowing for its
;;   use in ultra-light, low-power HW/SW configurations (e.g. terminal-
;;   only mode on a Raspberry Pi Zero 2W)
;; - No mouse required (using tab or shift-tab to change fields or
;;   hover over buttons)
;; - Log entries are appended to a user-specified ADIF log file
;; - Any field in the ADIF 3.1.4 specification can be selected to
;;   appear on the form, in whatever order is desired
;; - Each field has an option to preserve the most recent information
;;   after a QSO submission
;;   - Example: For situations where frequency and mode unchanged
;;     between QSOs
;;   - Also useful for repeating sent information reports in contests
;; - Automatically populates BAND based on FREQ for commonly used
;;   bands, if otherwise left blank or not shown on the form
;; - Optional live radio synchronization through Hamlib's rigctld:
;;   FREQ, MODE and SUBMODE follow the radio as the operator tunes
;;   or changes mode, and the current reading is shown in the header
;;   line above the form
;; - Option to lookup callsign information and show the information
;;   (text) in another buffer (requires an internet connection)
;; - Callsigns can be looked up at callook.info, HamQTH or QRZ.com,
;;   and the fields worth keeping can be filled in automatically,
;;   whether or not they appear on the form
;; - Country, continent and CQ/ITU zones can be worked out from the
;;   callsign itself using a cty.dat country file, which covers the
;;   whole world with no network connection and no account
;; - Option to check the log for duplicates before recording the QSO
;; - Option to clear the form without saving the information (e.g.
;;   for incomplete QSOs)
;;
;; Getting Started
;;
;;  1) Execute M-x customize, select "Applications" and then select
;;     "QSO" to see the customization options.
;;  2) Enter your callsign in the QSO Operator field.
;;  3) Enter the path to the ADIF file you will be using
;;     (e.g. ~/qsolog.adi).
;;  4) Add, remove, or reorder the fields you wish to have on the form.
;;  5) Select or deselect form fields that you wish you have cleared
;;     after a QSO submission (especially helpful for contests).
;;  6) Click "Apply" or "Apply and Save" as appropriate.
;;  7) Execute M-x qso-log-form to bring up and begin using the log
;;     entry form.
;;
;; Reading Frequency and Mode From the Radio (optional)
;;
;;  1) Install Hamlib and start its rigctld daemon against your radio,
;;     for example:
;;
;;       rigctld -m 3073 -r /dev/ttyUSB0 -s 38400
;;
;;     Run "rigctl -l" to find the model number (-m) for your radio.
;;     rigctld is used rather than a direct serial connection so that
;;     this package can share the radio with other software (WSJT-X,
;;     fldigi, and so on) and so that polling never blocks Emacs.
;;  2) Turn on "QSO Hamlib Enable" in the QSO customization group, and
;;     set the host and port if rigctld is not on the default
;;     localhost:4532.
;;  3) Add FREQ, MODE and (optionally) SUBMODE to the form fields so
;;     that the values are visible while logging.  SUBMODE is written
;;     to the ADIF record whether or not it appears on the form.
;;  4) Within the form, C-c C-r reads the radio once and C-c C-t turns
;;     synchronization on or off.
;;
;; While synchronization is running, a field is updated only when it is
;; empty or still holds the value the radio last put there, so anything
;; typed by the operator is never overwritten.
;;
;; Looking Up Callsigns (optional)
;;
;; "QSO Callsign Lookup Source" chooses where details come from:
;;
;;   callook.info  United States only, no account needed.  This is the
;;                 default, and it serves the FCC's public database.
;;   HamQTH        Worldwide, free, but asks you to register.
;;   QRZ.com       Worldwide, needs a paid XML subscription.
;;
;; Most countries outside the United States do not publish operator
;; names and addresses at all, which is why a worldwide lookup means
;; using a community-maintained callbook rather than an official
;; register.
;;
;; HamQTH and QRZ.com need a login.  Put the username in "QSO Callsign
;; Lookup User" and the password in ~/.authinfo.gpg, so that it is not
;; kept in your Emacs configuration:
;;
;;   machine www.hamqth.com login MYCALL password SECRET
;;   machine xmldata.qrz.com login MYCALL password SECRET
;;
;; "QSO Callsign Lookup Fields" chooses what to fill in.  A field is
;; filled whether or not it is on the form: anything not on the form is
;; written straight into the ADIF record when the QSO is submitted.
;;
;; Country, continent and CQ/ITU zones can also be worked out from the
;; callsign alone, with no network connection and no account, for any
;; callsign in the world.  Download a country file from
;; https://www.country-files.com, point "QSO Country File" at it, and
;; leave "QSO Callsign Lookup DXCC" on.  Whatever the chosen source
;; reports takes precedence over this, and if the file is missing the
;; rest of the form carries on as usual.
;;
;; Within the form, C-c C-l looks up the callsign that has been typed.

;;; Code:

(require 'wid-edit)
(require 'cl-lib)
(require 'subr-x)
(require 'seq)
(require 'url)
(require 'json)
(require 'xml)

(defgroup qso nil
  "Amateur radio QSO logging."
  :tag "QSO"
  :group 'applications)

(defcustom qso-adif-path "~/qso-log.adi"
  "Path to QSO ADIF file."
  :tag "QSO ADIF Path"
  :type 'string
  :group 'qso)

(defcustom qso-adif-title "Generated by Emacs QSO Logger"
  "Title of the ADIF file to appear in the first line of the ADIF header."
  :tag "QSO ADIF Title"
  :type 'string
  :group 'qso)

(defcustom qso-call-lookup t
  "If non-nil, provide a callsign lookup function/button."
  :tag "QSO Callsign Lookup"
  :type 'boolean
  :group 'qso)

;; Declared ahead of the option itself so that a setting saved under the
;; old name is carried over rather than quietly ignored.
(define-obsolete-variable-alias 'qso-call-lookup-autofill-name
  'qso-call-lookup-autofill "1.3.0")

(defcustom qso-call-lookup-autofill nil
  "If non-nil, provide a callsign lookup/autofill function/button."
  :tag "QSO Callsign Lookup Autofill"
  :type 'boolean
  :group 'qso)

(defcustom qso-call-lookup-source 'callook
  "Where to look up callsign details.

callook.info serves the FCC's public database and needs no account, but
it knows only United States callsigns.  Most other countries do not
publish operator details at all, so worldwide lookup means using a
community-maintained callbook, and those ask you to identify yourself.

Whichever source is chosen, `qso-call-lookup-dxcc' can still name the
country, continent and zones for any callsign in the world without any
network connection at all."
  :tag "QSO Callsign Lookup Source"
  :type '(choice
          (const :tag "callook.info (United States only, no account)" callook)
          (const :tag "HamQTH (worldwide, free account required)" hamqth)
          (const :tag "QRZ.com (worldwide, paid XML subscription)" qrz)
          (const :tag "None (offline country lookup only)" nil))
  :group 'qso)

(defcustom qso-call-lookup-user ""
  "Username or callsign used to log in to HamQTH or QRZ.com.

The matching password is read with `auth-source', so it never has to be
stored in your Emacs configuration.  Put a line like this one in
~/.authinfo.gpg:

    machine www.hamqth.com login MYCALL password SECRET

using machine `xmldata.qrz.com' for QRZ.com instead."
  :tag "QSO Callsign Lookup User"
  :type 'string
  :group 'qso)

(defcustom qso-call-lookup-fields '(NAME)
  "ADIF fields to fill in from a callsign lookup.

A field is filled in whether or not it appears on the form: anything
that is not on the form is written straight to the ADIF record when the
QSO is submitted.  Which fields actually arrive depends on the source,
and nothing is ever written over something you typed yourself."
  :tag "QSO Callsign Lookup Fields"
  :type '(set (const :tag "NAME (operator's name)" NAME)
              (const :tag "QTH (city or town)" QTH)
              (const :tag "GRIDSQUARE (Maidenhead locator)" GRIDSQUARE)
              (const :tag "STATE (primary subdivision)" STATE)
              (const :tag "CNTY (secondary subdivision)" CNTY)
              (const :tag "COUNTRY (DXCC entity name)" COUNTRY)
              (const :tag "CQZ (CQ zone)" CQZ)
              (const :tag "ITUZ (ITU zone)" ITUZ)
              (const :tag "CONT (continent)" CONT)
              (const :tag "LAT (latitude)" LAT)
              (const :tag "LON (longitude)" LON))
  :group 'qso)

(defcustom qso-call-lookup-timeout 10
  "Seconds to wait for a callsign lookup before giving up."
  :tag "QSO Callsign Lookup Timeout"
  :type 'number
  :group 'qso)

(defcustom qso-call-lookup-dxcc t
  "If non-nil, work out country, continent and zones from the callsign.

This reads the country file named by `qso-cty-file' and needs no network
connection and no account, so it covers every callsign in the world.  It
cannot supply an operator's name, only where the station is."
  :tag "QSO Callsign Lookup DXCC"
  :type 'boolean
  :group 'qso)

(defcustom qso-cty-file nil
  "Path to a cty.dat country file, or nil.

Country files are published at https://www.country-files.com and are
updated as new entities and prefixes are allocated.  When this is nil,
or names a file that is not there, callsigns are simply not resolved to
a country and the rest of the form carries on as usual."
  :tag "QSO Country File"
  :type '(choice (const :tag "None" nil) (file :tag "cty.dat"))
  :group 'qso)

(defcustom qso-call-duplicates t
  "Enable duplicate callsign checking."
  :tag "QSO Call Duplicates"
  :type 'boolean
  :group 'qso)

(defcustom qso-OPERATOR "MYCALL"
  "Control operator's callsign."
  :tag "QSO Operator"
  :type 'string
  :group 'qso)

(defconst qso-form-buffer-name "*QSO Log Entry*"
  "Name of the buffer holding the QSO log entry form.")

(defcustom qso-hamlib-enable nil
  "If non-nil, follow the radio's frequency and mode through Hamlib.

`qso-log-form' opens a connection to a running rigctld daemon and
polls it every `qso-hamlib-poll-interval' seconds, keeping the FREQ,
MODE and SUBMODE fields in step with the radio and showing the current
reading in the header line.

This requires rigctld to be running already, for example:

    rigctld -m 3073 -r /dev/ttyUSB0 -s 38400

Run \"rigctl -l\" to find the model number for your radio."
  :tag "QSO Hamlib Enable"
  :type 'boolean
  :group 'qso)

(defcustom qso-hamlib-host "localhost"
  "Host running the rigctld daemon."
  :tag "QSO Hamlib Host"
  :type 'string
  :group 'qso)

(defcustom qso-hamlib-port 4532
  "TCP port on which the rigctld daemon is listening."
  :tag "QSO Hamlib Port"
  :type 'integer
  :group 'qso)

(defcustom qso-hamlib-poll-interval 1.0
  "Seconds between readings of the radio's frequency and mode."
  :tag "QSO Hamlib Poll Interval"
  :type 'number
  :group 'qso)

(defcustom qso-hamlib-reconnect-interval 5.0
  "Seconds to wait before retrying a failed connection to rigctld."
  :tag "QSO Hamlib Reconnect Interval"
  :type 'number
  :group 'qso)

(defcustom qso-hamlib-connect-timeout 5.0
  "Seconds to allow rigctld to answer a connection attempt.

A host that is switched off or behind a firewall may never answer at
all.  Connecting does not block Emacs, but without a deadline of this
kind the form would sit indefinitely reporting that it is connecting."
  :tag "QSO Hamlib Connect Timeout"
  :type 'number
  :group 'qso)

(defcustom qso-hamlib-header-line t
  "If non-nil, show the radio's frequency and mode in the form's header line.

The header line reports the radio directly and is never edited, so it
stays accurate even when the operator has typed over the FREQ or MODE
field."
  :tag "QSO Hamlib Header Line"
  :type 'boolean
  :group 'qso)

(defcustom qso-hamlib-freq-format "%.6f"
  "Format string used to render the radio's frequency in MHz."
  :tag "QSO Hamlib Frequency Format"
  :type 'string
  :group 'qso)

(defcustom qso-hamlib-mode-alist
  '(("USB"     "SSB"  "USB")
    ("LSB"     "SSB"  "LSB")
    ("ECSSUSB" "SSB"  "USB")
    ("ECSSLSB" "SSB"  "LSB")
    ("CW"      "CW"   "")
    ("CWR"     "CW"   "")
    ("RTTY"    "RTTY" "")
    ("RTTYR"   "RTTY" "")
    ("AM"      "AM"   "")
    ("AMS"     "AM"   "")
    ("SAM"     "AM"   "")
    ("SAL"     "AM"   "")
    ("SAH"     "AM"   "")
    ("DSB"     "AM"   "")
    ("FM"      "FM"   "")
    ("FMN"     "FM"   "")
    ("WFM"     "FM"   "")
    ("PKTUSB"  ""     "")
    ("PKTLSB"  ""     "")
    ("PKTFM"   ""     ""))
  "How Hamlib mode names translate into ADIF MODE and SUBMODE values.

Each entry is a Hamlib mode name followed by the ADIF MODE and ADIF
SUBMODE to record for it.  An empty string means \"leave the field
alone\".

The packet modes are deliberately left empty: the radio reports only
that it is in a data mode and cannot know whether the operator is
running FT8, JS8, PSK31 or anything else, so guessing would file
contacts under the wrong mode.  An operator who works one digital mode
for a whole session can set PKTUSB to that mode here, for example
\"FT8\", and have it filled in automatically."
  :tag "QSO Hamlib Mode Map"
  :type '(alist :key-type (string :tag "Hamlib mode")
                :value-type (group (string :tag "ADIF MODE")
                                   (string :tag "ADIF SUBMODE")))
  :group 'qso)

(defcustom qso-form-fields
  '((CALL . t)
    (NAME . t)
    (RST_RCVD . t)
    (RST_SENT . nil)
    (FREQ . nil)
    (MODE . nil)
    (COMMENT . t))
  "Fields to show in the QSO Log Entry form and which to clear between entries."
  :tag "QSO Form Fields"
  :type '(alist :key-type (choice (const :tag "ADDRESS" ADDRESS)
				  (const :tag "ADDRESS_INTL" ADDRESS_INTL)
				  (const :tag "AGE" AGE)
				  (const :tag "ALTITUDE" ALTITUDE)
				  (const :tag "ANT_AZ" ANT_AZ)
				  (const :tag "ANT_EL" ANT_EL)
				  (const :tag "ANT_PATH" ANT_PATH)
				  (const :tag "ARRL_SECT" ARRL_SECT)
				  (const :tag "AWARD_GRANTED" AWARD_GRANTED)
				  (const :tag "AWARD_SUBMITTED" AWARD_SUBMITTED)
				  (const :tag "A_INDEX" A_INDEX)
				  (const :tag "BAND" BAND)
				  (const :tag "BAND_RX" BAND_RX)
				  (const :tag "CALL" CALL)
				  (const :tag "CHECK" CHECK)
				  (const :tag "CLASS" CLASS)
				  (const :tag "CLUBLOG_QSO_UPLOAD_DATE" CLUBLOG_QSO_UPLOAD_DATE)
				  (const :tag "CLUBLOG_QSO_UPLOAD_STATUS" CLUBLOG_QSO_UPLOAD_STATUS)
				  (const :tag "CNTY" CNTY)
				  (const :tag "COMMENT" COMMENT)
				  (const :tag "COMMENT_INTL" COMMENT_INTL)
				  (const :tag "CONT" CONT)
				  (const :tag "CONTACTED_OP" CONTACTED_OP)
				  (const :tag "CONTEST_ID" CONTEST_ID)
				  (const :tag "COUNTRY" COUNTRY)
				  (const :tag "COUNTRY_INTL" COUNTRY_INTL)
				  (const :tag "CQZ" CQZ)
				  (const :tag "CREDIT_SUBMITTED" CREDIT_SUBMITTED)
				  (const :tag "CREDIT_GRANTED" CREDIT_GRANTED)
				  (const :tag "DARC_DOK" DARC_DOK)
				  (const :tag "DISTANCE" DISTANCE)
				  (const :tag "DXCC" DXCC)
				  (const :tag "EMAIL" EMAIL)
				  (const :tag "EQ_CALL" EQ_CALL)
				  (const :tag "EQSL_QSLRDATE" EQSL_QSLRDATE)
				  (const :tag "EQSL_QSLSDATE" EQSL_QSLSDATE)
				  (const :tag "EQSL_QSL_RCVD" EQSL_QSL_RCVD)
				  (const :tag "EQSL_QSL_SENT" EQSL_QSL_SENT)
				  (const :tag "FISTS" FISTS)
				  (const :tag "FISTS_CC" FISTS_CC)
				  (const :tag "FORCE_INIT" FORCE_INIT)
				  (const :tag "FREQ" FREQ)
				  (const :tag "FREQ_RX" FREQ_RX)
				  (const :tag "GRIDSQUARE" GRIDSQUARE)
				  (const :tag "GRIDSQUARE_EXT" GRIDSQUARE_EXT)
				  (const :tag "GUEST_OP" GUEST_OP)
				  (const :tag "HAMLOGEU_QSO_UPLOAD_DATE" HAMLOGEU_QSO_UPLOAD_DATE)
				  (const :tag "HAMLOGEU_QSO_UPLOAD_STATUS" HAMLOGEU_QSO_UPLOAD_STATUS)
				  (const :tag "HAMQTH_QSO_UPLOAD_DATE" HAMQTH_QSO_UPLOAD_DATE)
				  (const :tag "HAMQTH_QSO_UPLOAD_STATUS" HAMQTH_QSO_UPLOAD_STATUS)
				  (const :tag "HRDLOG_QSO_UPLOAD_DATE" HRDLOG_QSO_UPLOAD_DATE)
				  (const :tag "HRDLOG_QSO_UPLOAD_STATUS" HRDLOG_QSO_UPLOAD_STATUS)
				  (const :tag "IOTA" IOTA)
				  (const :tag "IOTA_ISLAND_ID" IOTA_ISLAND_ID)
				  (const :tag "ITUZ" ITUZ)
				  (const :tag "K_INDEX" K_INDEX)
				  (const :tag "LAT" LAT)
				  (const :tag "LON" LON)
				  (const :tag "LOTW_QSLRDATE" LOTW_QSLRDATE)
				  (const :tag "LOTW_QSLSDATE" LOTW_QSLSDATE)
				  (const :tag "LOTW_QSL_RCVD" LOTW_QSL_RCVD)
				  (const :tag "LOTW_QSL_SENT" LOTW_QSL_SENT)
				  (const :tag "MAX_BURSTS" MAX_BURSTS)
				  (const :tag "MODE" MODE)
				  (const :tag "MS_SHOWER" MS_SHOWER)
				  (const :tag "MY_ALTITUDE" MY_ALTITUDE)
				  (const :tag "MY_ANTENNA" MY_ANTENNA)
				  (const :tag "MY_ARRL_SECT" MY_ARRL_SECT)
				  (const :tag "MY_CITY" MY_CITY)
				  (const :tag "MY_CITY_INTL" MY_CITY_INTL)
				  (const :tag "MY_CNTY" MY_CNTY)
				  (const :tag "MY_COUNTRY" MY_COUNTRY)
				  (const :tag "MY_COUNTRY_INTL" MY_COUNTRY_INTL)
				  (const :tag "MY_CQ_ZONE" MY_CQ_ZONE)
				  (const :tag "MY_DXCC" MY_DXCC)
				  (const :tag "MY_FISTS" MY_FISTS)
				  (const :tag "MY_GRIDSQUARE" MY_GRIDSQUARE)
				  (const :tag "MY_GRIDSQUARE_EXT" MY_GRIDSQUARE_EXT)
				  (const :tag "MY_IOTA" MY_IOTA)
				  (const :tag "MY_IOTA_ISLAND_ID" MY_IOTA_ISLAND_ID)
				  (const :tag "MY_ITU_ZONE" MY_ITU_ZONE)
				  (const :tag "MY_LAT" MY_LAT)
				  (const :tag "MY_LON" MY_LON)
				  (const :tag "MY_NAME" MY_NAME)
				  (const :tag "MY_NAME_INTL" MY_NAME_INTL)
				  (const :tag "MY_POSTAL_CODE" MY_POSTAL_CODE)
				  (const :tag "MY_POSTAL_CODE_INTL" MY_POSTAL_CODE_INTL)
				  (const :tag "MY_POTA_REF" MY_POTA_REF)
				  (const :tag "MY_RIG" MY_RIG)
				  (const :tag "MY_RIG_INTL" MY_RIG_INTL)
				  (const :tag "MY_SIG" MY_SIG)
				  (const :tag "MY_SIG_INTL" MY_SIG_INTL)
				  (const :tag "MY_SIG_INFO" MY_SIG_INFO)
				  (const :tag "MY_SIG_INFO_INTL" MY_SIG_INFO_INTL)
				  (const :tag "MY_SOTA_REF" MY_SOTA_REF)
				  (const :tag "MY_STATE" MY_STATE)
				  (const :tag "MY_STREET" MY_STREET)
				  (const :tag "MY_STREET_INTL" MY_STREET_INTL)
				  (const :tag "MY_USACA_COUNTIES" MY_USACA_COUNTIES)
				  (const :tag "MY_VUCC_GRIDS" MY_VUCC_GRIDS)
				  (const :tag "MY_WWFF_REF" MY_WWFF_REF)
				  (const :tag "NAME" NAME)
				  (const :tag "NAME_INTL" NAME_INTL)
				  (const :tag "NOTES" NOTES)
				  (const :tag "NOTES_INTL" NOTES_INTL)
				  (const :tag "NR_BURSTS" NR_BURSTS)
				  (const :tag "NR_PINGS" NR_PINGS)
;				  (const :tag "OPERATOR" OPERATOR)
				  (const :tag "OWNER_CALLSIGN" OWNER_CALLSIGN)
				  (const :tag "PFX" PFX)
				  (const :tag "POTA_REF" POTA_REF)
				  (const :tag "PRECEDENCE" PRECEDENCE)
				  (const :tag "PROP_MODE" PROP_MODE)
				  (const :tag "PUBLIC_KEY" PUBLIC_KEY)
				  (const :tag "QRZCOM_QSO_UPLOAD_DATE" QRZCOM_QSO_UPLOAD_DATE)
				  (const :tag "QRZCOM_QSO_UPLOAD_STATUS" QRZCOM_QSO_UPLOAD_STATUS)
				  (const :tag "QSLMSG" QSLMSG)
				  (const :tag "QSLMSG_INTL" QSLMSG_INTL)
				  (const :tag "QSLRDATE" QSLRDATE)
				  (const :tag "QSLSDATE" QSLSDATE)
				  (const :tag "QSL_RCVD" QSL_RCVD)
				  (const :tag "QSL_RCVD_VIA" QSL_RCVD_VIA)
				  (const :tag "QSL_SENT" QSL_SENT)
				  (const :tag "QSL_SENT_VIA" QSL_SENT_VIA)
				  (const :tag "QSL_VIA" QSL_VIA)
				  (const :tag "QSO_COMPLETE" QSO_COMPLETE)
				  (const :tag "QSO_DATE" QSO_DATE)
				  (const :tag "QSO_DATE_OFF" QSO_DATE_OFF)
				  (const :tag "QSO_RANDOM" QSO_RANDOM)
				  (const :tag "QTH" QTH)
				  (const :tag "QTH_INTL" QTH_INTL)
				  (const :tag "REGION" REGION)
				  (const :tag "RIG" RIG)
				  (const :tag "RIG_INTL" RIG_INTL)
				  (const :tag "RST_RCVD" RST_RCVD)
				  (const :tag "RST_SENT" RST_SENT)
				  (const :tag "RX_PWR" RX_PWR)
				  (const :tag "SAT_MODE" SAT_MODE)
				  (const :tag "SAT_NAME" SAT_NAME)
				  (const :tag "SFI" SFI)
				  (const :tag "SIG" SIG)
				  (const :tag "SIG_INTL" SIG_INTL)
				  (const :tag "SIG_INFO" SIG_INFO)
				  (const :tag "SIG_INFO_INTL" SIG_INFO_INTL)
				  (const :tag "SILENT_KEY" SILENT_KEY)
				  (const :tag "SKCC" SKCC)
				  (const :tag "SOTA_REF" SOTA_REF)
				  (const :tag "SRX" SRX)
				  (const :tag "SRX_STRING" SRX_STRING)
				  (const :tag "STATE" STATE)
				  (const :tag "STATION_CALLSIGN" STATION_CALLSIGN)
				  (const :tag "STX" STX)
				  (const :tag "STX_STRING" STX_STRING)
				  (const :tag "SUBMODE" SUBMODE)
				  (const :tag "SWL" SWL)
				  (const :tag "TEN_TEN" TEN_TEN)
				  (const :tag "TIME_OFF" TIME_OFF)
				  (const :tag "TIME_ON" TIME_ON)
				  (const :tag "TX_PWR" TX_PWR)
				  (const :tag "UKSMG" UKSMG)
				  (const :tag "USACA_COUNTIES" USACA_COUNTIES)
				  (const :tag "VE_PROV" VE_PROV)
				  (const :tag "VUCC_GRIDS" VUCC_GRIDS)
				  (const :tag "WEB" WEB)
				  (const :tag "WWFF_REF" WWFF_REF)
                                  (const :tag "Custom Choice" custom-choice))
                :value-type (boolean :tag "Clear after submission"))
  :group 'qso)

(defvar qso-form-field-definitions
  '((ADDRESS . (editable-field :format "ADDRESS: %v\n" :size 40 :value ""))
    (ADDRESS_INTL . (editable-field :format "ADDRESS_INTL: %v\n" :size 40 :value ""))
    (AGE . (editable-field :format "AGE: %v\n" :size 3 :value ""))
    (ALTITUDE . (editable-field :format "ALTITUDE: %vm\n" :size 4 :value ""))
    (ANT_AZ . (editable-field :format "ANT_AZ: %v\n" :size 3 :value ""))
    (ANT_EL . (editable-field :format "ANT_EL: %v\n" :size 3 :value ""))
    (ANT_PATH . (menu-choice :tag "ANT_PATH" :format "ANT_PATH: %[%v%]" :value ""
			 (item :tag "Short Path" :value "S")
			 (item :tag "Grayline" :value "G")
			 (item :tag "Long Path" :value "L")
			 (item :tag "Other" :value "O")))
    (ARRL_SECT . (editable-field :format "ARRL_SECT: %v\n" :size 3 :value ""))
    (AWARD_GRANTED . (editable-field :format "AWARD_GRANTED: %v\n" :size 40 :value ""))
    (AWARD_SUBMITTED . (editable-field :format "AWARD_SUBMITTED: %v\n" :size 40 :value ""))
    (A_INDEX . (editable-field :format "A_INDEX: %v\n" :size 3 :value ""))
    (BAND . (menu-choice :tag "BAND" :format "BAND: %[%v%]" :value ""
			 (item :tag "2190m" :value "2190m")
			 (item :tag "630m" :value "630m")
			 (item :tag "560m" :value "560m")
			 (item :tag "160m" :value "160m")
			 (item :tag "80m" :value "80m")
			 (item :tag "60m" :value "60m")
			 (item :tag "40m" :value "40m")
			 (item :tag "30m" :value "30m")
			 (item :tag "20m" :value "20m")
			 (item :tag "17m" :value "17m")
			 (item :tag "15m" :value "15m")
			 (item :tag "12m" :value "12m")
			 (item :tag "10m" :value "10m")
			 (item :tag "8m" :value "8m")
			 (item :tag "6m" :value "6m")
			 (item :tag "5m" :value "5m")
			 (item :tag "4m" :value "4m")
			 (item :tag "2m" :value "2m")
			 (item :tag "1.25m" :value "1.25m")
			 (item :tag "70cm" :value "70cm")
			 (item :tag "33cm" :value "33cm")
			 (item :tag "23cm" :value "23cm")
			 (item :tag "13cm" :value "13cm")
			 (item :tag "9cm" :value "9cm")
			 (item :tag "6cm" :value "6cm")
			 (item :tag "3cm" :value "3cm")
			 (item :tag "1.25cm" :value "1.25cm")
			 (item :tag "6mm" :value "6mm")
			 (item :tag "4mm" :value "4mm")
			 (item :tag "2.5mm" :value "2.5mm")
			 (item :tag "2mm" :value "2mm")
			 (item :tag "1mm" :value "1mm")
			 (item :tag "submm" :value "submm")))
    (BAND_RX . (editable-field :format "BAND_RX: %v\n" :size 40 :value ""))
    (CALL . (editable-field :format "CALL: %v " :size 10 :value ""))
    (CHECK . (editable-field :format "CHECK: %v\n" :size 40 :value ""))
    (CLASS . (editable-field :format "CLASS: %v\n" :size 10 :value ""))
    (CLUBLOG_QSO_UPLOAD_DATE . (editable-field :format "CLUBLOG_QSO_UPLOAD_DATE: %v\n" :size 40 :value ""))
    (CLUBLOG_QSO_UPLOAD_STATUS . (editable-field :format "CLUBLOG_QSO_UPLOAD_STATUS: %v\n" :size 40 :value ""))
    (CNTY . (editable-field :format "CNTY: %v\n" :size 40 :value ""))
    (COMMENT . (editable-field :format "COMMENT: %v\n" :size 37 :value ""))
    (COMMENT_INTL . (editable-field :format "COMMENT_INTL: %v\n" :size 32 :value ""))
    (CONT . (editable-field :format "CONT: %v\n" :size 2 :value ""))
    (CONTACTED_OP . (editable-field :format "CONTACTED_OP: %v\n" :size 32 :value ""))
    (CONTEST_ID . (menu-choice :tag "CONTEST_ID" :format "CONTEST_ID: %[%v%]" :value ""
			       (item :tag "PODXS Great Pumpkin Sprint" :value "070-160M-SPRINT")
			       (item :tag "PODXS Three Day Weekend" :value "070-3-DAY")
			       (item :tag "PODXS 31 Flavors" :value "070-31-FLAVORS")
			       (item :tag "PODXS 40m Firecracker Sprint" :value "070-40M-SPRINT")
			       (item :tag "PODXS 80m Jay Hudak Memorial Sprint" :value "070-80M-SPRINT")
			       (item :tag "PODXS PSKFest" :value "070-PSKFEST")
			       (item :tag "PODXS St. Patricks Day" :value "070-ST-PATS-DAY")
			       (item :tag "PODXS Valentine Sprint" :value "070-VALENTINE-SPRINT")
			       (item :tag "Ten-Meter RTTY Contest (2011 onwards)" :value "10-RTTY")
			       (item :tag "Open Season Ten Meter QSO Party" :value "1010-OPEN-SEASON")
			       (item :tag "7th-Area QSO Party" :value "7QP")
			       (item :tag "Alabama QSO Party" :value "AL-QSO-PARTY")
			       (item :tag "JARL All Asian DX Contest (CW)" :value "ALL-ASIAN-DX-CW")
			       (item :tag "JARL All Asian DX Contest (PHONE)" :value "ALL-ASIAN-DX-PHONE")
			       (item :tag "ANARTS WW RTTY" :value "ANARTS-RTTY")
			       (item :tag "Anatolian WW RTTY" :value "ANATOLIAN-RTTY")
			       (item :tag "Asia - Pacific Sprint" :value "AP-SPRINT")
			       (item :tag "Arkansas QSO Party" :value "AR-QSO-PARTY")
			       (item :tag "ARI DX Contest" :value "ARI-DX")
			       (item :tag "ARRL 10 Meter Contest" :value "ARRL-10")
			       (item :tag "ARRL 10 GHz and Up Contest" :value "ARRL-10-GHZ")
			       (item :tag "ARRL 160 Meter Contest" :value "ARRL-160")
			       (item :tag "ARRL 222 MHz and Up Distance Contest" :value "ARRL-222")
			       (item :tag "ARRL International Digital Contest" :value "ARRL-DIGI")
			       (item :tag "ARRL International DX Contest (CW)" :value "ARRL-DX-CW")
			       (item :tag "ARRL International DX Contest (Phone)" :value "ARRL-DX-SSB")
			       (item :tag "ARRL EME contest" :value "ARRL-EME")
			       (item :tag "ARRL Field Day" :value "ARRL-FIELD-DAY")
			       (item :tag "ARRL Rookie Roundup (CW)" :value "ARRL-RR-CW")
			       (item :tag "ARRL Rookie Roundup (RTTY)" :value "ARRL-RR-RTTY")
			       (item :tag "ARRL Rookie Roundup (Phone)" :value "ARRL-RR-SSB")
			       (item :tag "ARRL RTTY Round-Up" :value "ARRL-RTTY")
			       (item :tag "ARRL School Club Roundup" :value "ARRL-SCR")
			       (item :tag "ARRL November Sweepstakes (CW)" :value "ARRL-SS-CW")
			       (item :tag "ARRL November Sweepstakes (Phone)" :value "ARRL-SS-SSB")
			       (item :tag "ARRL August UHF Contest" :value "ARRL-UHF-AUG")
			       (item :tag "ARRL January VHF Sweepstakes" :value "ARRL-VHF-JAN")
			       (item :tag "ARRL June VHF QSO Party" :value "ARRL-VHF-JUN")
			       (item :tag "ARRL September VHF QSO Party" :value "ARRL-VHF-SEP")
			       (item :tag "Arizona QSO Party" :value "AZ-QSO-PARTY")
			       (item :tag "BARTG Spring RTTY Contest" :value "BARTG-RTTY")
			       (item :tag "BARTG Sprint Contest" :value "BARTG-SPRINT")
			       (item :tag "British Columbia QSO Party" :value "BC-QSO-PARTY")
			       (item :tag "California QSO Party" :value "CA-QSO-PARTY")
			       (item :tag "CIS DX Contest" :value "CIS-DX")
			       (item :tag "Colorado QSO Party" :value "CO-QSO-PARTY")
			       (item :tag "CQ WW 160 Meter DX Contest (CW)" :value "CQ-160-CW")
			       (item :tag "CQ WW 160 Meter DX Contest (SSB)" :value "CQ-160-SSB")
			       (item :tag "CQ-M International DX Contest" :value "CQ-M")
			       (item :tag "CQ World-Wide VHF Contest" :value "CQ-VHF")
			       (item :tag "CQ WW WPX Contest (CW)" :value "CQ-WPX-CW")
			       (item :tag "CQ/RJ WW RTTY WPX Contest" :value "CQ-WPX-RTTY")
			       (item :tag "CQ WW WPX Contest (SSB)" :value "CQ-WPX-SSB")
			       (item :tag "CQ WW DX Contest (CW)" :value "CQ-WW-CW")
			       (item :tag "CQ/RJ WW RTTY DX Contest" :value "CQ-WW-RTTY")
			       (item :tag "CQ WW DX Contest (SSB)" :value "CQ-WW-SSB")
			       (item :tag "Connecticut QSO Party" :value "CT-QSO-PARTY")
			       (item :tag "Concurso Verde e Amarelo DX CW Contest" :value "CVA-DX-CW")
			       (item :tag "Concurso Verde e Amarelo DX CW Contest" :value "CVA-DX-SSB")
			       (item :tag "CWops CW Open Competition" :value "CWOPS-CW-OPEN")
			       (item :tag "CWops Mini-CWT Test" :value "CWOPS-CWT")
			       (item :tag "WAE DX Contest (CW)" :value "DARC-WAEDC-CW")
			       (item :tag "WAE DX Contest (RTTY)" :value "DARC-WAEDC-RTTY")
			       (item :tag "WAE DX Contest (SSB)" :value "DARC-WAEDC-SSB")
			       (item :tag "DARC Worked All Germany" :value "DARC-WAG")
			       (item :tag "Delaware QSO Party" :value "DE-QSO-PARTY")
			       (item :tag "DL-DX RTTY Contest" :value "DL-DX-RTTY")
			       (item :tag "DMC RTTY Contest" :value "DMC-RTTY")
			       (item :tag "Concurso Nacional de Telegrafía" :value "EA-CNCW")
			       (item :tag "Municipios Españoles" :value "EA-DME")
			       (item :tag "His Majesty The King of Spain CW Contest (2022 and later)" :value "EA-MAJESTAD-CW")
			       (item :tag "His Majesty The King of Spain SSB Contest (2022 and later)" :value "EA-MAJESTAD-SSB")
			       (item :tag "EA PSK63" :value "EA-PSK63")
			       (item :tag "Unión de Radioaficionados Españoles RTTY Contest" :value "EA-RTTY (import-only)")
			       (item :tag "Su Majestad El Rey de España - CW (2021 and earlier)" :value "EA-SMRE-CW")
			       (item :tag "Su Majestad El Rey de España - SSB (2021 and earlier)" :value "EA-SMRE-SSB")
			       (item :tag "Atlántico V-UHF" :value "EA-VHF-ATLANTIC")
			       (item :tag "Combinado de V-UHF" :value "EA-VHF-COM")
			       (item :tag "Costa del Sol V-UHF" :value "EA-VHF-COSTA-SOL")
			       (item :tag "Nacional VHF" :value "EA-VHF-EA")
			       (item :tag "Segovia EA1RCS V-UHF" :value "EA-VHF-EA1RCS")
			       (item :tag "QSL V-UHF & 50MHz" :value "EA-VHF-QSL")
			       (item :tag "Sant Sadurni V-UHF" :value "EA-VHF-SADURNI")
			       (item :tag "Unión de Radioaficionados Españoles RTTY Contest" :value "EA-WW-RTTY")
			       (item :tag "PSK63 QSO Party" :value "EPC-PSK63")
			       (item :tag "EU Sprint" :value "EU Sprint")
			       (item :tag "EU HF Championship" :value "EU-HF")
			       (item :tag "EU PSK DX Contest" :value "EU-PSK-DX")
			       (item :tag "European CW Association 160m CW Party" :value "EUCW160M")
			       (item :tag "FISTS Fall Sprint" :value "FALL SPRINT")
			       (item :tag "Florida QSO Party" :value "FL-QSO-PARTY")
			       (item :tag "Georgia QSO Party" :value "GA-QSO-PARTY")
			       (item :tag "Hungarian DX Contest" :value "HA-DX")
			       (item :tag "Helvetia Contest" :value "HELVETIA")
			       (item :tag "Hawaiian QSO Party" :value "HI-QSO-PARTY")
			       (item :tag "IARC Holyland Contest" :value "HOLYLAND")
			       (item :tag "Iowa QSO Party" :value "IA-QSO-PARTY")
			       (item :tag "DARC IARU Region 1 Field Day" :value "IARU-FIELD-DAY")
			       (item :tag "IARU HF World Championship" :value "IARU-HF")
			       (item :tag "ICWC Medium Speed Test" :value "ICWC-MST")
			       (item :tag "Idaho QSO Party" :value "ID-QSO-PARTY")
			       (item :tag "Illinois QSO Party" :value "IL QSO Party")
			       (item :tag "Indiana QSO Party" :value "IN-QSO-PARTY")
			       (item :tag "JARTS WW RTTY" :value "JARTS-WW-RTTY")
			       (item :tag "Japan International DX Contest (CW)" :value "JIDX-CW")
			       (item :tag "Japan International DX Contest (SSB)" :value "JIDX-SSB")
			       (item :tag "Mongolian RTTY DX Contest" :value "JT-DX-RTTY")
			       (item :tag "K1USN Slow Speed Test" :value "K1USN-SST")
			       (item :tag "Kansas QSO Party" :value "KS-QSO-PARTY")
			       (item :tag "Kentucky QSO Party" :value "KY-QSO-PARTY")
			       (item :tag "Louisiana QSO Party" :value "LA-QSO-PARTY")
			       (item :tag "DRCG Long Distance Contest (RTTY)" :value "LDC-RTTY")
			       (item :tag "LZ DX Contest" :value "LZ DX")
			       (item :tag "Maritimes QSO Party" :value "MAR-QSO-PARTY")
			       (item :tag "Maryland QSO Party" :value "MD-QSO-PARTY")
			       (item :tag "Maine QSO Party" :value "ME-QSO-PARTY")
			       (item :tag "Michigan QSO Party" :value "MI-QSO-PARTY")
			       (item :tag "Mid-Atlantic QSO Party" :value "MIDATLANTIC-QSO-PARTY")
			       (item :tag "Minnesota QSO Party" :value "MN-QSO-PARTY")
			       (item :tag "Missouri QSO Party" :value "MO-QSO-PARTY")
			       (item :tag "Mississippi QSO Party" :value "MS-QSO-PARTY")
			       (item :tag "Montana QSO Party" :value "MT-QSO-PARTY")
			       (item :tag "North America Sprint (CW)" :value "NA-SPRINT-CW")
			       (item :tag "North America Sprint (RTTY)" :value "NA-SPRINT-RTTY")
			       (item :tag "North America Sprint (Phone)" :value "NA-SPRINT-SSB")
			       (item :tag "North America QSO Party (CW)" :value "NAQP-CW")
			       (item :tag "North America QSO Party (RTTY)" :value "NAQP-RTTY")
			       (item :tag "North America QSO Party (Phone)" :value "NAQP-SSB")
			       (item :tag "North Carolina QSO Party" :value "NC-QSO-PARTY")
			       (item :tag "North Dakota QSO Party" :value "ND-QSO-PARTY")
			       (item :tag "Nebraska QSO Party" :value "NE-QSO-PARTY")
			       (item :tag "New England QSO Party" :value "NEQP")
			       (item :tag "New Hampshire QSO Party" :value "NH-QSO-PARTY")
			       (item :tag "New Jersey QSO Party" :value "NJ-QSO-PARTY")
			       (item :tag "New Mexico QSO Party" :value "NM-QSO-PARTY")
			       (item :tag "NRAU-Baltic Contest (CW)" :value "NRAU-BALTIC-CW")
			       (item :tag "NRAU-Baltic Contest (SSB)" :value "NRAU-BALTIC-SSB")
			       (item :tag "Nevada QSO Party" :value "NV-QSO-PARTY")
			       (item :tag "New York QSO Party" :value "NY-QSO-PARTY")
			       (item :tag "Oceania DX Contest (CW)" :value "OCEANIA-DX-CW")
			       (item :tag "Oceania DX Contest (SSB)" :value "OCEANIA-DX-SSB")
			       (item :tag "Ohio QSO Party" :value "OH-QSO-PARTY")
			       (item :tag "Czech Radio Club OK DX Contest" :value "OK-DX-RTTY")
			       (item :tag "Czech Radio Club OK-OM DX Contest" :value "OK-OM-DX")
			       (item :tag "Oklahoma QSO Party" :value "OK-QSO-PARTY")
			       (item :tag "Old Man International Sideband Society QSO Party" :value "OMISS-QSO-PARTY")
			       (item :tag "Ontario QSO Party" :value "ON-QSO-PARTY")
			       (item :tag "Oregon QSO Party" :value "OR-QSO-PARTY")
			       (item :tag "Pennsylvania QSO Party" :value "PA-QSO-PARTY")
			       (item :tag "Dutch PACC Contest" :value "PACC")
			       (item :tag "MDXA PSK DeathMatch (2005-2010)" :value "PSK-DEATHMATCH")
			       (item :tag "Quebec QSO Party" :value "QC-QSO-PARTY")
			       (item :tag "Canadian Amateur Radio Society Contest" :value "RAC (import-only)")
			       (item :tag "RAC Canada Day Contest" :value "RAC-CANADA-DAY")
			       (item :tag "RAC Canada Winter Contest" :value "RAC-CANADA-WINTER")
			       (item :tag "Russian District Award Contest" :value "RDAC")
			       (item :tag "Russian DX Contest" :value "RDXC")
			       (item :tag "Reseau des Emetteurs Francais 160m Contest" :value "REF-160M")
			       (item :tag "Reseau des Emetteurs Francais Contest (CW)" :value "REF-CW")
			       (item :tag "Reseau des Emetteurs Francais Contest (SSB)" :value "REF-SSB")
			       (item :tag "Rede dos Emissores Portugueses Portugal Day HF Contest" :value "REP-PORTUGAL-DAY-HF")
			       (item :tag "Rhode Island QSO Party" :value "RI-QSO-PARTY")
			       (item :tag "1.8MHz Contest" :value "RSGB-160")
			       (item :tag "21/28 MHz Contest (CW)" :value "RSGB-21/28-CW")
			       (item :tag "21/28 MHz Contest (SSB)" :value "RSGB-21/28-SSB")
			       (item :tag "80m Club Championships" :value "RSGB-80M-CC")
			       (item :tag "Affiliated Societies Team Contest (CW)" :value "RSGB-AFS-CW")
			       (item :tag "Affiliated Societies Team Contest (SSB)" :value "RSGB-AFS-SSB")
			       (item :tag "Club Calls" :value "RSGB-CLUB-CALLS")
			       (item :tag "Commonwealth Contest" :value "RSGB-COMMONWEALTH")
			       (item :tag "IOTA Contest" :value "RSGB-IOTA")
			       (item :tag "Low Power Field Day" :value "RSGB-LOW-POWER")
			       (item :tag "National Field Day" :value "RSGB-NFD")
			       (item :tag "RoPoCo" :value "RSGB-ROPOCO")
			       (item :tag "SSB Field Day" :value "RSGB-SSB-FD")
			       (item :tag "Russian Radio RTTY Worldwide Contest" :value "RUSSIAN-RTTY")
			       (item :tag "Scandinavian Activity Contest (CW)" :value "SAC-CW")
			       (item :tag "Scandinavian Activity Contest (SSB)" :value "SAC-SSB")
			       (item :tag "SARTG WW RTTY" :value "SARTG-RTTY")
			       (item :tag "South Carolina QSO Party" :value "SC-QSO-PARTY")
			       (item :tag "SCC RTTY Championship" :value "SCC-RTTY")
			       (item :tag "South Dakota QSO Party" :value "SD-QSO-PARTY")
			       (item :tag "SSA Portabeltest" :value "SMP-AUG")
			       (item :tag "SSA Portabeltest" :value "SMP-MAY")
			       (item :tag "PRC SPDX Contest (RTTY)" :value "SP-DX-RTTY")
			       (item :tag "SPAR Winter Field Day(2016 and earlier)" :value "SPAR-WINTER-FD")
			       (item :tag "SP DX Contest" :value "SPDXContest")
			       (item :tag "FISTS Spring Sprint" :value "SPRING SPRINT")
			       (item :tag "Scottish-Russian Marathon" :value "SR-MARATHON")
			       (item :tag "Stew Perry Topband Distance Challenge" :value "STEW-PERRY")
			       (item :tag "FISTS Summer Sprint" :value "SUMMER SPRINT")
			       (item :tag "TARA Grid Dip PSK-RTTY Shindig" :value "TARA-GRID-DIP")
			       (item :tag "TARA RTTY Mêlée" :value "TARA-RTTY")
			       (item :tag "TARA Rumble PSK Contest" :value "TARA-RUMBLE")
			       (item :tag "TARA Skirmish Digital Prefix Contest" :value "TARA-SKIRMISH")
			       (item :tag "Ten-Meter RTTY Contest (before 2011)" :value "TEN-RTTY")
			       (item :tag "The Makrothen Contest" :value "TMC-RTTY")
			       (item :tag "Tennessee QSO Party" :value "TN-QSO-PARTY")
			       (item :tag "Texas QSO Party" :value "TX-QSO-PARTY")
			       (item :tag "UBA Contest (CW)" :value "UBA-DX-CW")
			       (item :tag "UBA Contest (SSB)" :value "UBA-DX-SSB")
			       (item :tag "European PSK Club BPSK63 Contest" :value "UK-DX-BPSK63")
			       (item :tag "UK DX RTTY Contest" :value "UK-DX-RTTY")
			       (item :tag "Open Ukraine RTTY Championship" :value "UKR-CHAMP-RTTY")
			       (item :tag "Ukrainian DX" :value "UKRAINIAN DX")
			       (item :tag "UKSMG 6m Marathon" :value "UKSMG-6M-MARATHON")
			       (item :tag "UKSMG Summer Es Contest" :value "UKSMG-SUMMER-ES")
			       (item :tag "Ukrainian DX Contest" :value "URE-DX  (import-only)")
			       (item :tag "Mobile Amateur Awards Club" :value "US-COUNTIES-QSO")
			       (item :tag "Utah QSO Party" :value "UT-QSO-PARTY")
			       (item :tag "Virginia QSO Party" :value "VA-QSO-PARTY")
			       (item :tag "RCV Venezuelan Independence Day Contest" :value "VENEZ-IND-DAY")
			       (item :tag "Virginia QSO Party" :value "VIRGINIA QSO PARTY (import-only)")
			       (item :tag "Alessandro Volta RTTY DX Contest" :value "VOLTA-RTTY")
			       (item :tag "Vermont QSO Party" :value "VT-QSO-PARTY")
			       (item :tag "Washington QSO Party" :value "WA-QSO-PARTY")
			       (item :tag "Winter Field Day (2017 and later)" :value "WFD")
			       (item :tag "Wisconsin QSO Party" :value "WI-QSO-PARTY")
			       (item :tag "WIA Harry Angel Memorial 80m Sprint" :value "WIA-HARRY ANGEL")
			       (item :tag "WIA John Moyle Memorial Field Day" :value "WIA-JMMFD")
			       (item :tag "WIA Oceania DX (OCDX) Contest" :value "WIA-OCDX")
			       (item :tag "WIA Remembrance Day" :value "WIA-REMEMBRANCE")
			       (item :tag "WIA Ross Hull Memorial VHF/UHF Contest" :value "WIA-ROSS HULL")
			       (item :tag "WIA Trans Tasman Low Bands Challenge" :value "WIA-TRANS TASMAN")
			       (item :tag "WIA VHF UHF Field Days" :value "WIA-VHF/UHF FD")
			       (item :tag "WIA VK Shires" :value "WIA-VK SHIRES")
			       (item :tag "FISTS Winter Sprint" :value "WINTER SPRINT")
			       (item :tag "West Virginia QSO Party" :value "WV-QSO-PARTY")
			       (item :tag "World Wide Digi DX Contest" :value "WW-DIGI")
			       (item :tag "Wyoming QSO Party" :value "WY-QSO-PARTY")
			       (item :tag "Mexico International Contest (RTTY)" :value "XE-INTL-RTTY")
			       (item :tag "YODX HF contest" :value "YOHFDX")
			       (item :tag "YU DX Contest" :value "YUDXC")))
    (COUNTRY . (editable-field :format "COUNTRY: %v\n" :size 37 :value ""))
    (COUNTRY_INTL . (editable-field :format "COUNTRY_INTL: %v\n" :size 32 :value ""))
    (CQZ . (editable-field :format "CQZ: %v\n" :size 40 :value ""))
    (CREDIT_SUBMITTED . (editable-field :format "CREDIT_SUBMITTED: %v\n" :size 40 :value ""))
    (CREDIT_GRANTED . (editable-field :format "CREDIT_GRANTED: %v\n" :size 40 :value ""))
    (DARC_DOK . (editable-field :format "DARC_DOK: %v\n" :size 40 :value ""))
    (DISTANCE . (editable-field :format "DISTANCE: %v\n" :size 40 :value ""))
    (DXCC . (editable-field :format "DXCC: %v\n" :size 40 :value ""))
    (EMAIL . (editable-field :format "EMAIL: %v\n" :size 39 :value ""))
    (EQ_CALL . (editable-field :format "EQ_CALL: %v\n" :size 40 :value ""))
    (EQSL_QSLRDATE . (editable-field :format "EQSL_QSLRDATE: %v\n" :size 40 :value ""))
    (EQSL_QSLSDATE . (editable-field :format "EQSL_QSLSDATE: %v\n" :size 40 :value ""))
    (EQSL_QSL_RCVD . (editable-field :format "EQSL_QSL_RCVD: %v\n" :size 40 :value ""))
    (EQSL_QSL_SENT . (editable-field :format "EQSL_QSL_SENT: %v\n" :size 40 :value ""))
    (FISTS . (editable-field :format "FISTS: %v\n" :size 40 :value ""))
    (FISTS_CC . (editable-field :format "FISTS_CC: %v\n" :size 40 :value ""))
    (FORCE_INIT . (editable-field :format "FORCE_INIT: %v\n" :size 40 :value ""))
    (FREQ . (editable-field :format "FREQ: %vMHz\n" :size 10 :value ""))
    (FREQ_RX . (editable-field :format "FREQ_RX: %vMHz\n" :size 10 :value ""))
    (GRIDSQUARE . (editable-field :format "GRIDSQUARE: %v\n" :size 6 :value ""))
    (GRIDSQUARE_EXT . (editable-field :format "GRIDSQUARE_EXT: %v\n" :size 6 :value ""))
    (GUEST_OP . (editable-field :format "GUEST_OP: %v\n" :size 36 :value ""))
    (HAMLOGEU_QSO_UPLOAD_DATE . (editable-field :format "HAMLOGEU_QSO_UPLOAD_DATE: %v\n" :size 40 :value ""))
    (HAMLOGEU_QSO_UPLOAD_STATUS . (editable-field :format "HAMLOGEU_QSO_UPLOAD_STATUS: %v\n" :size 40 :value ""))
    (HAMQTH_QSO_UPLOAD_DATE . (editable-field :format "HAMQTH_QSO_UPLOAD_DATE: %v\n" :size 40 :value ""))
    (HAMQTH_QSO_UPLOAD_STATUS . (editable-field :format "HAMQTH_QSO_UPLOAD_STATUS: %v\n" :size 40 :value ""))
    (HRDLOG_QSO_UPLOAD_DATE . (editable-field :format "HRDLOG_QSO_UPLOAD_DATE: %v\n" :size 40 :value ""))
    (HRDLOG_QSO_UPLOAD_STATUS . (editable-field :format "HRDLOG_QSO_UPLOAD_STATUS: %v\n" :size 40 :value ""))
    (IOTA . (editable-field :format "IOTA: %v\n" :size 40 :value ""))
    (IOTA_ISLAND_ID . (editable-field :format "IOTA_ISLAND_ID: %v\n" :size 40 :value ""))
    (ITUZ . (editable-field :format "ITUZ: %v\n" :size 40 :value ""))
    (K_INDEX . (editable-field :format "K_INDEX: %v\n" :size 3 :value ""))
    (LAT . (editable-field :format "LAT: %v\n" :size 11 :value ""))
    (LON . (editable-field :format "LON: %v\n" :size 11 :value ""))
    (LOTW_QSLRDATE . (editable-field :format "LOTW_QSLRDATE: %v\n" :size 40 :value ""))
    (LOTW_QSLSDATE . (editable-field :format "LOTW_QSLSDATE: %v\n" :size 40 :value ""))
    (LOTW_QSL_RCVD . (editable-field :format "LOTW_QSL_RCVD: %v\n" :size 40 :value ""))
    (LOTW_QSL_SENT . (editable-field :format "LOTW_QSL_SENT: %v\n" :size 40 :value ""))
    (MAX_BURSTS . (editable-field :format "MAX_BURSTS: %v\n" :size 40 :value ""))
    (MODE . (menu-choice :tag "MODE" :format "MODE: %[%v%]" :value ""
			  (item :tag "AM" :value "AM")
			  (item :tag "ARDOP" :value "ARDOP")
			  (item :tag "ATV" :value "ATV")
			  (item :tag "CHIP" :value "CHIP")
			  (item :tag "CLO" :value "CLO")
			  (item :tag "CONTESTI" :value "CONTESTI")
			  (item :tag "CW" :value "CW")
			  (item :tag "DIGITALVOICE" :value "DIGITALVOICE")
			  (item :tag "DOMINO" :value "DOMINO")
			  (item :tag "DYNAMIC" :value "DYNAMIC")
			  (item :tag "FAX" :value "FAX")
			  (item :tag "FM" :value "FM")
			  (item :tag "FSK441" :value "FSK441")
			  (item :tag "FT8" :value "FT8")
			  (item :tag "HELL" :value "HELL")
			  (item :tag "ISCAT" :value "ISCAT")
			  (item :tag "JT4" :value "JT4")
			  (item :tag "JT6M" :value "JT6M")
			  (item :tag "JT9" :value "JT9")
			  (item :tag "JT44" :value "JT44")
			  (item :tag "JT65" :value "JT65")
			  (item :tag "MFSK" :value "MFSK")
			  (item :tag "MSK144" :value "MSK144")
			  (item :tag "MT63" :value "MT63")
			  (item :tag "OLIVIA" :value "OLIVIA")
			  (item :tag "OPERA" :value "OPERA")
			  (item :tag "PAC" :value "PAC")
			  (item :tag "PAX" :value "PAX")
			  (item :tag "PKT" :value "PKT")
			  (item :tag "PSK" :value "PSK")
			  (item :tag "PSK2K" :value "PSK2K")
			  (item :tag "Q15" :value "Q15")
			  (item :tag "QRA64" :value "QRA64")
			  (item :tag "ROS" :value "ROS")
			  (item :tag "RTTY" :value "RTTY")
			  (item :tag "RTTYM" :value "RTTYM")
			  (item :tag "SSB" :value "SSB")
			  (item :tag "SSTV" :value "SSTV")
			  (item :tag "T10" :value "T10")
			  (item :tag "THOR" :value "THOR")
			  (item :tag "THRB" :value "THRB")
			  (item :tag "TOR" :value "TOR")
			  (item :tag "V4" :value "V4")
			  (item :tag "VOI" :value "VOI")
			  (item :tag "WINMOR" :value "WINMOR")
			  (item :tag "WSPR" :value "WSPR")))
    (MS_SHOWER . (editable-field :format "MS_SHOWER: %v\n" :size 40 :value ""))
    (MY_ALTITUDE . (editable-field :format "MY_ALTITUDE: %v\n" :size 40 :value ""))
    (MY_ANTENNA . (editable-field :format "MY_ANTENNA: %v\n" :size 40 :value ""))
    (MY_ARRL_SECT . (editable-field :format "MY_ARRL_SECT: %v\n" :size 3 :value ""))
    (MY_CITY . (editable-field :format "MY_CITY: %v\n" :size 40 :value ""))
    (MY_CITY_INTL . (editable-field :format "MY_CITY_INTL: %v\n" :size 40 :value ""))
    (MY_CNTY . (editable-field :format "MY_CNTY: %v\n" :size 40 :value ""))
    (MY_COUNTRY . (editable-field :format "MY_COUNTRY: %v\n" :size 40 :value ""))
    (MY_COUNTRY_INTL . (editable-field :format "MY_COUNTRY_INTL: %v\n" :size 40 :value ""))
    (MY_CQ_ZONE . (editable-field :format "MY_CQ_ZONE: %v\n" :size 40 :value ""))
    (MY_DXCC . (editable-field :format "MY_DXCC: %v\n" :size 40 :value ""))
    (MY_FISTS . (editable-field :format "MY_FISTS: %v\n" :size 40 :value ""))
    (MY_GRIDSQUARE . (editable-field :format "MY_GRIDSQUARE: %v\n" :size 40 :value ""))
    (MY_GRIDSQUARE_EXT . (editable-field :format "MY_GRIDSQUARE_EXT: %v\n" :size 40 :value ""))
    (MY_IOTA . (editable-field :format "MY_IOTA: %v\n" :size 40 :value ""))
    (MY_IOTA_ISLAND_ID . (editable-field :format "MY_IOTA_ISLAND_ID: %v\n" :size 40 :value ""))
    (MY_ITU_ZONE . (editable-field :format "MY_ITU_ZONE: %v\n" :size 40 :value ""))
    (MY_LAT . (editable-field :format "MY_LAT: %v\n" :size 40 :value ""))
    (MY_LON . (editable-field :format "MY_LON: %v\n" :size 40 :value ""))
    (MY_NAME . (editable-field :format "MY_NAME: %v\n" :size 40 :value ""))
    (MY_NAME_INTL . (editable-field :format "MY_NAME_INTL: %v\n" :size 40 :value ""))
    (MY_POSTAL_CODE . (editable-field :format "MY_POSTAL_CODE: %v\n" :size 40 :value ""))
    (MY_POSTAL_CODE_INTL . (editable-field :format "MY_POSTAL_CODE_INTL: %v\n" :size 40 :value ""))
    (MY_POTA_REF . (editable-field :format "MY_POTA_REF: %v\n" :size 40 :value ""))
    (MY_RIG . (editable-field :format "MY_RIG: %v\n" :size 40 :value ""))
    (MY_RIG_INTL . (editable-field :format "MY_RIG_INTL: %v\n" :size 40 :value ""))
    (MY_SIG . (editable-field :format "MY_SIG: %v\n" :size 40 :value ""))
    (MY_SIG_INTL . (editable-field :format "MY_SIG_INTL: %v\n" :size 40 :value ""))
    (MY_SIG_INFO . (editable-field :format "MY_SIG_INFO: %v\n" :size 40 :value ""))
    (MY_SIG_INFO_INTL . (editable-field :format "MY_SIG_INFO_INTL: %v\n" :size 40 :value ""))
    (MY_SOTA_REF . (editable-field :format "MY_SOTA_REF: %v\n" :size 40 :value ""))
    (MY_STATE . (editable-field :format "MY_STATE: %v\n" :size 40 :value ""))
    (MY_STREET . (editable-field :format "MY_STREET: %v\n" :size 40 :value ""))
    (MY_STREET_INTL . (editable-field :format "MY_STREET_INTL: %v\n" :size 40 :value ""))
    (MY_USACA_COUNTIES . (editable-field :format "MY_USACA_COUNTIES: %v\n" :size 40 :value ""))
    (MY_VUCC_GRIDS . (editable-field :format "MY_VUCC_GRIDS: %v\n" :size 40 :value ""))
    (MY_WWFF_REF . (editable-field :format "MY_WWFF_REF: %v\n" :size 40 :value ""))
    (NAME . (editable-field :format "NAME: %v\n" :size 40 :value ""))
    (NAME_INTL . (editable-field :format "NAME_INTL: %v\n" :size 40 :value ""))
    (NOTES . (editable-field :format "NOTES: %v\n" :size 40 :value ""))
    (NOTES_INTL . (editable-field :format "NOTES_INTL: %v\n" :size 40 :value ""))
    (NR_BURSTS . (editable-field :format "NR_BURSTS: %v\n" :size 40 :value ""))
    (NR_PINGS . (editable-field :format "NR_PINGS: %v\n" :size 40 :value ""))
;    (OPERATOR . (editable-field :format "OPERATOR: %v\n" :size 40 :value ""))
    (OWNER_CALLSIGN . (editable-field :format "OWNER_CALLSIGN: %v\n" :size 10 :value ""))
    (PFX . (editable-field :format "PFX: %v\n" :size 40 :value ""))
    (POTA_REF . (editable-field :format "POTA_REF: %v\n" :size 40 :value ""))
    (PRECEDENCE . (editable-field :format "PRECEDENCE: %v\n" :size 40 :value ""))
    (PROP_MODE . (menu-choice :tag "PROP_MODE" :format "PROP_MODE: %[%v%]" :value ""
			      (item :tag "Aircraft Scatter" :value "AS")
			      (item :tag "Aurora-E" :value "AUE")
			      (item :tag "Aurora" :value "AUR")
			      (item :tag "Back scatter" :value "BS")
			      (item :tag "EchoLink" :value "ECH")
			      (item :tag "Earth-Moon-Earth" :value "EME")
			      (item :tag "Sporadic E" :value "ES")
			      (item :tag "F2 Reflection" :value "F2")
			      (item :tag "Field Aligned Irregularities" :value "FAI")
			      (item :tag "Ground Wave" :value "GWAVE")
			      (item :tag "Internet-assisted" :value "INTERNET")
			      (item :tag "Ionoscatter" :value "ION")
			      (item :tag "IRLP" :value "IRL")
			      (item :tag "Line of Sight (includes transmission through obstacles such as walls)" :value "LOS")
			      (item :tag "Meteor scatter" :value "MS")
			      (item :tag "Terrestrial or atmospheric repeater or transponder" :value "RPT")
			      (item :tag "Rain scatter" :value "RS")
			      (item :tag "Satellite" :value "SAT")
			      (item :tag "Trans-equatorial" :value "TEP")
			      (item :tag "Tropospheric ducting" :value "TR")))
    (PUBLIC_KEY . (editable-field :format "PUBLIC_KEY: %v\n" :size 40 :value ""))
    (QRZCOM_QSO_UPLOAD_DATE . (editable-field :format "QRZCOM_QSO_UPLOAD_DATE: %v\n" :size 40 :value ""))
    (QRZCOM_QSO_UPLOAD_STATUS . (editable-field :format "QRZCOM_QSO_UPLOAD_STATUS: %v\n" :size 40 :value ""))
    (QSLMSG . (editable-field :format "QSLMSG: %v\n" :size 40 :value ""))
    (QSLMSG_INTL . (editable-field :format "QSLMSG_INTL: %v\n" :size 40 :value ""))
    (QSLRDATE . (editable-field :format "QSLRDATE: %v\n" :size 8 :value ""))
    (QSLSDATE . (editable-field :format "QSLSDATE: %v\n" :size 8 :value ""))
    (QSL_RCVD . (editable-field :format "QSL_RCVD: %v\n" :size 1 :value ""))
    (QSL_RCVD_VIA . (editable-field :format "QSL_RCVD_VIA: %v\n" :size 1 :value ""))
    (QSL_SENT . (editable-field :format "QSL_SENT: %v\n" :size 1 :value ""))
    (QSL_SENT_VIA . (editable-field :format "QSL_SENT_VIA: %v\n" :size 1 :value ""))
    (QSL_VIA . (editable-field :format "QSL_VIA: %v\n" :size 1 :value ""))
    (QSO_COMPLETE . (editable-field :format "QSO_COMPLETE: %v\n" :size 3 :value ""))
    (QSO_DATE . (editable-field :format "QSO_DATE: %v\n" :size 8 :value ""))
    (QSO_DATE_OFF . (editable-field :format "QSO_DATE_OFF: %v\n" :size 8 :value ""))
    (QSO_RANDOM . (editable-field :format "QSO_RANDOM: %v\n" :size 1 :value ""))
    (QTH . (editable-field :format "QTH: %v\n" :size 40 :value ""))
    (QTH_INTL . (editable-field :format "QTH_INTL: %v\n" :size 40 :value ""))
    (REGION . (editable-field :format "REGION: %v\n" :size 40 :value ""))
    (RIG . (editable-field :format "RIG: %v\n" :size 40 :value ""))
    (RIG_INTL . (editable-field :format "RIG_INTL: %v\n" :size 40 :value ""))
    (RST_RCVD . (editable-field :format "RST_RCVD: %v\n" :size 6 :value ""))
    (RST_SENT . (editable-field :format "RST_SENT: %v\n" :size 6 :value ""))
    (RX_PWR . (editable-field :format "RX_PWR: %vW\n" :size 6 :value ""))
    (SAT_MODE . (editable-field :format "SAT_MODE: %v\n" :size 40 :value ""))
    (SAT_NAME . (editable-field :format "SAT_NAME: %v\n" :size 40 :value ""))
    (SFI . (editable-field :format "SFI: %v\n" :size 40 :value ""))
    (SIG . (editable-field :format "SIG: %v\n" :size 40 :value ""))
    (SIG_INTL . (editable-field :format "SIG_INTL: %v\n" :size 40 :value ""))
    (SIG_INFO . (editable-field :format "SIG_INFO: %v\n" :size 40 :value ""))
    (SIG_INFO_INTL . (editable-field :format "SIG_INFO_INTL: %v\n" :size 40 :value ""))
    (SILENT_KEY . (editable-field :format "SILENT_KEY: %v\n" :size 1 :value ""))
    (SKCC . (editable-field :format "SKCC: %v\n" :size 40 :value ""))
    (SOTA_REF . (editable-field :format "SOTA_REF: %v\n" :size 40 :value ""))
    (SRX . (editable-field :format "SRX: %v\n" :size 6 :value ""))
    (SRX_STRING . (editable-field :format "SRX_STRING: %v\n" :size 40 :value ""))
    (STATE . (editable-field :format "STATE: %v\n" :size 40 :value ""))
    (STATION_CALLSIGN . (editable-field :format "STATION_CALLSIGN: %v\n" :size 40 :value ""))
    (STX . (editable-field :format "STX: %v\n" :size 40 :value ""))
    (STX_STRING . (editable-field :format "STX_STRING: %v\n" :size 40 :value ""))
    (SUBMODE . (menu-choice :format "SUBMODE: %[%v%]" :value ""
			    (item :tag "8PSK125 (PSK)" :value "8PSK125")
			    (item :tag "8PSK125F (PSK)" :value "8PSK125F")
			    (item :tag "8PSK125FL (PSK)" :value "8PSK125FL")
			    (item :tag "8PSK250 (PSK)" :value "8PSK250")
			    (item :tag "8PSK250F (PSK)" :value "8PSK250F")
			    (item :tag "8PSK250FL (PSK)" :value "8PSK250FL")
			    (item :tag "8PSK500 (PSK)" :value "8PSK500")
			    (item :tag "8PSK500F (PSK)" :value "8PSK500F")
			    (item :tag "8PSK1000 (PSK)" :value "8PSK1000")
			    (item :tag "8PSK1000F (PSK)" :value "8PSK1000F")
			    (item :tag "8PSK1200F (PSK)" :value "8PSK1200F")
			    (item :tag "AMTORFEC (TOR)" :value "AMTORFEC")
			    (item :tag "ASCI (RTTY)" :value "ASCI")
			    (item :tag "C4FM (DIGITALVOICE)" :value "C4FM")
			    (item :tag "CHIP64 (CHIP)" :value "CHIP64")
			    (item :tag "CHIP128 (CHIP)" :value "CHIP128")
			    (item :tag "DMR (DIGITALVOICE)" :value "DMR")
			    (item :tag "DOM-M (DOMINO)" :value "DOM-M")
			    (item :tag "DOM4 (DOMINO)" :value "DOM4")
			    (item :tag "DOM5 (DOMINO)" :value "DOM5")
			    (item :tag "DOM8 (DOMINO)" :value "DOM8")
			    (item :tag "DOM11 (DOMINO)" :value "DOM11")
			    (item :tag "DOM16 (DOMINO)" :value "DOM16")
			    (item :tag "DOM22 (DOMINO)" :value "DOM22")
			    (item :tag "DOM44 (DOMINO)" :value "DOM44")
			    (item :tag "DOM88 (DOMINO)" :value "DOM88")
			    (item :tag "DOMINOEX (DOMINO)" :value "DOMINOEX")
			    (item :tag "DOMINOF (DOMINO)" :value "DOMINOF")
			    (item :tag "DSTAR (DIGITALVOICE)" :value "DSTAR")
			    (item :tag "FMHELL (HELL)" :value "FMHELL")
			    (item :tag "FREEDV (DIGITALVOICE)" :value "FREEDV")
			    (item :tag "FSK31 (PSK)" :value "FSK31")
			    (item :tag "FSKHELL (HELL)" :value "FSKHELL")
			    (item :tag "FSQCALL (MFSK)" :value "FSQCALL")
			    (item :tag "FST4 (MFSK)" :value "FST4")
			    (item :tag "FST4W (MFSK)" :value "FST4W")
			    (item :tag "FT4 (MFSK)" :value "FT4")
			    (item :tag "GTOR (TOR)" :value "GTOR")
			    (item :tag "HELL80 (HELL)" :value "HELL80")
			    (item :tag "HELLX5 (HELL)" :value "HELLX5")
			    (item :tag "HELLX9 (HELL)" :value "HELLX9")
			    (item :tag "HFSK (HELL)" :value "HFSK")
			    (item :tag "ISCAT-A (ISCAT)" :value "ISCAT-A")
			    (item :tag "ISCAT-B (ISCAT)" :value "ISCAT-B")
			    (item :tag "JS8 (MFSK)" :value "JS8")
			    (item :tag "JT4A (JT4)" :value "JT4A")
			    (item :tag "JT4B (JT4)" :value "JT4B")
			    (item :tag "JT4C (JT4)" :value "JT4C")
			    (item :tag "JT4D (JT4)" :value "JT4D")
			    (item :tag "JT4E (JT4)" :value "JT4E")
			    (item :tag "JT4F (JT4)" :value "JT4F")
			    (item :tag "JT4G (JT4)" :value "JT4G")
			    (item :tag "JT9-1 (JT9)" :value "JT9-1")
			    (item :tag "JT9-2 (JT9)" :value "JT9-2")
			    (item :tag "JT9-5 (JT9)" :value "JT9-5")
			    (item :tag "JT9-10 (JT9)" :value "JT9-10")
			    (item :tag "JT9-30 (JT9)" :value "JT9-30")
			    (item :tag "JT9A (JT9)" :value "JT9A")
			    (item :tag "JT9B (JT9)" :value "JT9B")
			    (item :tag "JT9C (JT9)" :value "JT9C")
			    (item :tag "JT9D (JT9)" :value "JT9D")
			    (item :tag "JT9E (JT9)" :value "JT9E")
			    (item :tag "JT9E FAST (JT9)" :value "JT9E FAST")
			    (item :tag "JT9F (JT9)" :value "JT9F")
			    (item :tag "JT9F FAST (JT9)" :value "JT9F FAST")
			    (item :tag "JT9G (JT9)" :value "JT9G")
			    (item :tag "JT9G FAST (JT9)" :value "JT9G FAST")
			    (item :tag "JT9H (JT9)" :value "JT9H")
			    (item :tag "JT9H FAST (JT9)" :value "JT9H FAST")
			    (item :tag "JT65A (JT65)" :value "JT65A")
			    (item :tag "JT65B (JT65)" :value "JT65B")
			    (item :tag "JT65B2 (JT65)" :value "JT65B2")
			    (item :tag "JT65C (JT65)" :value "JT65C")
			    (item :tag "JT65C2 (JT65)" :value "JT65C2")
			    (item :tag "JTMS (MFSK)" :value "JTMS")
			    (item :tag "LSB (SSB)" :value "LSB")
			    (item :tag "M17 (DIGITALVOICE)" :value "M17")
			    (item :tag "MFSK4 (MFSK)" :value "MFSK4")
			    (item :tag "MFSK8 (MFSK)" :value "MFSK8")
			    (item :tag "MFSK11 (MFSK)" :value "MFSK11")
			    (item :tag "MFSK16 (MFSK)" :value "MFSK16")
			    (item :tag "MFSK22 (MFSK)" :value "MFSK22")
			    (item :tag "MFSK31 (MFSK)" :value "MFSK31")
			    (item :tag "MFSK32 (MFSK)" :value "MFSK32")
			    (item :tag "MFSK64 (MFSK)" :value "MFSK64")
			    (item :tag "MFSK64L (MFSK)" :value "MFSK64L")
			    (item :tag "MFSK128 (MFSK)" :value "MFSK128")
			    (item :tag "MFSK128L (MFSK)" :value "MFSK128L")
			    (item :tag "NAVTEX (TOR)" :value "NAVTEX")
			    (item :tag "OLIVIA 4/125 (OLIVIA)" :value "OLIVIA 4/125")
			    (item :tag "OLIVIA 4/250 (OLIVIA)" :value "OLIVIA 4/250")
			    (item :tag "OLIVIA 8/250 (OLIVIA)" :value "OLIVIA 8/250")
			    (item :tag "OLIVIA 8/500 (OLIVIA)" :value "OLIVIA 8/500")
			    (item :tag "OLIVIA 16/500 (OLIVIA)" :value "OLIVIA 16/500")
			    (item :tag "OLIVIA 16/1000 (OLIVIA)" :value "OLIVIA 16/1000")
			    (item :tag "OLIVIA 32/1000 (OLIVIA)" :value "OLIVIA 32/1000")
			    (item :tag "OPERA-BEACON (OPERA)" :value "OPERA-BEACON")
			    (item :tag "OPERA-QSO (OPERA)" :value "OPERA-QSO")
			    (item :tag "PAC2 (PAC)" :value "PAC2")
			    (item :tag "PAC3 (PAC)" :value "PAC3")
			    (item :tag "PAC4 (PAC)" :value "PAC4")
			    (item :tag "PAX2 (PAX)" :value "PAX2")
			    (item :tag "PCW (CW)" :value "PCW")
			    (item :tag "PSK10 (PSK)" :value "PSK10")
			    (item :tag "PSK31 (PSK)" :value "PSK31")
			    (item :tag "PSK63 (PSK)" :value "PSK63")
			    (item :tag "PSK63F (PSK)" :value "PSK63F")
			    (item :tag "PSK63RC10 (PSK)" :value "PSK63RC10")
			    (item :tag "PSK63RC20 (PSK)" :value "PSK63RC20")
			    (item :tag "PSK63RC32 (PSK)" :value "PSK63RC32")
			    (item :tag "PSK63RC4 (PSK)" :value "PSK63RC4")
			    (item :tag "PSK63RC5 (PSK)" :value "PSK63RC5")
			    (item :tag "PSK125 (PSK)" :value "PSK125")
			    (item :tag "PSK125RC10 (PSK)" :value "PSK125RC10")
			    (item :tag "PSK125RC12 (PSK)" :value "PSK125RC12")
			    (item :tag "PSK125RC16 (PSK)" :value "PSK125RC16")
			    (item :tag "PSK125RC4 (PSK)" :value "PSK125RC4")
			    (item :tag "PSK125RC5 (PSK)" :value "PSK125RC5")
			    (item :tag "PSK250 (PSK)" :value "PSK250")
			    (item :tag "PSK250RC2 (PSK)" :value "PSK250RC2")
			    (item :tag "PSK250RC3 (PSK)" :value "PSK250RC3")
			    (item :tag "PSK250RC5 (PSK)" :value "PSK250RC5")
			    (item :tag "PSK250RC6 (PSK)" :value "PSK250RC6")
			    (item :tag "PSK250RC7 (PSK)" :value "PSK250RC7")
			    (item :tag "PSK500 (PSK)" :value "PSK500")
			    (item :tag "PSK500RC2 (PSK)" :value "PSK500RC2")
			    (item :tag "PSK500RC3 (PSK)" :value "PSK500RC3")
			    (item :tag "PSK500RC4 (PSK)" :value "PSK500RC4")
			    (item :tag "PSK800RC2 (PSK)" :value "PSK800RC2")
			    (item :tag "PSK1000 (PSK)" :value "PSK1000")
			    (item :tag "PSK1000RC2 (PSK)" :value "PSK1000RC2")
			    (item :tag "PSKAM10 (PSK)" :value "PSKAM10")
			    (item :tag "PSKAM31 (PSK)" :value "PSKAM31")
			    (item :tag "PSKAM50 (PSK)" :value "PSKAM50")
			    (item :tag "PSKFEC31 (PSK)" :value "PSKFEC31")
			    (item :tag "PSKHELL (HELL)" :value "PSKHELL")
			    (item :tag "QPSK31 (PSK)" :value "QPSK31")
			    (item :tag "Q65 (MFSK)" :value "Q65")
			    (item :tag "QPSK63 (PSK)" :value "QPSK63")
			    (item :tag "QPSK125 (PSK)" :value "QPSK125")
			    (item :tag "QPSK250 (PSK)" :value "QPSK250")
			    (item :tag "QPSK500 (PSK)" :value "QPSK500")
			    (item :tag "QRA64A (QRA64)" :value "QRA64A")
			    (item :tag "QRA64B (QRA64)" :value "QRA64B")
			    (item :tag "QRA64C (QRA64)" :value "QRA64C")
			    (item :tag "QRA64D (QRA64)" :value "QRA64D")
			    (item :tag "QRA64E (QRA64)" :value "QRA64E")
			    (item :tag "ROS-EME (ROS)" :value "ROS-EME")
			    (item :tag "ROS-HF (ROS)" :value "ROS-HF")
			    (item :tag "ROS-MF (ROS)" :value "ROS-MF")
			    (item :tag "SIM31 (PSK)" :value "SIM31")
			    (item :tag "SITORB (TOR)" :value "SITORB")
			    (item :tag "SLOWHELL (HELL)" :value "SLOWHELL")
			    (item :tag "THOR-M (THOR)" :value "THOR-M")
			    (item :tag "THOR4 (THOR)" :value "THOR4")
			    (item :tag "THOR5 (THOR)" :value "THOR5")
			    (item :tag "THOR8 (THOR)" :value "THOR8")
			    (item :tag "THOR11 (THOR)" :value "THOR11")
			    (item :tag "THOR16 (THOR)" :value "THOR16")
			    (item :tag "THOR22 (THOR)" :value "THOR22")
			    (item :tag "THOR25X4 (THOR)" :value "THOR25X4")
			    (item :tag "THOR50X1 (THOR)" :value "THOR50X1")
			    (item :tag "THOR50X2 (THOR)" :value "THOR50X2")
			    (item :tag "THOR100 (THOR)" :value "THOR100")
			    (item :tag "THRBX (THRB)" :value "THRBX")
			    (item :tag "THRBX1 (THRB)" :value "THRBX1")
			    (item :tag "THRBX2 (THRB)" :value "THRBX2")
			    (item :tag "THRBX4 (THRB)" :value "THRBX4")
			    (item :tag "THROB1 (THRB)" :value "THROB1")
			    (item :tag "THROB2 (THRB)" :value "THROB2")
			    (item :tag "THROB4 (THRB)" :value "THROB4")
			    (item :tag "USB (SSB)" :value "USB")
			    (item :tag "VARA HF (DYNAMIC)" :value "VARA HF")
			    (item :tag "VARA SATELLITE (DYNAMIC)" :value "VARA SATELLITE")
			    (item :tag "VARA FM 1200 (DYNAMIC)" :value "VARA FM 1200")
			    (item :tag "VARA FM 9600 (DYNAMIC)" :value "VARA FM 9600")))
    (SWL . (editable-field :format "SWL: %v\n" :size 1 :value ""))
    (TEN_TEN . (editable-field :format "TEN_TEN: %v\n" :size 6 :value ""))
    (TIME_OFF . (editable-field :format "TIME_OFF: %v\n" :size 6 :value ""))
    (TIME_ON . (editable-field :format "TIME_ON: %v\n" :size 6 :value ""))
    (TX_PWR . (editable-field :format "TX_PWR: %vW\n" :size 6 :value ""))
    (UKSMG . (editable-field :format "UKSMG: %v\n" :size 40 :value ""))
    (USACA_COUNTIES . (editable-field :format "USACA_COUNTIES: %v\n" :size 40 :value ""))
    (VE_PROV . (editable-field :format "VE_PROV: %v\n" :size 40 :value ""))
    (VUCC_GRIDS . (editable-field :format "VUCC_GRIDS: %v\n" :size 40 :value ""))
    (WEB . (editable-field :format "WEB: %v\n" :size 41 :value ""))
    (WWFF_REF . (editable-field :format "WWFF_REF: %v\n" :size 40 :value ""))
    (custom-choice . (menu-choice :tag "Choose" :format "Choose: %[%v%]\n" :value "This"
                                  :help-echo "Choose me, please!"
                                  :notify (lambda (widget &rest ignore)
                                            (message "%s is a good choice!"
                                                     (widget-value widget)))
                                  (item :tag "This option" :value "This")
                                  (item :tag "That option" :value "That")
                                  (editable-field :menu-tag "No option" :value "Thus option"))))
  "QSO field definitions for the QSO Log Entry form.")


;;; Radio synchronization through Hamlib's rigctld

;; rigctld speaks a line oriented protocol on a TCP socket.  Prefixing a
;; command with "+" selects its extended response, which names each value
;; and terminates the reply with an "RPRT" status line, so a reply can be
;; recognized as complete no matter how the operating system splits it
;; across packets.  Asking for both values at once looks like this:
;;
;;     +\get_freq            get_freq:
;;                           Frequency: 14074000
;;                           RPRT 0
;;     +\get_mode            get_mode:
;;                           Mode: USB
;;                           Passband: 2400
;;                           RPRT 0

(defconst qso--hamlib-query "+\\get_freq\n+\\get_mode\n"
  "Commands sent to rigctld to read the current frequency and mode.")

(defvar qso--hamlib-process nil
  "Network connection to rigctld, or nil when not connected.")

(defvar qso--hamlib-timer nil
  "Repeating timer that polls the radio, or nil when not polling.")

(defvar qso--hamlib-pending ""
  "Text received from rigctld that does not yet form a complete line.")

(defvar qso--hamlib-freq nil
  "Frequency most recently reported by the radio, in hertz.")

(defvar qso--hamlib-rig-mode nil
  "Mode name most recently reported by the radio, as a Hamlib string.")

(defvar qso--hamlib-error nil
  "Description of the most recent radio communication failure, or nil.")

(defvar qso--hamlib-next-retry 0
  "Time, as returned by `float-time', before which not to redial rigctld.")

(defvar qso--hamlib-state 'idle
  "How the connection to rigctld currently stands.
One of `idle', `connecting', `connected' or `disconnected'.")

(defvar qso--hamlib-connect-timer nil
  "Timer that gives up on a connection attempt, or nil.")

(defvar qso--hamlib-inhibit nil
  "When non-nil, leave the form alone even if a new reading arrives.
Bound while a QSO is being submitted or cleared so that the poller
cannot rearrange widgets underneath those operations.")

(defvar-local qso--widget-alist nil
  "Widgets of the form in this buffer, as (FIELD WIDGET CLEAR-AFTER-SUBMIT).
`qso-log-form' keeps this so that the radio poller, which runs long
after the form was built, can find the live widgets.")

(defvar-local qso--hamlib-written nil
  "Values this package last wrote into form fields, as (FIELD . VALUE).
Used to tell a field the radio filled in from one the operator typed.")

(defun qso--hamlib-live-p ()
  "Return non-nil when the connection to rigctld is usable."
  (and (eq qso--hamlib-state 'connected)
       qso--hamlib-process
       (process-live-p qso--hamlib-process)))

(defun qso--hamlib-cancel-connect-timer ()
  "Stop waiting for an answer to a connection attempt."
  (when qso--hamlib-connect-timer
    (cancel-timer qso--hamlib-connect-timer)
    (setq qso--hamlib-connect-timer nil)))

(defun qso--hamlib-discard-process ()
  "Drop the connection to rigctld without treating it as a failure."
  (qso--hamlib-cancel-connect-timer)
  (when qso--hamlib-process
    ;; Detach the callbacks first, so that deleting the process does not
    ;; come back through the sentinel as a fresh failure.
    (set-process-sentinel qso--hamlib-process #'ignore)
    (set-process-filter qso--hamlib-process #'ignore)
    (ignore-errors (delete-process qso--hamlib-process)))
  (setq qso--hamlib-process nil))

(defun qso--hamlib-failed (reason)
  "Record REASON for losing the radio and arrange to try again later."
  (qso--hamlib-discard-process)
  (setq qso--hamlib-state 'disconnected)
  (setq qso--hamlib-error reason)
  (setq qso--hamlib-pending "")
  (setq qso--hamlib-freq nil)
  (setq qso--hamlib-rig-mode nil)
  (setq qso--hamlib-next-retry (+ (float-time) qso-hamlib-reconnect-interval))
  (qso--hamlib-update-header-line))

(defun qso--hamlib-connect ()
  "Begin connecting to rigctld.

This returns at once, whatever the state of the network.  The socket is
opened with `:nowait', so a host that is switched off or firewalled is
noticed by the sentinel or by `qso--hamlib-connect-timer' rather than by
making Emacs wait out the operating system's TCP timeout."
  (qso--hamlib-discard-process)
  (setq qso--hamlib-pending "")
  (setq qso--hamlib-state 'connecting)
  (setq qso--hamlib-error nil)
  (condition-case err
      (setq qso--hamlib-process
            (make-network-process :name "qso-rigctld"
                                  :host qso-hamlib-host
                                  :service qso-hamlib-port
                                  :nowait t
                                  :noquery t
                                  :coding 'utf-8-unix
                                  :filter #'qso--hamlib-filter
                                  :sentinel #'qso--hamlib-sentinel))
    (error
     (setq qso--hamlib-process nil)
     (qso--hamlib-failed (error-message-string err))))
  ;; A host that drops packets outright never answers at all, so give the
  ;; attempt a deadline of our own rather than waiting on the network stack.
  (when (eq qso--hamlib-state 'connecting)
    (setq qso--hamlib-connect-timer
          (run-at-time qso-hamlib-connect-timeout nil
                       #'qso--hamlib-connect-expired)))
  (qso--hamlib-update-header-line))

(defun qso--hamlib-connect-expired ()
  "Give up on a connection attempt that rigctld never answered."
  (setq qso--hamlib-connect-timer nil)
  (when (eq qso--hamlib-state 'connecting)
    (qso--hamlib-failed
     (format "no answer within %g s" qso-hamlib-connect-timeout))))

(defun qso--hamlib-disconnect ()
  "Close the connection to rigctld, if any."
  (qso--hamlib-discard-process)
  (setq qso--hamlib-state 'idle))

(defun qso--hamlib-sentinel (process event)
  "Follow the connection to rigctld as it reports EVENT for PROCESS."
  (when (eq process qso--hamlib-process)
    (if (string-prefix-p "open" event)
        (progn
          (qso--hamlib-cancel-connect-timer)
          (setq qso--hamlib-state 'connected)
          (setq qso--hamlib-error nil)
          (ignore-errors (process-send-string process qso--hamlib-query))
          (qso--hamlib-update-header-line))
      (qso--hamlib-failed (string-trim event)))))

(defun qso--hamlib-filter (_process string)
  "Split STRING arriving from rigctld into whole lines and act on each."
  (setq qso--hamlib-pending (concat qso--hamlib-pending string))
  (while (string-match "\\`\\([^\n]*\\)\n" qso--hamlib-pending)
    (let ((line (match-string 1 qso--hamlib-pending)))
      (setq qso--hamlib-pending
            (substring qso--hamlib-pending (match-end 0)))
      (qso--hamlib-handle-line (string-trim line)))))

(defun qso--hamlib-handle-line (line)
  "Interpret a single response LINE from rigctld."
  (cond
   ((string-match "\\`Frequency: \\([0-9]+\\)\\'" line)
    (setq qso--hamlib-freq (string-to-number (match-string 1 line))))
   ((string-match "\\`Mode: \\([A-Za-z0-9_-]+\\)\\'" line)
    (setq qso--hamlib-rig-mode (match-string 1 line)))
   ((string-match "\\`RPRT \\(-?[0-9]+\\)\\'" line)
    ;; A response is complete; a nonzero status means the radio refused it.
    (let ((status (string-to-number (match-string 1 line))))
      (setq qso--hamlib-error
            (unless (zerop status) (format "rigctld status %d" status))))
    (qso--hamlib-apply))))

(defun qso--hamlib-poll ()
  "Read the radio, redialing first if the link has dropped."
  (cond
   ((qso--hamlib-live-p)
    (condition-case err
        (process-send-string qso--hamlib-process qso--hamlib-query)
      (error (qso--hamlib-failed (error-message-string err)))))
   ;; An attempt already under way answers through the sentinel or times
   ;; out on its own; starting another would just pile up sockets.
   ((eq qso--hamlib-state 'connecting) nil)
   ;; Redial no more often than `qso-hamlib-reconnect-interval', so that a
   ;; radio that is switched off does not produce a stream of failures.
   ((>= (float-time) qso--hamlib-next-retry)
    (qso--hamlib-connect)))
  (qso--hamlib-update-header-line))

(defun qso--hamlib-freq-string ()
  "Return the radio's frequency in MHz as a string, or nil if unknown."
  (when (and qso--hamlib-freq (> qso--hamlib-freq 0))
    (format qso-hamlib-freq-format (/ qso--hamlib-freq 1000000.0))))

(defun qso--hamlib-adif-mode ()
  "Return (MODE . SUBMODE) in ADIF terms for the radio's mode, or nil.
Either element may be an empty string, meaning the radio's mode does not
determine that field."
  (when qso--hamlib-rig-mode
    (let ((entry (assoc-string qso--hamlib-rig-mode qso-hamlib-mode-alist t)))
      (when entry (cons (nth 1 entry) (nth 2 entry))))))

(defun qso--widget-accepts-p (widget value)
  "Return non-nil when WIDGET can hold VALUE.
A menu-choice only offers a fixed set of values, so setting it to
anything else would leave the form displaying a value the operator
cannot see or correct."
  (if (eq (widget-type widget) 'menu-choice)
      (let ((offered nil))
        (dolist (choice (widget-get widget :args))
          (when (ignore-errors (widget-apply choice :match value))
            (setq offered t)))
        offered)
    t))

(defun qso--hamlib-point-in-widget-p (widget)
  "Return non-nil when point lies within WIDGET."
  (let ((from (widget-get widget :from))
        (to (widget-get widget :to)))
    (and (markerp from)
         (markerp to)
         (>= (point) (marker-position from))
         (<= (point) (marker-position to)))))

(defun qso--hamlib-set-field (field value)
  "Set FIELD's widget to VALUE, unless the operator owns the field.
Return non-nil when the widget was changed.  A field is left alone when
it holds anything other than what the radio last put there, and while
point is inside it, so typing is never overwritten.

An empty VALUE clears a field this package filled in earlier, which is
what keeps a SUBMODE of USB from surviving a switch from SSB to CW.  A
VALUE of nil means the radio said nothing about this field and leaves it
untouched."
  (let ((widget (nth 1 (assq field qso--widget-alist))))
    (when (and widget
               value
               (or (string-empty-p value)
                   (qso--widget-accepts-p widget value)))
      (let ((current (ignore-errors (widget-value widget)))
            (ours (cdr (assq field qso--hamlib-written))))
        (when (and (stringp current)
                   (not (equal current value))
                   (or (string-empty-p (string-trim current))
                       (equal current ours))
                   (not (qso--hamlib-point-in-widget-p widget)))
          (save-excursion
            (widget-value-set widget value))
          (let ((cell (assq field qso--hamlib-written)))
            (if cell
                (setcdr cell value)
              (push (cons field value) qso--hamlib-written)))
          t)))))

(defun qso--hamlib-apply ()
  "Push the latest reading into the QSO form and its header line."
  (let ((buffer (get-buffer qso-form-buffer-name)))
    (when (and (buffer-live-p buffer) (not qso--hamlib-inhibit))
      (with-current-buffer buffer
        (let* ((mode-pair (qso--hamlib-adif-mode))
               (changed nil))
          (when (qso--hamlib-set-field 'FREQ (qso--hamlib-freq-string))
            (setq changed t))
          (when (qso--hamlib-set-field 'MODE (car mode-pair))
            (setq changed t))
          (when (qso--hamlib-set-field 'SUBMODE (cdr mode-pair))
            (setq changed t))
          (when changed
            (widget-setup))
          (qso--hamlib-update-header-line))))))

(defun qso--hamlib-header-string ()
  "Return the header line describing the radio, or nil to show none."
  (cond
   ((eq qso--hamlib-state 'connecting)
    (format " RADIO  connecting to rigctld at %s:%d..."
            qso-hamlib-host qso-hamlib-port))
   ((not (qso--hamlib-live-p))
    (format " RADIO  no connection to rigctld at %s:%d%s"
            qso-hamlib-host qso-hamlib-port
            (if qso--hamlib-error (format " (%s)" qso--hamlib-error) "")))
   ((null qso--hamlib-freq)
    (format " RADIO  connected to %s:%d, waiting for a reading"
            qso-hamlib-host qso-hamlib-port))
   (t
    (let* ((mode-pair (qso--hamlib-adif-mode))
           (logged
            (cond
             ((null mode-pair) "not recognized")
             ((string-empty-p (car mode-pair)) "not logged")
             ((string-empty-p (cdr mode-pair)) (car mode-pair))
             (t (format "%s / %s" (car mode-pair) (cdr mode-pair))))))
      (format " RADIO  %s MHz   %s   logged as %s"
              (or (qso--hamlib-freq-string) "?")
              (or qso--hamlib-rig-mode "?")
              logged)))))

(defun qso--hamlib-update-header-line ()
  "Refresh the radio reading shown above the QSO form."
  (let ((buffer (get-buffer qso-form-buffer-name)))
    (when (and (buffer-live-p buffer) qso-hamlib-header-line)
      (with-current-buffer buffer
        (setq header-line-format (qso--hamlib-header-string))
        (force-mode-line-update)))))

(defun qso-hamlib-start ()
  "Start following the radio's frequency and mode through rigctld."
  (interactive)
  (qso--hamlib-cancel-timer)
  (setq qso--hamlib-next-retry 0)
  (qso--hamlib-connect)
  (setq qso--hamlib-timer
        (run-at-time 0 qso-hamlib-poll-interval #'qso--hamlib-poll))
  (message "QSO: following radio at %s:%d" qso-hamlib-host qso-hamlib-port))

(defun qso--hamlib-cancel-timer ()
  "Stop the polling timer, if it is running."
  (when qso--hamlib-timer
    (cancel-timer qso--hamlib-timer)
    (setq qso--hamlib-timer nil)))

(defun qso-hamlib-stop ()
  "Stop following the radio and close the connection to rigctld."
  (interactive)
  (qso--hamlib-cancel-timer)
  (qso--hamlib-disconnect)
  (setq qso--hamlib-pending "")
  (setq qso--hamlib-freq nil)
  (setq qso--hamlib-rig-mode nil)
  (setq qso--hamlib-error nil)
  (setq qso--hamlib-next-retry 0)
  (qso--hamlib-update-header-line))

(defun qso-hamlib-toggle ()
  "Turn radio synchronization on or off for the rest of this session."
  (interactive)
  (if qso--hamlib-timer
      (progn
        (qso-hamlib-stop)
        (message "QSO: no longer following the radio"))
    (qso-hamlib-start)))

(defun qso-hamlib-sync-now ()
  "Read the radio once, whether or not synchronization is running."
  (interactive)
  (if (qso--hamlib-live-p)
      (condition-case err
          (process-send-string qso--hamlib-process qso--hamlib-query)
        (error (qso--hamlib-failed (error-message-string err))))
    ;; Connecting is asynchronous, so the reading is sent by the sentinel
    ;; once the connection actually opens.
    (setq qso--hamlib-next-retry 0)
    (qso--hamlib-connect)
    (message "QSO: contacting rigctld at %s:%d..."
             qso-hamlib-host qso-hamlib-port)))

;;; Callsign lookup

;; Every source is reduced to the same thing: an alist of ADIF field names
;; and values.  The form and the ADIF writer only ever see that alist, so
;; adding a source means writing one function and nothing else.

(defvar-local qso--lookup-extra nil
  "Looked-up fields that are not on the form, as (FIELD . VALUE).
Written into the ADIF record when the QSO is submitted.")

(defvar-local qso--lookup-call nil
  "Callsign that `qso--lookup-extra' belongs to.
Keeps details of one station out of the record of another.")

(defvar qso--lookup-session nil
  "Cached login session for the current lookup source, or nil.")

(defvar qso--lookup-session-time 0
  "When `qso--lookup-session' was obtained, as `float-time'.")

(defun qso--lookup-secret (host user)
  "Return the password stored for USER at HOST, or nil."
  (require 'auth-source)
  (let ((found (car (auth-source-search :host host :user user :max 1))))
    (when found
      (let ((secret (plist-get found :secret)))
        (if (functionp secret) (funcall secret) secret)))))

(defun qso--lookup-http-get (url)
  "Fetch URL and return its body as a string, or nil on any failure."
  (let ((buffer (condition-case nil
                    ;; The timeout argument arrived in Emacs 26; without it
                    ;; a stalled server would hang Emacs until it gave up.
                    (if (>= emacs-major-version 26)
                        (url-retrieve-synchronously url t t qso-call-lookup-timeout)
                      (url-retrieve-synchronously url t t))
                  (error nil))))
    (when (buffer-live-p buffer)
      (unwind-protect
          (with-current-buffer buffer
            (goto-char (point-min))
            (if (re-search-forward "^\r?$" nil t)
                (forward-line 1)
              (goto-char (point-min)))
            (decode-coding-string
             (buffer-substring-no-properties (point) (point-max)) 'utf-8))
        (kill-buffer buffer)))))

(defun qso--lookup-parse-xml (body)
  "Parse BODY as XML and return its root node, or nil."
  (ignore-errors
    (with-temp-buffer
      (insert body)
      (car (xml-parse-region (point-min) (point-max))))))

(defun qso--xml-text (node tag)
  "Return the text of TAG inside NODE, or nil."
  (let ((child (car (xml-get-children node tag))))
    (when child
      (let ((text (car (xml-node-children child))))
        (when (stringp text)
          (let ((trimmed (string-trim text)))
            (unless (string-empty-p trimmed) trimmed)))))))

(defun qso--lookup-clean (data)
  "Drop empty entries from DATA, an alist of ADIF fields."
  (let ((result '()))
    (dolist (pair data (nreverse result))
      (let ((value (cdr pair)))
        (when (and value (stringp value) (not (string-empty-p (string-trim value))))
          (push (cons (car pair) (string-trim value)) result))))))

;;; Source: callook.info (United States)

(defun qso--lookup-callook (call)
  "Look CALL up at callook.info.  Return an alist of ADIF fields."
  (let ((body (qso--lookup-http-get
               (format "https://callook.info/%s/json" (url-hexify-string call)))))
    (when body
      (let* ((json-object-type 'alist)
             (json-array-type 'list)
             (json-key-type 'symbol)
             (data (ignore-errors (json-read-from-string body))))
        (when (equal (cdr (assq 'status data)) "VALID")
          (let* ((address (cdr (assq 'address data)))
                 (location (cdr (assq 'location data)))
                 ;; "NEWINGTON, CT 06111" -- city before the comma, then
                 ;; the two-letter state.
                 (line2 (cdr (assq 'line2 address)))
                 (city (when line2 (car (split-string line2 ","))))
                 (state (when (and line2 (string-match ",\\s-*\\([A-Z]\\{2\\}\\)\\b" line2))
                          (match-string 1 line2))))
            (qso--lookup-clean
             (list (cons 'NAME (cdr (assq 'name data)))
                   (cons 'QTH city)
                   (cons 'STATE state)
                   (cons 'GRIDSQUARE (cdr (assq 'gridsquare location)))
                   (cons 'LAT (cdr (assq 'latitude location)))
                   (cons 'LON (cdr (assq 'longitude location)))
                   (cons 'COUNTRY "United States of America")))))))))

;;; Source: HamQTH (worldwide)

(defun qso--lookup-hamqth-session ()
  "Return a HamQTH session id, logging in if the cached one is stale."
  ;; HamQTH sessions last about an hour; renewing a little early is
  ;; cheaper than discovering the expiry in the middle of a contact.
  (if (and qso--lookup-session
           (< (- (float-time) qso--lookup-session-time) 3000))
      qso--lookup-session
    (let* ((user (string-trim (or qso-call-lookup-user "")))
           (password (unless (string-empty-p user)
                       (qso--lookup-secret "www.hamqth.com" user))))
      (cond
       ((string-empty-p user)
        (message "QSO: set QSO Callsign Lookup User to your HamQTH login")
        nil)
       ((null password)
        (message "QSO: no HamQTH password for %s in auth-source (~/.authinfo.gpg)" user)
        nil)
       (t
        (let ((body (qso--lookup-http-get
                     (format "https://www.hamqth.com/xml.php?u=%s&p=%s"
                             (url-hexify-string user)
                             (url-hexify-string password)))))
          (when body
            (let* ((root (qso--lookup-parse-xml body))
                   (session (car (xml-get-children root 'session)))
                   (id (and session (qso--xml-text session 'session_id)))
                   (problem (and session (qso--xml-text session 'error))))
              (cond
               (id (setq qso--lookup-session id
                         qso--lookup-session-time (float-time))
                   id)
               (problem (message "QSO: HamQTH: %s" problem) nil)
               (t (message "QSO: HamQTH did not return a session") nil))))))))))

(defun qso--lookup-hamqth (call)
  "Look CALL up at HamQTH.  Return an alist of ADIF fields."
  (let ((session (qso--lookup-hamqth-session)))
    (when session
      (let ((body (qso--lookup-http-get
                   (format "https://www.hamqth.com/xml.php?id=%s&callsign=%s&prg=Emacs-QSO-Logger"
                           (url-hexify-string session)
                           (url-hexify-string (downcase call))))))
        (when body
          (let* ((root (qso--lookup-parse-xml body))
                 (search (car (xml-get-children root 'search)))
                 (problem (qso--xml-text root 'session)))
            (cond
             (search
              (qso--lookup-clean
               (list (cons 'NAME (or (qso--xml-text search 'adr_name)
                                     (qso--xml-text search 'nick)))
                     (cons 'QTH (or (qso--xml-text search 'qth)
                                    (qso--xml-text search 'adr_city)))
                     (cons 'GRIDSQUARE (qso--xml-text search 'grid))
                     (cons 'STATE (qso--xml-text search 'us_state))
                     (cons 'CNTY (qso--xml-text search 'us_county))
                     (cons 'COUNTRY (qso--xml-text search 'country))
                     (cons 'CQZ (qso--xml-text search 'cq))
                     (cons 'ITUZ (qso--xml-text search 'itu))
                     (cons 'CONT (qso--xml-text search 'continent))
                     (cons 'LAT (qso--xml-text search 'latitude))
                     (cons 'LON (qso--xml-text search 'longitude)))))
             (t
              ;; A rejected session id is worth one silent retry, since it
              ;; simply means the hour ran out mid-session.
              (when problem (setq qso--lookup-session nil))
              nil))))))))

;;; Source: QRZ.com (worldwide, subscription)

(defun qso--lookup-qrz-session ()
  "Return a QRZ.com session key, logging in if the cached one is stale."
  (if (and qso--lookup-session
           (< (- (float-time) qso--lookup-session-time) 3000))
      qso--lookup-session
    (let* ((user (string-trim (or qso-call-lookup-user "")))
           (password (unless (string-empty-p user)
                       (qso--lookup-secret "xmldata.qrz.com" user))))
      (cond
       ((string-empty-p user)
        (message "QSO: set QSO Callsign Lookup User to your QRZ.com login")
        nil)
       ((null password)
        (message "QSO: no QRZ.com password for %s in auth-source (~/.authinfo.gpg)" user)
        nil)
       (t
        (let ((body (qso--lookup-http-get
                     (format "https://xmldata.qrz.com/xml/current/?username=%s;password=%s;agent=Emacs-QSO-Logger"
                             (url-hexify-string user)
                             (url-hexify-string password)))))
          (when body
            (let* ((root (qso--lookup-parse-xml body))
                   (session (car (xml-get-children root 'Session)))
                   (key (and session (qso--xml-text session 'Key)))
                   (problem (and session (qso--xml-text session 'Error))))
              (cond
               (key (setq qso--lookup-session key
                          qso--lookup-session-time (float-time))
                    key)
               (problem (message "QSO: QRZ.com: %s" problem) nil)
               (t (message "QSO: QRZ.com did not return a session key") nil))))))))))

(defun qso--lookup-qrz (call)
  "Look CALL up at QRZ.com.  Return an alist of ADIF fields."
  (let ((session (qso--lookup-qrz-session)))
    (when session
      (let ((body (qso--lookup-http-get
                   (format "https://xmldata.qrz.com/xml/current/?s=%s;callsign=%s"
                           (url-hexify-string session)
                           (url-hexify-string call)))))
        (when body
          (let* ((root (qso--lookup-parse-xml body))
                 (entry (car (xml-get-children root 'Callsign)))
                 (session-node (car (xml-get-children root 'Session)))
                 (problem (and session-node (qso--xml-text session-node 'Error))))
            (cond
             (entry
              (let ((first (qso--xml-text entry 'fname))
                    (last (qso--xml-text entry 'name)))
                (qso--lookup-clean
                 (list (cons 'NAME (string-trim (concat (or first "") " " (or last ""))))
                       (cons 'QTH (qso--xml-text entry 'addr2))
                       (cons 'GRIDSQUARE (qso--xml-text entry 'grid))
                       (cons 'STATE (qso--xml-text entry 'state))
                       (cons 'CNTY (qso--xml-text entry 'county))
                       (cons 'COUNTRY (qso--xml-text entry 'country))
                       (cons 'CQZ (qso--xml-text entry 'cqzone))
                       (cons 'ITUZ (qso--xml-text entry 'ituzone))
                       (cons 'LAT (qso--xml-text entry 'lat))
                       (cons 'LON (qso--xml-text entry 'lon))))))
             (t
              (when problem
                (setq qso--lookup-session nil)
                (message "QSO: QRZ.com: %s" problem))
              nil))))))))

;;; Offline country lookup from a cty.dat country file

(defvar qso--cty-prefixes nil
  "Hash of callsign prefix to entity plist, or nil when nothing is loaded.")

(defvar qso--cty-exact nil
  "Hash of whole callsigns to entity plists, from cty.dat \"=\" entries.")

(defvar qso--cty-loaded-file nil
  "The country file currently in memory, as (PATH . MODIFICATION-TIME).")

(defun qso--cty-strip-modifiers (token)
  "Remove cty.dat's per-prefix overrides from TOKEN, leaving the prefix."
  (let ((prefix token))
    (dolist (pattern '("([^)]*)" "\\[[^]]*\\]" "<[^>]*>" "{[^}]*}" "~[^~]*~"))
      (setq prefix (replace-regexp-in-string pattern "" prefix)))
    (string-trim prefix)))

(defun qso--cty-load ()
  "Read `qso-cty-file' into memory.  Return non-nil when usable."
  (let* ((file (and qso-cty-file (expand-file-name qso-cty-file)))
         (stamp (and file (file-readable-p file)
                     (cons file (nth 5 (file-attributes file))))))
    (cond
     ;; Forget which file was loaded as well as its contents, so that a
     ;; country file that reappears later is read again rather than being
     ;; mistaken for the one already in memory.
     ((null stamp)
      (setq qso--cty-prefixes nil qso--cty-exact nil qso--cty-loaded-file nil)
      nil)
     ((equal stamp qso--cty-loaded-file) (and qso--cty-prefixes t))
     (t
      (let ((prefixes (make-hash-table :test 'equal))
            (exact (make-hash-table :test 'equal)))
        (condition-case err
            (with-temp-buffer
              (insert-file-contents file)
              (goto-char (point-min))
              ;; Records are separated by semicolons.  The first line holds
              ;; the entity's details, the rest a comma-separated list of
              ;; the prefixes that belong to it.
              (while (re-search-forward "\\([^;]+\\);" nil t)
                (let* ((record (match-string 1))
                       (lines (split-string record "\n" t))
                       (fields (split-string (or (car lines) "") ":"))
                       (tokens (split-string
                                (mapconcat #'identity (cdr lines) "") "," t)))
                  (when (>= (length fields) 8)
                    (let ((entity (list :country (string-trim (nth 0 fields))
                                        :cqz (string-trim (nth 1 fields))
                                        :ituz (string-trim (nth 2 fields))
                                        :cont (string-trim (nth 3 fields)))))
                      (dolist (token tokens)
                        (let ((entry entity)
                              (bare (qso--cty-strip-modifiers token)))
                          ;; A prefix may override the entity's zones.
                          (when (string-match "(\\([0-9]+\\))" token)
                            (setq entry (plist-put (copy-sequence entry)
                                                   :cqz (match-string 1 token))))
                          (when (string-match "\\[\\([0-9]+\\)\\]" token)
                            (setq entry (plist-put (copy-sequence entry)
                                                   :ituz (match-string 1 token))))
                          (cond
                           ((string-empty-p bare) nil)
                           ;; "=CALL" names one station, not a prefix.
                           ((string-prefix-p "=" bare)
                            (puthash (upcase (substring bare 1)) entry exact))
                           (t (puthash (upcase bare) entry prefixes))))))))))
          (error
           (message "QSO: cannot read country file %s: %s"
                    file (error-message-string err))
           (setq prefixes nil)))
        (if (and prefixes (> (hash-table-count prefixes) 0))
            (progn (setq qso--cty-prefixes prefixes
                         qso--cty-exact exact
                         qso--cty-loaded-file stamp)
                   t)
          (setq qso--cty-prefixes nil qso--cty-exact nil qso--cty-loaded-file nil)
          nil))))))

(defconst qso--cty-plain-suffixes
  '("P" "M" "MM" "AM" "QRP" "A" "B" "LH" "R" "T" "J")
  "Callsign suffixes that say nothing about where a station is.")

(defun qso--cty-base-call (call)
  "Return the part of CALL that decides which entity it belongs to.

This is a rule of thumb rather than a law: a lone digit is an area
within the same country, common suffixes such as /P or /MM are ignored,
and otherwise the shorter part carries the country prefix, as in both
DL/K6SM and K6SM/DL."
  (let ((parts (split-string (upcase call) "/" t)))
    (cond
     ((null parts) (upcase call))
     ((null (cdr parts)) (car parts))
     (t
      (let* ((meaningful (or (seq-remove
                              (lambda (part) (member part qso--cty-plain-suffixes))
                              parts)
                             parts))
             (located (or (seq-remove
                           (lambda (part) (string-match-p "\\`[0-9]\\'" part))
                           meaningful)
                          meaningful)))
        (if (null (cdr located))
            (car located)
          (car (sort (copy-sequence located)
                     (lambda (a b) (< (length a) (length b)))))))))))

(defun qso--cty-lookup (call)
  "Return the entity plist for CALL from the country file, or nil."
  (when (qso--cty-load)
    (let ((whole (upcase (string-trim call))))
      (or (gethash whole qso--cty-exact)
          (let ((base (qso--cty-base-call whole)))
            (or (gethash base qso--cty-exact)
                ;; Longest prefix wins, so K1 beats K.
                (let ((length (length base))
                      (hit nil))
                  (while (and (> length 0) (null hit))
                    (setq hit (gethash (substring base 0 length) qso--cty-prefixes))
                    (setq length (1- length)))
                  hit)))))))

(defun qso--lookup-dxcc (call)
  "Return country and zone fields for CALL from the country file."
  (when qso-call-lookup-dxcc
    (let ((entity (qso--cty-lookup call)))
      (when entity
        (qso--lookup-clean
         (list (cons 'COUNTRY (plist-get entity :country))
               (cons 'CQZ (plist-get entity :cqz))
               (cons 'ITUZ (plist-get entity :ituz))
               (cons 'CONT (plist-get entity :cont))))))))

;;; Putting a lookup together and using the result

(defun qso--lookup-fetch (call)
  "Gather everything known about CALL as an alist of ADIF fields.

The country file supplies a floor that works offline for any callsign;
whatever the chosen source knows is laid over the top of it."
  (let ((offline (qso--lookup-dxcc call))
        (online (pcase qso-call-lookup-source
                  ('callook (qso--lookup-callook call))
                  ('hamqth (qso--lookup-hamqth call))
                  ('qrz (qso--lookup-qrz call))
                  (_ nil)))
        (result '()))
    (dolist (pair (append offline online))
      (setq result (cons pair (assq-delete-all (car pair) result))))
    (nreverse result)))

(defun qso--lookup-show (call data)
  "Display DATA for CALL in the *Callsign Info* buffer."
  (with-current-buffer (get-buffer-create "*Callsign Info*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (if (null data)
          (insert (format "Nothing found for %s.\n" (upcase call)))
        (insert (format "%s\n\n" (upcase call)))
        (dolist (pair data)
          (insert (format "%-12s %s\n" (symbol-name (car pair)) (cdr pair)))))
      (goto-char (point-min)))
    (display-buffer (current-buffer))))

(defun qso--lookup-autofill (call data)
  "Put DATA for CALL into the form, and keep the rest for the ADIF record.
Return the list of fields that were filled in."
  (setq qso--lookup-call (upcase (string-trim call)))
  (setq qso--lookup-extra nil)
  (let ((filled '())
        (touched nil))
    (dolist (field qso-call-lookup-fields)
      (let ((value (cdr (assq field data))))
        (when value
          (let ((widget (nth 1 (assq field qso--widget-alist))))
            (cond
             ((and widget (qso--widget-accepts-p widget value))
              (widget-value-set widget value)
              (setq touched t)
              (push field filled))
             (widget
              ;; On the form but unable to hold this value, as with a
              ;; menu-choice that does not offer it.
              (message "QSO: %s cannot be set to %S from the form" field value))
             (t
              ;; Not on the form, so carry it to the record instead.
              (push (cons field value) qso--lookup-extra)
              (push field filled)))))))
    (when touched (widget-setup))
    (nreverse filled)))

(defun qso--lookup-call-value ()
  "Return the callsign currently typed into the form, or nil."
  (let* ((widget (nth 1 (assq 'CALL qso--widget-alist)))
         (value (and widget (string-trim (or (widget-value widget) "")))))
    (unless (or (null value) (string-empty-p value)) value)))

(defun qso-call-lookup-at-point (&optional autofill)
  "Look up the callsign on the form and show what is known about it.
With AUTOFILL non-nil, also fill in `qso-call-lookup-fields'."
  (interactive "P")
  (let ((call (qso--lookup-call-value)))
    (cond
     ((null call) (message "QSO: no callsign entered"))
     (t
      (message "QSO: looking up %s..." (upcase call))
      (let ((data (qso--lookup-fetch call)))
        (qso--lookup-show call data)
        (cond
         ((null data)
          (message "QSO: nothing found for %s" (upcase call)))
         (autofill
          (let ((filled (qso--lookup-autofill call data)))
            (if filled
                (message "QSO: filled in %s"
                         (mapconcat #'symbol-name filled ", "))
              (message "QSO: nothing to fill in for %s" (upcase call)))))
         (t (message "QSO: %d field(s) found for %s"
                     (length data) (upcase call)))))))))

(defvar qso-form-map
  (let ((map (copy-keymap widget-keymap)))
    (define-key map (kbd "C-c C-r") #'qso-hamlib-sync-now)
    (define-key map (kbd "C-c C-t") #'qso-hamlib-toggle)
    (define-key map (kbd "C-c C-l") #'qso-call-lookup-at-point)
    map)
  "Keymap used in the QSO Log Entry form.")


(defun qso-log-form ()
  "Create a dynamic QSO log form based on `qso-form-fields`."
  (interactive)
  (switch-to-buffer qso-form-buffer-name)
  (kill-all-local-variables)
  (let ((inhibit-read-only t))
    (erase-buffer))
  (remove-overlays)
  (widget-insert "OPERATOR: " qso-OPERATOR " \n")
  (let ((widget-alist '()))
    ;; Create widgets for each field and store in widget-alist in the same order
    (dolist (field-info qso-form-fields)
      (let* ((field (car field-info))
             (clear-after-submit (cdr field-info))
             (field-definition (alist-get field qso-form-field-definitions)))
        (when field-definition
          (let ((widget (apply #'widget-create field-definition)))
            (setq widget-alist (append widget-alist (list (list field widget clear-after-submit))))
	    (when (eq field 'CALL)
	      (when qso-call-lookup
	        (widget-create 'push-button
	      		 :notify (lambda (&rest _)
	      			   (qso-call-lookup-at-point nil))
	      		 "Lookup"))
	      (when qso-call-lookup-autofill
	        (widget-create 'push-button
	      		 :notify (lambda (&rest _)
	      			   (qso-call-lookup-at-point t))
	      		 "Lookup & Autofill"))
	      (widget-insert "\n"))))))

    ;; Add submit, clear and quit buttons
    (widget-insert "\n")
    (widget-create 'push-button
                   :notify (lambda (&rest _)
                             (let ((adif-string "")
				   (call-value nil)
                                   (date-value "")
                                   (time-value "")
				   ;; Keep the radio poller out of the form while
				   ;; the record is being assembled and written.
				   (qso--hamlib-inhibit t))
                               ;; Collect data from each widget
                               (dolist (field-pair widget-alist)
                                 (let* ((field (nth 0 field-pair))
                                        (widget (nth 1 field-pair))
                                        (clear-after-submit (nth 2 field-pair))
                                        (value (widget-value widget)))
				   (setq value (string-trim value)) ;; Remove whitespace
                                   ;; Store the CALL value for duplicate check
                                   (when (eq field 'CALL)
                                     (setq call-value value))
				   ;; Generate the adif-string with non-empty field values
				   (unless (string-empty-p value)
                                     (setq adif-string
                                           (concat adif-string
                                                   (format "<%s:%d>%s"
                                                           (upcase (symbol-name field))
                                                           (length (format "%s" value))
                                                           value))))
                                   ;; Special handling for QSO_DATE and TIME_ON
                                   (when (eq field 'QSO_DATE)
                                     (setq date-value value))
                                   (when (eq field 'TIME_ON)
                                     (setq time-value value))
                                   ;; Clear the widget if it is marked for clearing
                                   (when clear-after-submit
                                     (widget-value-set widget ""))))
			       ;; If the ADIF file doesn't yet exist, create it and insert an ADIF header
			       (unless (file-exists-p qso-adif-path)
				 (make-empty-file qso-adif-path)
				 (with-temp-buffer
				   (let ((timestamp (format-time-string "%Y%m%d %H%M%S" (current-time) t)))
				     (insert (format "%s\n" qso-adif-title))
				     (insert "<ADIF_VER:5>3.1.4\n")
				     (insert (format "<CREATED_TIMESTAMP:15>%s\n" timestamp))
				     (insert "<PROGRAMID:16>Emacs-QSO-Logger\n<PROGRAMVERSION:5>1.3.0\n<EOH>\n"))
				   (write-region (point-min) (point-max) qso-adif-path t))
				 (message "File created, header written to file"))
			       ;; Check for duplicate callsign
			       (when (and qso-call-duplicates
					  call-value
					  (not (string-empty-p call-value)))
				 (let ((pattern (format "<CALL:%d>%s"
							(length (format "%s" call-value))
							(regexp-quote call-value)))
				       (occur-buf "*Occur*"))
				   (with-temp-buffer
				     (insert-file-contents qso-adif-path)
				     (occur pattern))
				   (when (get-buffer occur-buf)
				     (display-buffer occur-buf)
				     (let ((proceed (y-or-n-p "Duplicate(s) found — proceed anyway? ")))
				       (kill-buffer occur-buf)
				       (goto-char (point-min))
				       (widget-forward 1)
				       (unless proceed
					 (user-error "Submission canceled due to duplicate callsign"))))))
			       (progn
				 ;; Get the current UTC date and time if date and time fields are empty
				 (let* ((current-time (current-time))
					(utc-time (format-time-string "%Y%m%d %H%M%S" current-time t))
					(date (substring utc-time 0 8))
					(time (substring utc-time 9 15)))
				   (unless (and date-value (not (string-empty-p date-value)))
				     (setq date-value date))
				   (unless (and time-value (not (string-empty-p time-value)))
				     (setq time-value time))
				   ;; Auto-calculate BAND from FREQ if BAND not already included
				   (unless (string-match "<BAND:" adif-string)
				     (when (string-match "<FREQ:[0-9]+>\\([0-9.]+\\)" adif-string)
				       (let* ((freq-str (match-string 1 adif-string))
					      (freq (string-to-number freq-str))
					      (band
					       (cond
						((and (>= freq 1.8) (<= freq 2.0)) "160m")
						((and (>= freq 3.5) (<= freq 4.0)) "80m")
						((and (>= freq 5.3305) (<= freq 5.405)) "60m")
						((and (>= freq 7.0) (<= freq 7.3)) "40m")
						((and (>= freq 10.1) (<= freq 10.15)) "30m")
						((and (>= freq 14.0) (<= freq 14.35)) "20m")
						((and (>= freq 18.068) (<= freq 18.168)) "17m")
						((and (>= freq 21.0) (<= freq 21.45)) "15m")
						((and (>= freq 24.89) (<= freq 24.99)) "12m")
						((and (>= freq 28.0) (<= freq 29.7)) "10m")
						((and (>= freq 50.0) (<= freq 54.0)) "6m")
						((and (>= freq 144.0) (<= freq 148.0)) "2m")
						((and (>= freq 219.0) (<= freq 225.0)) "1.25m")
						((and (>= freq 430.0) (<= freq 450.0)) "70cm")
						(t nil))))
					 (when band
					   (setq adif-string
						 (concat adif-string
							 (format "<BAND:%d>%s" (length band) band)))))))
				   ;; Record the radio's MODE and SUBMODE even when those fields are
				   ;; not shown on the form.  SUBMODE is only meaningful alongside the
				   ;; MODE it belongs to, so it is added only when the logged MODE is
				   ;; the one the radio reports; if the operator typed a different
				   ;; mode, that choice stands and neither field is touched.
				   (when (and qso-hamlib-enable qso--hamlib-rig-mode)
				     (let* ((mode-pair (qso--hamlib-adif-mode))
				   	 (rig-mode (car mode-pair))
				   	 (rig-submode (cdr mode-pair)))
				       (when (and rig-mode (not (string-empty-p rig-mode)))
				         (unless (string-match "<MODE:" adif-string)
				   	(setq adif-string
				   	      (concat adif-string
				   		      (format "<MODE:%d>%s"
				   			      (length rig-mode) rig-mode))))
				         (when (and rig-submode
				   		 (not (string-empty-p rig-submode))
				   		 (not (string-match "<SUBMODE:" adif-string))
				   		 (string-match "<MODE:[0-9]+>\\([^<]+\\)" adif-string)
				   		 (equal (match-string 1 adif-string) rig-mode))
				   	(setq adif-string
				   	      (concat adif-string
				   		      (format "<SUBMODE:%d>%s"
				   			      (length rig-submode) rig-submode)))))))
				   ;; Fields found by a callsign lookup that are not on the form.
				   ;; They are tied to the callsign they were fetched for, so details
				   ;; of one station cannot end up in the record of another.
				   (when (and qso--lookup-extra
				   	   call-value
				   	   (equal (upcase call-value) qso--lookup-call))
				     (dolist (pair qso--lookup-extra)
				       (let ((tag (symbol-name (car pair)))
				   	  (value (cdr pair)))
				         (unless (string-match (format "<%s:" (regexp-quote tag)) adif-string)
				   	(setq adif-string
				   	      (concat adif-string
				   		      (format "<%s:%d>%s" tag (length value) value)))))))
				   ;; Append date and time to the ADIF string
                                   (setq adif-string
                                         (concat adif-string
                                                 (format "<QSO_DATE:8>%s" date-value)
                                                 (format "<TIME_ON:6>%s" time-value)
						 "<OPERATOR:"
						 (format "%d" (length (format "%s" qso-OPERATOR))) ">"
						 (format "%s" qso-OPERATOR)"<eor>\n")))
				 ;; Append data to file
				 (with-temp-buffer
                                   (insert adif-string)
                                   (write-region (point-min) (point-max) qso-adif-path t))))
			     (goto-char (point-min))
			     (widget-forward 1)
			     ;; The looked-up details belong to the contact just logged.
			     (setq qso--lookup-extra nil)
			     (setq qso--lookup-call nil)
			     (message "QSO logged!"))
		   "Submit")
    (widget-insert " ") ;; Add a space between buttons
    (widget-create 'push-button
                   :notify (lambda (&rest _)
                             (let ((_adif-string "")
				   (_call-value nil)
                                   (_date-value "")
                                   (_time-value "")
				   (qso--hamlib-inhibit t))
                               ;; Collect data from each widget
                               (dolist (field-pair widget-alist)
                                 (let* ((_field (nth 0 field-pair))
                                        (widget (nth 1 field-pair))
                                        (clear-after-submit (nth 2 field-pair))
                                        (_value (widget-value widget)))
                                     (when clear-after-submit
                                       (widget-value-set widget "")))))
			     (setq qso--lookup-extra nil)
			     (setq qso--lookup-call nil)
			     (goto-char (point-min))
			     (widget-forward 1))
                   "Clear")
    (widget-insert " ") ;; Add a space between buttons
    (widget-create 'push-button
                   :notify (lambda (&rest _)
                             (kill-buffer qso-form-buffer-name))
                   "Quit")
    (use-local-map qso-form-map)
    (widget-setup)
    (widget-forward 1)
    ;; Remember the widgets so that the radio poller, which runs long after
    ;; this function has returned, can reach them.
    (setq-local qso--widget-alist widget-alist)
    (setq-local qso--hamlib-written nil)
    (add-hook 'kill-buffer-hook #'qso-hamlib-stop nil t)
    (when qso-hamlib-enable
      (qso-hamlib-start))))
(provide 'qso)
;;; qso.el ends here
