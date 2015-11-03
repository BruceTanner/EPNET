; FTP
;
; This module implements the FTP protocol
;
		module	ftp
;
;==============================================================================
;
; This file is part of the EPNET software
;
; Copyright (C) 2015  Bruce Tanner
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; If you do use or modify this file, either for its original purpose or for
; something new, I'd love to hear about it! I can be contacted by email at:
;
; brucetanner@btopenworld.com
;
;==============================================================================
;
; For reference, here are the interesting bits of RFC 959:
;
; 4.  FILE TRANSFER FUNCTIONS
;
;   The communication channel from the user-PI to the server-PI is
;   established as a TCP connection from the user to the standard server
;   port.  The user protocol interpreter is responsible for sending FTP
;   commands and interpreting the replies received; the server-PI
;   interprets commands, sends replies and directs its DTP to set up the
;   data connection and transfer the data.  If the second party to the
;   data transfer (the passive transfer process) is the user-DTP, then it
;   is governed through the internal protocol of the user-FTP host; if it
;   is a second server-DTP, then it is governed by its PI on command from
;   the user-PI.  The FTP replies are discussed in the next section.  In
;   the description of a few of the commands in this section, it is
;   helpful to be explicit about the possible replies.
;
;   4.1.  FTP COMMANDS
;
;      4.1.1.  ACCESS CONTROL COMMANDS
;
;         The following commands specify access control identifiers
;         (command codes are shown in parentheses).
;
;         USER NAME (USER)
;
;            The argument field is a Telnet string identifying the user.
;            The user identification is that which is required by the
;            server for access to its file system.  This command will
;            normally be the first command transmitted by the user after
;            the control connections are made (some servers may require
;            this).  Additional identification information in the form of
;            a password and/or an account command may also be required by
;            some servers.  Servers may allow a new USER command to be
;            entered at any point in order to change the access control
;            and/or accounting information.  This has the effect of
;            flushing any user, password, and account information already
;            supplied and beginning the login sequence again.  All
;            transfer parameters are unchanged and any file transfer in
;            progress is completed under the old access control
;            parameters.
;
;         PASSWORD (PASS)
;
;            The argument field is a Telnet string specifying the user's
;            password.  This command must be immediately preceded by the
;            user name command, and, for some sites, completes the user's
;            identification for access control.  Since password
;            information is quite sensitive, it is desirable in general
;            to "mask" it or suppress typeout.  It appears that the
;            server has no foolproof way to achieve this.  It is
;            therefore the responsibility of the user-FTP process to hide
;            the sensitive password information.
;
;         ACCOUNT (ACCT)
;
;            The argument field is a Telnet string identifying the user's
;            account.  The command is not necessarily related to the USER
;            command, as some sites may require an account for login and
;            others only for specific access, such as storing files.  In
;            the latter case the command may arrive at any time.
;
;            There are reply codes to differentiate these cases for the
;            automation: when account information is required for login,
;            the response to a successful PASSword command is reply code
;            332.  On the other hand, if account information is NOT
;            required for login, the reply to a successful PASSword
;            command is 230; and if the account information is needed for
;            a command issued later in the dialogue, the server should
;            return a 332 or 532 reply depending on whether it stores
;            (pending receipt of the ACCounT command) or discards the
;            command, respectively.
;
;         CHANGE WORKING DIRECTORY (CWD)
;
;            This command allows the user to work with a different
;            directory or dataset for file storage or retrieval without
;            altering his login or accounting information.  Transfer
;            parameters are similarly unchanged.  The argument is a
;            pathname specifying a directory or other system dependent
;            file group designator.
;
;         CHANGE TO PARENT DIRECTORY (CDUP)
;
;            This command is a special case of CWD, and is included to
;            simplify the implementation of programs for transferring
;            directory trees between operating systems having different
;            syntaxes for naming the parent directory.  The reply codes
;            shall be identical to the reply codes of CWD.  See
;            Appendix II for further details.
;
;         STRUCTURE MOUNT (SMNT)
;
;            This command allows the user to mount a different file
;            system data structure without altering his login or
;            accounting information.  Transfer parameters are similarly
;            unchanged.  The argument is a pathname specifying a
;            directory or other system dependent file group designator.
;
;         REINITIALIZE (REIN)
;
;            This command terminates a USER, flushing all I/O and account
;            information, except to allow any transfer in progress to be
;            completed.  All parameters are reset to the default settings
;            and the control connection is left open.  This is identical
;            to the state in which a user finds himself immediately after
;            the control connection is opened.  A USER command may be
;            expected to follow.
;
;         LOGOUT (QUIT)
;
;            This command terminates a USER and if file transfer is not
;            in progress, the server closes the control connection.  If
;            file transfer is in progress, the connection will remain
;            open for result response and the server will then close it.
;            If the user-process is transferring files for several USERs
;            but does not wish to close and then reopen connections for
;            each, then the REIN command should be used instead of QUIT.
;
;            An unexpected close on the control connection will cause the
;            server to take the effective action of an abort (ABOR) and a
;            logout (QUIT).
;
;      4.1.2.  TRANSFER PARAMETER COMMANDS
;
;         All data transfer parameters have default values, and the
;         commands specifying data transfer parameters are required only
;         if the default parameter values are to be changed.  The default
;         value is the last specified value, or if no value has been
;         specified, the standard default value is as stated here.  This
;         implies that the server must "remember" the applicable default
;         values.  The commands may be in any order except that they must
;         precede the FTP service request.  The following commands
;         specify data transfer parameters:
;
;         DATA PORT (PORT)
;
;            The argument is a HOST-PORT specification for the data port
;            to be used in data connection.  There are defaults for both
;            the user and server data ports, and under normal
;            circumstances this command and its reply are not needed.  If
;            this command is used, the argument is the concatenation of a
;            32-bit internet host address and a 16-bit TCP port address.
;            This address information is broken into 8-bit fields and the
;            value of each field is transmitted as a decimal number (in
;            character string representation).  The fields are separated
;            by commas.  A port command would be:
;
;               PORT h1,h2,h3,h4,p1,p2
;
;            where h1 is the high order 8 bits of the internet host
;            address.
;
;         PASSIVE (PASV)
;
;            This command requests the server-DTP to "listen" on a data
;            port (which is not its default data port) and to wait for a
;            connection rather than initiate one upon receipt of a
;            transfer command.  The response to this command includes the
;            host and port address this server is listening on.
;
;         REPRESENTATION TYPE (TYPE)
;
;            The argument specifies the representation type as described
;            in the Section on Data Representation and Storage.  Several
;            types take a second parameter.  The first parameter is
;            denoted by a single Telnet character, as is the second
;            Format parameter for ASCII and EBCDIC; the second parameter
;            for local byte is a decimal integer to indicate Bytesize.
;            The parameters are separated by a <SP> (Space, ASCII code
;            32).
;
;            The following codes are assigned for type:
;
;                         \    /
;               A - ASCII |    | N - Non-print
;                         |-><-| T - Telnet format effectors
;               E - EBCDIC|    | C - Carriage Control (ASA)
;                         /    \
;               I - Image
;               
;               L <byte size> - Local byte Byte size
;
;            The default representation type is ASCII Non-print.  If the
;            Format parameter is changed, and later just the first
;            argument is changed, Format then returns to the Non-print
;            default.
;
;         FILE STRUCTURE (STRU)
;
;            The argument is a single Telnet character code specifying
;            file structure described in the Section on Data
;            Representation and Storage.
;
;            The following codes are assigned for structure:
;
;               F - File (no record structure)
;               R - Record structure
;               P - Page structure
;
;            The default structure is File.
;
;         TRANSFER MODE (MODE)
;
;            The argument is a single Telnet character code specifying
;            the data transfer modes described in the Section on
;            Transmission Modes.
;
;            The following codes are assigned for transfer modes:
;
;               S - Stream
;               B - Block
;               C - Compressed
;
;            The default transfer mode is Stream.
;
;      4.1.3.  FTP SERVICE COMMANDS
;
;         The FTP service commands define the file transfer or the file
;         system function requested by the user.  The argument of an FTP
;         service command will normally be a pathname.  The syntax of
;         pathnames must conform to server site conventions (with
;         standard defaults applicable), and the language conventions of
;         the control connection.  The suggested default handling is to
;         use the last specified device, directory or file name, or the
;         standard default defined for local users.  The commands may be
;         in any order except that a "rename from" command must be
;         followed by a "rename to" command and the restart command must
;         be followed by the interrupted service command (e.g., STOR or
;         RETR).  The data, when transferred in response to FTP service
;         commands, shall always be sent over the data connection, except
;         for certain informative replies.  The following commands
;         specify FTP service requests:
;
;         RETRIEVE (RETR)
;
;            This command causes the server-DTP to transfer a copy of the
;            file, specified in the pathname, to the server- or user-DTP
;            at the other end of the data connection.  The status and
;            contents of the file at the server site shall be unaffected.
;
;         STORE (STOR)
;
;            This command causes the server-DTP to accept the data
;            transferred via the data connection and to store the data as
;            a file at the server site.  If the file specified in the
;            pathname exists at the server site, then its contents shall
;            be replaced by the data being transferred.  A new file is
;            created at the server site if the file specified in the
;            pathname does not already exist.
;
;         STORE UNIQUE (STOU)
;
;            This command behaves like STOR except that the resultant
;            file is to be created in the current directory under a name
;            unique to that directory.  The 250 Transfer Started response
;            must include the name generated.
;
;         APPEND (with create) (APPE)
;
;            This command causes the server-DTP to accept the data
;            transferred via the data connection and to store the data in
;            a file at the server site.  If the file specified in the
;            pathname exists at the server site, then the data shall be
;            appended to that file; otherwise the file specified in the
;            pathname shall be created at the server site.
;
;         ALLOCATE (ALLO)
;
;            This command may be required by some servers to reserve
;            sufficient storage to accommodate the new file to be
;            transferred.  The argument shall be a decimal integer
;            representing the number of bytes (using the logical byte
;            size) of storage to be reserved for the file.  For files
;            sent with record or page structure a maximum record or page
;            size (in logical bytes) might also be necessary; this is
;            indicated by a decimal integer in a second argument field of
;            the command.  This second argument is optional, but when
;            present should be separated from the first by the three
;            Telnet characters <SP> R <SP>.  This command shall be
;            followed by a STORe or APPEnd command.  The ALLO command
;            should be treated as a NOOP (no operation) by those servers
;            which do not require that the maximum size of the file be
;            declared beforehand, and those servers interested in only
;            the maximum record or page size should accept a dummy value
;            in the first argument and ignore it.
;
;         RESTART (REST)
;
;            The argument field represents the server marker at which
;            file transfer is to be restarted.  This command does not
;            cause file transfer but skips over the file to the specified
;            data checkpoint.  This command shall be immediately followed
;            by the appropriate FTP service command which shall cause
;            file transfer to resume.
;
;         RENAME FROM (RNFR)
;
;            This command specifies the old pathname of the file which is
;            to be renamed.  This command must be immediately followed by
;            a "rename to" command specifying the new file pathname.
;
;         RENAME TO (RNTO)
;
;            This command specifies the new pathname of the file
;            specified in the immediately preceding "rename from"
;            command.  Together the two commands cause a file to be
;            renamed.
;
;         ABORT (ABOR)
;
;            This command tells the server to abort the previous FTP
;            service command and any associated transfer of data.  The
;            abort command may require "special action", as discussed in
;            the Section on FTP Commands, to force recognition by the
;            server.  No action is to be taken if the previous command
;            has been completed (including data transfer).  The control
;            connection is not to be closed by the server, but the data
;            connection must be closed.
;
;            There are two cases for the server upon receipt of this
;            command: (1) the FTP service command was already completed,
;            or (2) the FTP service command is still in progress.
;
;               In the first case, the server closes the data connection
;               (if it is open) and responds with a 226 reply, indicating
;               that the abort command was successfully processed.
;
;               In the second case, the server aborts the FTP service in
;               progress and closes the data connection, returning a 426
;               reply to indicate that the service request terminated
;               abnormally.  The server then sends a 226 reply,
;               indicating that the abort command was successfully
;               processed.
;
;         DELETE (DELE)
;
;            This command causes the file specified in the pathname to be
;            deleted at the server site.  If an extra level of protection
;            is desired (such as the query, "Do you really wish to
;            delete?"), it should be provided by the user-FTP process.
;
;         REMOVE DIRECTORY (RMD)
;
;            This command causes the directory specified in the pathname
;            to be removed as a directory (if the pathname is absolute)
;            or as a subdirectory of the current working directory (if
;            the pathname is relative).  See Appendix II.
;
;         MAKE DIRECTORY (MKD)
;
;            This command causes the directory specified in the pathname
;            to be created as a directory (if the pathname is absolute)
;            or as a subdirectory of the current working directory (if
;            the pathname is relative).  See Appendix II.
;
;         PRINT WORKING DIRECTORY (PWD)
;
;            This command causes the name of the current working
;            directory to be returned in the reply.  See Appendix II.
;
;         LIST (LIST)
;
;            This command causes a list to be sent from the server to the
;            passive DTP.  If the pathname specifies a directory or other
;            group of files, the server should transfer a list of files
;            in the specified directory.  If the pathname specifies a
;            file then the server should send current information on the
;            file.  A null argument implies the user's current working or
;            default directory.  The data transfer is over the data
;            connection in type ASCII or type EBCDIC.  (The user must
;            ensure that the TYPE is appropriately ASCII or EBCDIC).
;            Since the information on a file may vary widely from system
;            to system, this information may be hard to use automatically
;            in a program, but may be quite useful to a human user.
;
;         NAME LIST (NLST)
;
;            This command causes a directory listing to be sent from
;            server to user site.  The pathname should specify a
;            directory or other system-specific file group descriptor; a
;            null argument implies the current directory.  The server
;            will return a stream of names of files and no other
;            information.  The data will be transferred in ASCII or
;            EBCDIC type over the data connection as valid pathname
;            strings separated by <CRLF> or <NL>.  (Again the user must
;            ensure that the TYPE is correct.)  This command is intended
;            to return information that can be used by a program to
;            further process the files automatically.  For example, in
;            the implementation of a "multiple get" function.
;
;         SITE PARAMETERS (SITE)
;
;            This command is used by the server to provide services
;            specific to his system that are essential to file transfer
;            but not sufficiently universal to be included as commands in
;            the protocol.  The nature of these services and the
;            specification of their syntax can be stated in a reply to
;            the HELP SITE command.
;
;         SYSTEM (SYST)
;
;            This command is used to find out the type of operating
;            system at the server.  The reply shall have as its first
;            word one of the system names listed in the current version
;            of the Assigned Numbers document [4].
;
;         STATUS (STAT)
;
;            This command shall cause a status response to be sent over
;            the control connection in the form of a reply.  The command
;            may be sent during a file transfer (along with the Telnet IP
;            and Synch signals--see the Section on FTP Commands) in which
;            case the server will respond with the status of the
;            operation in progress, or it may be sent between file
;            transfers.  In the latter case, the command may have an
;            argument field.  If the argument is a pathname, the command
;            is analogous to the "list" command except that data shall be
;            transferred over the control connection.  If a partial
;            pathname is given, the server may respond with a list of
;            file names or attributes associated with that specification.
;            If no argument is given, the server should return general
;            status information about the server FTP process.  This
;            should include current values of all transfer parameters and
;            the status of connections.
;
;         HELP (HELP)
;
;            This command shall cause the server to send helpful
;            information regarding its implementation status over the
;            control connection to the user.  The command may take an
;            argument (e.g., any command name) and return more specific
;            information as a response.  The reply is type 211 or 214.
;            It is suggested that HELP be allowed before entering a USER
;            command. The server may use this reply to specify
;            site-dependent parameters, e.g., in response to HELP SITE.
;
;         NOOP (NOOP)
;
;            This command does not affect any parameters or previously
;            entered commands. It specifies no action other than that the
;            server send an OK reply.
;
;   The File Transfer Protocol follows the specifications of the Telnet
;   protocol for all communications over the control connection.  Since
;   the language used for Telnet communication may be a negotiated
;   option, all references in the next two sections will be to the
;   "Telnet language" and the corresponding "Telnet end-of-line code".
;   Currently, one may take these to mean NVT-ASCII and <CRLF>.  No other
;   specifications of the Telnet protocol will be cited.
;
;   FTP commands are "Telnet strings" terminated by the "Telnet end of
;   line code".  The command codes themselves are alphabetic characters
;   terminated by the character <SP> (Space) if parameters follow and
;   Telnet-EOL otherwise.  The command codes and the semantics of
;   commands are described in this section; the detailed syntax of
;   commands is specified in the Section on Commands, the reply sequences
;   are discussed in the Section on Sequencing of Commands and Replies,
;   and scenarios illustrating the use of commands are provided in the
;   Section on Typical FTP Scenarios.
;
;   FTP commands may be partitioned as those specifying access-control
;   identifiers, data transfer parameters, or FTP service requests.
;   Certain commands (such as ABOR, STAT, QUIT) may be sent over the
;   control connection while a data transfer is in progress.  Some
;   servers may not be able to monitor the control and data connections
;   simultaneously, in which case some special action will be necessary
;   to get the server's attention.  The following ordered format is
;   tentatively recommended:
;
;      1. User system inserts the Telnet "Interrupt Process" (IP) signal
;      in the Telnet stream.
;
;      2. User system sends the Telnet "Synch" signal.
;
;      3. User system inserts the command (e.g., ABOR) in the Telnet
;      stream.
;
;      4. Server PI, after receiving "IP", scans the Telnet stream for
;      EXACTLY ONE FTP command.
;
;   (For other servers this may not be necessary but the actions listed
;   above should have no unusual effect.)
;
;   4.2.  FTP REPLIES
;
;      Replies to File Transfer Protocol commands are devised to ensure
;      the synchronization of requests and actions in the process of file
;      transfer, and to guarantee that the user process always knows the
;      state of the Server.  Every command must generate at least one
;      reply, although there may be more than one; in the latter case,
;      the multiple replies must be easily distinguished.  In addition,
;      some commands occur in sequential groups, such as USER, PASS and
;      ACCT, or RNFR and RNTO.  The replies show the existence of an
;      intermediate state if all preceding commands have been successful.
;      A failure at any point in the sequence necessitates the repetition
;      of the entire sequence from the beginning.
;
;         The details of the command-reply sequence are made explicit in
;         a set of state diagrams below.
;
;      An FTP reply consists of a three digit number (transmitted as
;      three alphanumeric characters) followed by some text.  The number
;      is intended for use by automata to determine what state to enter
;      next; the text is intended for the human user.  It is intended
;      that the three digits contain enough encoded information that the
;      user-process (the User-PI) will not need to examine the text and
;      may either discard it or pass it on to the user, as appropriate.
;      In particular, the text may be server-dependent, so there are
;      likely to be varying texts for each reply code.
;
;      A reply is defined to contain the 3-digit code, followed by Space
;      <SP>, followed by one line of text (where some maximum line length
;      has been specified), and terminated by the Telnet end-of-line
;      code.  There will be cases however, where the text is longer than
;      a single line.  In these cases the complete text must be bracketed
;      so the User-process knows when it may stop reading the reply (i.e.
;      stop processing input on the control connection) and go do other
;      things.  This requires a special format on the first line to
;      indicate that more than one line is coming, and another on the
;      last line to designate it as the last.  At least one of these must
;      contain the appropriate reply code to indicate the state of the
;      transaction.  To satisfy all factions, it was decided that both
;      the first and last line codes should be the same.
;
;         Thus the format for multi-line replies is that the first line
;         will begin with the exact required reply code, followed
;         immediately by a Hyphen, "-" (also known as Minus), followed by
;         text.  The last line will begin with the same code, followed
;         immediately by Space <SP>, optionally some text, and the Telnet
;         end-of-line code.
;
;            For example:
;                                123-First line
;                                Second line
;                                  234 A line beginning with numbers
;                                123 The last line
;
;         The user-process then simply needs to search for the second
;         occurrence of the same reply code, followed by <SP> (Space), at
;         the beginning of a line, and ignore all intermediary lines.  If
;         an intermediary line begins with a 3-digit number, the Server
;         must pad the front  to avoid confusion.
;
;            This scheme allows standard system routines to be used for
;            reply information (such as for the STAT reply), with
;            "artificial" first and last lines tacked on.  In rare cases
;            where these routines are able to generate three digits and a
;            Space at the beginning of any line, the beginning of each
;            text line should be offset by some neutral text, like Space.
;
;         This scheme assumes that multi-line replies may not be nested.
;
;      The three digits of the reply each have a special significance.
;      This is intended to allow a range of very simple to very
;      sophisticated responses by the user-process.  The first digit
;      denotes whether the response is good, bad or incomplete.
;      (Referring to the state diagram), an unsophisticated user-process
;      will be able to determine its next action (proceed as planned,
;      redo, retrench, etc.) by simply examining this first digit.  A
;      user-process that wants to know approximately what kind of error
;      occurred (e.g. file system error, command syntax error) may
;      examine the second digit, reserving the third digit for the finest
;      gradation of information (e.g., RNTO command without a preceding
;      RNFR).
;
;         There are five values for the first digit of the reply code:
;
;            1yz   Positive Preliminary reply
;
;               The requested action is being initiated; expect another
;               reply before proceeding with a new command.  (The
;               user-process sending another command before the
;               completion reply would be in violation of protocol; but
;               server-FTP processes should queue any commands that
;               arrive while a preceding command is in progress.)  This
;               type of reply can be used to indicate that the command
;               was accepted and the user-process may now pay attention
;               to the data connections, for implementations where
;               simultaneous monitoring is difficult.  The server-FTP
;               process may send at most, one 1yz reply per command.
;
;            2yz   Positive Completion reply
;
;               The requested action has been successfully completed.  A
;               new request may be initiated.
;
;            3yz   Positive Intermediate reply
;
;               The command has been accepted, but the requested action
;               is being held in abeyance, pending receipt of further
;               information.  The user should send another command
;               specifying this information.  This reply is used in
;               command sequence groups.
;
;            4yz   Transient Negative Completion reply
;
;               The command was not accepted and the requested action did
;               not take place, but the error condition is temporary and
;               the action may be requested again.  The user should
;               return to the beginning of the command sequence, if any.
;               It is difficult to assign a meaning to "transient",
;               particularly when two distinct sites (Server- and
;               User-processes) have to agree on the interpretation.
;               Each reply in the 4yz category might have a slightly
;               different time value, but the intent is that the
;               user-process is encouraged to try again.  A rule of thumb
;               in determining if a reply fits into the 4yz or the 5yz
;               (Permanent Negative) category is that replies are 4yz if
;               the commands can be repeated without any change in
;               command form or in properties of the User or Server
;               (e.g., the command is spelled the same with the same
;               arguments used; the user does not change his file access
;               or user name; the server does not put up a new
;               implementation.)
;
;            5yz   Permanent Negative Completion reply
;
;               The command was not accepted and the requested action did
;               not take place.  The User-process is discouraged from
;               repeating the exact request (in the same sequence).  Even
;               some "permanent" error conditions can be corrected, so
;               the human user may want to direct his User-process to
;               reinitiate the command sequence by direct action at some
;               point in the future (e.g., after the spelling has been
;               changed, or the user has altered his directory status.)
;
;         The following function groupings are encoded in the second
;         digit:
;
;            x0z   Syntax - These replies refer to syntax errors,
;                  syntactically correct commands that don't fit any
;                  functional category, unimplemented or superfluous
;                  commands.
;
;            x1z   Information -  These are replies to requests for
;                  information, such as status or help.
;
;            x2z   Connections - Replies referring to the control and
;                  data connections.
;
;            x3z   Authentication and accounting - Replies for the login
;                  process and accounting procedures.
;
;            x4z   Unspecified as yet.
;
;            x5z   File system - These replies indicate the status of the
;                  Server file system vis-a-vis the requested transfer or
;                  other file system action.
;
;         The third digit gives a finer gradation of meaning in each of
;         the function categories, specified by the second digit.  The
;         list of replies below will illustrate this.  Note that the text
;         associated with each reply is recommended, rather than
;         mandatory, and may even change according to the command with
;         which it is associated.  The reply codes, on the other hand,
;         must strictly follow the specifications in the last section;
;         that is, Server implementations should not invent new codes for
;         situations that are only slightly different from the ones
;         described here, but rather should adapt codes already defined.
;
;            A command such as TYPE or ALLO whose successful execution
;            does not offer the user-process any new information will
;            cause a 200 reply to be returned.  If the command is not
;            implemented by a particular Server-FTP process because it
;            has no relevance to that computer system, for example ALLO
;            at a TOPS20 site, a Positive Completion reply is still
;            desired so that the simple User-process knows it can proceed
;            with its course of action.  A 202 reply is used in this case
;            with, for example, the reply text:  "No storage allocation
;            necessary."  If, on the other hand, the command requests a
;            non-site-specific action and is unimplemented, the response
;            is 502.  A refinement of that is the 504 reply for a command
;            that is implemented, but that requests an unimplemented
;            parameter.
;
;      4.2.1  Reply Codes by Function Groups
;
;         200 Command okay.
;         500 Syntax error, command unrecognized.
;             This may include errors such as command line too long.
;         501 Syntax error in parameters or arguments.
;         202 Command not implemented, superfluous at this site.
;         502 Command not implemented.
;         503 Bad sequence of commands.
;         504 Command not implemented for that parameter.
;          
;         110 Restart marker reply.
;             In this case, the text is exact and not left to the
;             particular implementation; it must read:
;                  MARK yyyy = mmmm
;             Where yyyy is User-process data stream marker, and mmmm
;             server's equivalent marker (note the spaces between markers
;             and "=").
;         211 System status, or system help reply.
;         212 Directory status.
;         213 File status.
;         214 Help message.
;             On how to use the server or the meaning of a particular
;             non-standard command.  This reply is useful only to the
;             human user.
;         215 NAME system type.
;             Where NAME is an official system name from the list in the
;             Assigned Numbers document.
;          
;         120 Service ready in nnn minutes.
;         220 Service ready for new user.
;         221 Service closing control connection.
;             Logged out if appropriate.
;         421 Service not available, closing control connection.
;             This may be a reply to any command if the service knows it
;             must shut down.
;         125 Data connection already open; transfer starting.
;         225 Data connection open; no transfer in progress.
;         425 Can't open data connection.
;         226 Closing data connection.
;             Requested file action successful (for example, file
;             transfer or file abort).
;         426 Connection closed; transfer aborted.
;         227 Entering Passive Mode (h1,h2,h3,h4,p1,p2).
;          
;         230 User logged in, proceed.
;         530 Not logged in.
;         331 User name okay, need password.
;         332 Need account for login.
;         532 Need account for storing files.
;          
;         150 File status okay; about to open data connection.
;         250 Requested file action okay, completed.
;         257 "PATHNAME" created.
;         350 Requested file action pending further information.
;         450 Requested file action not taken.
;             File unavailable (e.g., file busy).
;         550 Requested action not taken.
;             File unavailable (e.g., file not found, no access).
;         451 Requested action aborted. Local error in processing.
;         551 Requested action aborted. Page type unknown.
;         452 Requested action not taken.
;             Insufficient storage space in system.
;         552 Requested file action aborted.
;             Exceeded storage allocation (for current directory or
;             dataset).
;         553 Requested action not taken.
;             File name not allowed.
;         
;
;      4.2.2 Numeric  Order List of Reply Codes
;
;         110 Restart marker reply.
;             In this case, the text is exact and not left to the
;             particular implementation; it must read:
;                  MARK yyyy = mmmm
;             Where yyyy is User-process data stream marker, and mmmm
;             server's equivalent marker (note the spaces between markers
;             and "=").
;         120 Service ready in nnn minutes.
;         125 Data connection already open; transfer starting.
;         150 File status okay; about to open data connection.
;         200 Command okay.
;         202 Command not implemented, superfluous at this site.
;         211 System status, or system help reply.
;         212 Directory status.
;         213 File status.
;         214 Help message.
;             On how to use the server or the meaning of a particular
;             non-standard command.  This reply is useful only to the
;             human user.
;         215 NAME system type.
;             Where NAME is an official system name from the list in the
;             Assigned Numbers document.
;         220 Service ready for new user.
;         221 Service closing control connection.
;             Logged out if appropriate.
;         225 Data connection open; no transfer in progress.
;         226 Closing data connection.
;             Requested file action successful (for example, file
;             transfer or file abort).
;         227 Entering Passive Mode (h1,h2,h3,h4,p1,p2).
;         230 User logged in, proceed.
;         250 Requested file action okay, completed.
;         257 "PATHNAME" created.
;          
;         331 User name okay, need password.
;         332 Need account for login.
;         350 Requested file action pending further information.
;          
;         421 Service not available, closing control connection.
;             This may be a reply to any command if the service knows it
;             must shut down.
;         425 Can't open data connection.
;         426 Connection closed; transfer aborted.
;         450 Requested file action not taken.
;             File unavailable (e.g., file busy).
;         451 Requested action aborted: local error in processing.
;         452 Requested action not taken.
;             Insufficient storage space in system.
;         500 Syntax error, command unrecognized.
;             This may include errors such as command line too long.
;         501 Syntax error in parameters or arguments.
;         502 Command not implemented.
;         503 Bad sequence of commands.
;         504 Command not implemented for that parameter.
;         530 Not logged in.
;         532 Need account for storing files.
;         550 Requested action not taken.
;             File unavailable (e.g., file not found, no access).
;         551 Requested action aborted: page type unknown.
;         552 Requested file action aborted.
;             Exceeded storage allocation (for current directory or
;             dataset).
;         553 Requested action not taken.
;             File name not allowed.
;         
;
; 5.  DECLARATIVE SPECIFICATIONS
;
;   5.1.  MINIMUM IMPLEMENTATION
;
;      In order to make FTP workable without needless error messages, the
;      following minimum implementation is required for all servers:
;
;         TYPE - ASCII Non-print
;         MODE - Stream
;         STRUCTURE - File, Record
;         COMMANDS - USER, QUIT, PORT,
;                    TYPE, MODE, STRU,
;                      for the default values
;                    RETR, STOR,
;                    NOOP.
;
;      The default values for transfer parameters are:
;
;         TYPE - ASCII Non-print
;         MODE - Stream
;         STRU - File
;
;      All hosts must accept the above as the standard defaults.
;
;   5.2.  CONNECTIONS
;
;      The server protocol interpreter shall "listen" on Port L.  The
;      user or user protocol interpreter shall initiate the full-duplex
;      control connection.  Server- and user- processes should follow the
;      conventions of the Telnet protocol as specified in the
;      ARPA-Internet Protocol Handbook [1].  Servers are under no
;      obligation to provide for editing of command lines and may require
;      that it be done in the user host.  The control connection shall be
;      closed by the server at the user's request after all transfers and
;      replies are completed.
;
;      The user-DTP must "listen" on the specified data port; this may be
;      the default user port (U) or a port specified in the PORT command.
;      The server shall initiate the data connection from his own default
;      data port (L-1) using the specified user data port.  The direction
;      of the transfer and the port used will be determined by the FTP
;      service command.
;
;      Note that all FTP implementation must support data transfer using
;      the default port, and that only the USER-PI may initiate the use
;      of non-default ports.
;
;      When data is to be transferred between two servers, A and B (refer
;      to Figure 2), the user-PI, C, sets up control connections with
;      both server-PI's.  One of the servers, say A, is then sent a PASV
;      command telling him to "listen" on his data port rather than
;      initiate a connection when he receives a transfer service command.
;      When the user-PI receives an acknowledgment to the PASV command,
;      which includes the identity of the host and port being listened
;      on, the user-PI then sends A's port, a, to B in a PORT command; a
;      reply is returned.  The user-PI may then send the corresponding
;      service commands to A and B.  Server B initiates the connection
;      and the transfer proceeds.  The command-reply sequence is listed
;      below where the messages are vertically synchronous but
;      horizontally asynchronous:
;
;         User-PI - Server A                User-PI - Server B
;         ------------------                ------------------
;         
;         C->A : Connect                    C->B : Connect
;         C->A : PASV
;         A->C : 227 Entering Passive Mode. A1,A2,A3,A4,a1,a2
;                                           C->B : PORT A1,A2,A3,A4,a1,a2
;                                           B->C : 200 Okay
;         C->A : STOR                       C->B : RETR
;                    B->A : Connect to HOST-A, PORT-a
;
;                                Figure 3
;
;      The data connection shall be closed by the server under the
;      conditions described in the Section on Establishing Data
;      Connections.  If the data connection is to be closed following a
;      data transfer where closing the connection is not required to
;      indicate the end-of-file, the server must do so immediately.
;      Waiting until after a new transfer command is not permitted
;      because the user-process will have already tested the data
;      connection to see if it needs to do a "listen"; (remember that the
;      user must "listen" on a closed data port BEFORE sending the
;      transfer request).  To prevent a race condition here, the server
;      sends a reply (226) after closing the data connection (or if the
;      connection is left open, a "file transfer completed" reply (250)
;      and the user-PI should wait for one of these replies before
;      issuing a new transfer command).
;
;      Any time either the user or server see that the connection is
;      being closed by the other side, it should promptly read any
;      remaining data queued on the connection and issue the close on its
;      own side.
;
;   5.3.  COMMANDS
;
;      The commands are Telnet character strings transmitted over the
;      control connections as described in the Section on FTP Commands.
;      The command functions and semantics are described in the Section
;      on Access Control Commands, Transfer Parameter Commands, FTP
;      Service Commands, and Miscellaneous Commands.  The command syntax
;      is specified here.
;
;      The commands begin with a command code followed by an argument
;      field.  The command codes are four or fewer alphabetic characters.
;      Upper and lower case alphabetic characters are to be treated
;      identically.  Thus, any of the following may represent the
;      retrieve command:
;
;                  RETR    Retr    retr    ReTr    rETr
;
;      This also applies to any symbols representing parameter values,
;      such as A or a for ASCII TYPE.  The command codes and the argument
;      fields are separated by one or more spaces.
;
;      The argument field consists of a variable length character string
;      ending with the character sequence <CRLF> (Carriage Return, Line
;      Feed) for NVT-ASCII representation; for other negotiated languages
;      a different end of line character might be used.  It should be
;      noted that the server is to take no action until the end of line
;      code is received.
;
;      The syntax is specified below in NVT-ASCII.  All characters in the
;      argument field are ASCII characters including any ASCII
;      represented decimal integers.  Square brackets denote an optional
;      argument field.  If the option is not taken, the appropriate
;      default is implied.
;
;      5.3.1.  FTP COMMANDS
;
;         The following are the FTP commands:
;
;            USER <SP> <username> <CRLF>
;            PASS <SP> <password> <CRLF>
;            ACCT <SP> <account-information> <CRLF>
;            CWD  <SP> <pathname> <CRLF>
;            CDUP <CRLF>
;            SMNT <SP> <pathname> <CRLF>
;            QUIT <CRLF>
;            REIN <CRLF>
;            PORT <SP> <host-port> <CRLF>
;            PASV <CRLF>
;            TYPE <SP> <type-code> <CRLF>
;            STRU <SP> <structure-code> <CRLF>
;            MODE <SP> <mode-code> <CRLF>
;            RETR <SP> <pathname> <CRLF>
;            STOR <SP> <pathname> <CRLF>
;            STOU <CRLF>
;            APPE <SP> <pathname> <CRLF>
;            ALLO <SP> <decimal-integer>
;                [<SP> R <SP> <decimal-integer>] <CRLF>
;            REST <SP> <marker> <CRLF>
;            RNFR <SP> <pathname> <CRLF>
;            RNTO <SP> <pathname> <CRLF>
;            ABOR <CRLF>
;            DELE <SP> <pathname> <CRLF>
;            RMD  <SP> <pathname> <CRLF>
;            MKD  <SP> <pathname> <CRLF>
;            PWD  <CRLF>
;            LIST [<SP> <pathname>] <CRLF>
;            NLST [<SP> <pathname>] <CRLF>
;            SITE <SP> <string> <CRLF>
;            SYST <CRLF>
;            STAT [<SP> <pathname>] <CRLF>
;            HELP [<SP> <string>] <CRLF>
;            NOOP <CRLF>
;
;      5.3.2.  FTP COMMAND ARGUMENTS
;
;         The syntax of the above argument fields (using BNF notation
;         where applicable) is:
;
;            <username> ::= <string>
;            <password> ::= <string>
;            <account-information> ::= <string>
;            <string> ::= <char> | <char><string>
;            <char> ::= any of the 128 ASCII characters except <CR> and
;            <LF>
;            <marker> ::= <pr-string>
;            <pr-string> ::= <pr-char> | <pr-char><pr-string>
;            <pr-char> ::= printable characters, any
;                          ASCII code 33 through 126
;            <byte-size> ::= <number>
;            <host-port> ::= <host-number>,<port-number>
;            <host-number> ::= <number>,<number>,<number>,<number>
;            <port-number> ::= <number>,<number>
;            <number> ::= any decimal integer 1 through 255
;            <form-code> ::= N | T | C
;            <type-code> ::= A [<sp> <form-code>]
;                          | E [<sp> <form-code>]
;                          | I
;                          | L <sp> <byte-size>
;            <structure-code> ::= F | R | P
;            <mode-code> ::= S | B | C
;            <pathname> ::= <string>
;            <decimal-integer> ::= any decimal integer
;
;   5.4.  SEQUENCING OF COMMANDS AND REPLIES
;
;      The communication between the user and server is intended to be an
;      alternating dialogue.  As such, the user issues an FTP command and
;      the server responds with a prompt primary reply.  The user should
;      wait for this initial primary success or failure response before
;      sending further commands.
;
;      Certain commands require a second reply for which the user should
;      also wait.  These replies may, for example, report on the progress
;      or completion of file transfer or the closing of the data
;      connection.  They are secondary replies to file transfer commands.
;
;      One important group of informational replies is the connection
;      greetings.  Under normal circumstances, a server will send a 220
;      reply, "awaiting input", when the connection is completed.  The
;      user should wait for this greeting message before sending any
;      commands.  If the server is unable to accept input right away, a
;      120 "expected delay" reply should be sent immediately and a 220
;      reply when ready.  The user will then know not to hang up if there
;      is a delay.
;
;      Spontaneous Replies
;
;         Sometimes "the system" spontaneously has a message to be sent
;         to a user (usually all users).  For example, "System going down
;         in 15 minutes".  There is no provision in FTP for such
;         spontaneous information to be sent from the server to the user.
;         It is recommended that such information be queued in the
;         server-PI and delivered to the user-PI in the next reply
;         (possibly making it a multi-line reply).
;
;      The table below lists alternative success and failure replies for
;      each command.  These must be strictly adhered to; a server may
;      substitute text in the replies, but the meaning and action implied
;      by the code numbers and by the specific command reply sequence
;      cannot be altered.
;
;      Command-Reply Sequences
;
;         In this section, the command-reply sequence is presented.  Each
;         command is listed with its possible replies; command groups are
;         listed together.  Preliminary replies are listed first (with
;         their succeeding replies indented and under them), then
;         positive and negative completion, and finally intermediary
;         replies with the remaining commands from the sequence
;         following.  This listing forms the basis for the state
;         diagrams, which will be presented separately.
;
;            Connection Establishment
;               120
;                  220
;               220
;               421
;            Login
;               USER
;                  230
;                  530
;                  500, 501, 421
;                  331, 332
;               PASS
;                  230
;                  202
;                  530
;                  500, 501, 503, 421
;                  332
;               ACCT
;                  230
;                  202
;                  530
;                  500, 501, 503, 421
;               CWD
;                  250
;                  500, 501, 502, 421, 530, 550
;               CDUP
;                  200
;                  500, 501, 502, 421, 530, 550
;               SMNT
;                  202, 250
;                  500, 501, 502, 421, 530, 550
;            Logout
;               REIN
;                  120
;                     220
;                  220
;                  421
;                  500, 502
;               QUIT
;                  221
;                  500
;            Transfer parameters
;               PORT
;                  200
;                  500, 501, 421, 530
;               PASV
;                  227
;                  500, 501, 502, 421, 530
;               MODE
;                  200
;                  500, 501, 504, 421, 530
;               TYPE
;                  200
;                  500, 501, 504, 421, 530
;               STRU
;                  200
;                  500, 501, 504, 421, 530
;            File action commands
;               ALLO
;                  200
;                  202
;                  500, 501, 504, 421, 530
;               REST
;                  500, 501, 502, 421, 530
;                  350
;               STOR
;                  125, 150
;                     (110)
;                     226, 250
;                     425, 426, 451, 551, 552
;                  532, 450, 452, 553
;                  500, 501, 421, 530
;               STOU
;                  125, 150
;                     (110)
;                     226, 250
;                     425, 426, 451, 551, 552
;                  532, 450, 452, 553
;                  500, 501, 421, 530
;               RETR
;                  125, 150
;                     (110)
;                     226, 250
;                     425, 426, 451
;                  450, 550
;                  500, 501, 421, 530
;               LIST
;                  125, 150
;                     226, 250
;                     425, 426, 451
;                  450
;                  500, 501, 502, 421, 530
;               NLST
;                  125, 150
;                     226, 250
;                     425, 426, 451
;                  450
;                  500, 501, 502, 421, 530
;               APPE
;                  125, 150
;                     (110)
;                     226, 250
;                     425, 426, 451, 551, 552
;                  532, 450, 550, 452, 553
;                  500, 501, 502, 421, 530
;               RNFR
;                  450, 550
;                  500, 501, 502, 421, 530
;                  350
;               RNTO
;                  250
;                  532, 553
;                  500, 501, 502, 503, 421, 530
;               DELE
;                  250
;                  450, 550
;                  500, 501, 502, 421, 530
;               RMD
;                  250
;                  500, 501, 502, 421, 530, 550
;               MKD
;                  257
;                  500, 501, 502, 421, 530, 550
;               PWD
;                  257
;                  500, 501, 502, 421, 550
;               ABOR
;                  225, 226
;                  500, 501, 502, 421
;            Informational commands
;               SYST
;                  215
;                  500, 501, 502, 421
;               STAT
;                  211, 212, 213
;                  450
;                  500, 501, 502, 421, 530
;               HELP
;                  211, 214
;                  500, 501, 502, 421
;            Miscellaneous commands
;               SITE
;                  200
;                  202
;                  500, 501, 530
;               NOOP
;                  200
;                  500 421
;
; 7.  TYPICAL FTP SCENARIO
;
;   User at host U wanting to transfer files to/from host S:
;
;   In general, the user will communicate to the server via a mediating
;   user-FTP process.  The following may be a typical scenario.  The
;   user-FTP prompts are shown in parentheses, '---->' represents
;   commands from host U to host S, and '<----' represents replies from
;   host S to host U.
;
;      LOCAL COMMANDS BY USER              ACTION INVOLVED
;
;      ftp (host) multics<CR>         Connect to host S, port L,
;                                     establishing control connections.
;                                     <---- 220 Service ready <CRLF>.
;      username Doe <CR>              USER Doe<CRLF>---->
;                                     <---- 331 User name ok,
;                                               need password<CRLF>.
;      password mumble <CR>           PASS mumble<CRLF>---->
;                                     <---- 230 User logged in<CRLF>.
;      retrieve (local type) ASCII<CR>
;      (local pathname) test 1 <CR>   User-FTP opens local file in ASCII.
;      (for. pathname) test.pl1<CR>   RETR test.pl1<CRLF> ---->
;                                     <---- 150 File status okay;
;                                           about to open data
;                                           connection<CRLF>.
;                                     Server makes data connection
;                                     to port U.
;      
;                                     <---- 226 Closing data connection,
;                                         file transfer successful<CRLF>.
;      type Image<CR>                 TYPE I<CRLF> ---->
;                                     <---- 200 Command OK<CRLF>
;      store (local type) image<CR>
;      (local pathname) file dump<CR> User-FTP opens local file in Image.
;      (for.pathname) >udd>cn>fd<CR>  STOR >udd>cn>fd<CRLF> ---->
;                                     <---- 550 Access denied<CRLF>
;      terminate                      QUIT <CRLF> ---->
;                                     Server closes all
;                                     connections.
;
; 8.  CONNECTION ESTABLISHMENT
;
;   The FTP control connection is established via TCP between the user
;   process port U and the server process port L.  This protocol is
;   assigned the service port 21 (25 octal), that is L=21.
;
;==============================================================================
;
;
CONTROL_DPORT	equ	21		; Server listens on port 21
CONTROL_SPORT	equ	22		; Our port
;
;
; open_control
;
; Opens the control session to the FTP server
;
; In:   A=socket number
;      HL->ip address to connect to
; Out: NC if successful
;
open_control:	ld	(vars.ftp.socket),a
;
		bit	vars.trace.ftp,(iy+vars._trace)
		jr	z,.notrace
;
		ld	de,trace.ftp.open
		call	trace
;
		push	hl
		 call	io.ip
		 call	trace.dots
		pop	hl		; HL->server IP
;
		ld	a,(vars.ftp.socket)
;
.notrace:	push	hl		; Save ->IP address
		 ld	hl,CONTROL_SPORT; HL=our port number
		 ld	de,owner_str
		 call	tcp.open
		pop	de		; DE->IP address
		jr	c,.done
;
		ld	hl,CONTROL_DPORT; HL=server port no.
		ld	a,(vars.ftp.socket)
		call	tcp.connect
;
.done:		bit	vars.trace.ftp,(iy+vars._trace)
		ret	z
;
		jp	trace.is_error
;
;------------------------------------------------------------------------------
; login
;
; Called after open_control to read the hello string from the server and send
; login commands
;
; In:  vars.ftp.socket contains the socket number if called immediately
;      after open_control
;      DE->user name, length byte first
; Out: Cy=>error, not logged in
;
login:
		bit	vars.trace.ftp,(iy+vars._trace)
		jr	z,.notrace
;
		push	de
		 ld	de,trace.ftp.login
		 call	trace
		pop	de
.notrace:
		; Copy user name arg to buffer
		ex	de,hl		; HL->user name arg
		ld	de,vars.ftp.user
		push	de		; Save -> user name buffer
		 ld	c,(hl)		; Get length byte
		 inc	c		; Include length byte
		 ld	a,vars.ftp.user_size-1
		 cp	c
		 jr	nc,.lenok
		 ld	c,a
.lenok:		 ld	b,0
		 ldir
;
		 call	get_response	; Wait for "hello message" from server
		pop	hl		; HL->vars.ftp.user
		ret	c
;
		ld	a,(hl)		; Got user name?
		or	a
		jr	nz,.gotuser	; Go if username given on command line
;
		ld	de,userprompt_str
		ld	c,vars.ftp.user_size
		push	hl		; Save -> user name buffer
		 call	io.input	; Prompt user for user name
		pop	hl		; HL->user name buffer
		ret	c
;
		ld	a,(hl)
		or	a
		jr	nz,.gotuser
;
		push	hl		; Save -> user name buffer
		ex	de,hl		; DE->username buffer
		ld	hl,anonymous_str
		ld	bc,anonymous_str_size
		ldir			; Copy default username
		pop	hl		; HL->user name buffer
;
.gotuser:	ex	de,hl		; DE->user name
		ld	hl,user_str
		call	issue_arg
		ret	c
;
		ld	de,331		; Password required
		or	a
		sbc	hl,de
		ret	nz
;
		ld	hl,vars.ftp.pass
		ld	de,passprompt_str
		ld	c,vars.ftp.pass_size
		push	hl
		 call	io.input	; Prompt usert for password
		pop	hl		; HL->password buffer
		ret	c
;
		ld	a,(hl)
		or	a
		jr	nz,.gotpass
;
		push	hl		; Save -> password buffer
		ex	de,hl		; DE->password buffer
		ld	hl,localhost_str
		ld	bc,localhost_str_size
		ldir			; Copy default password
		pop	hl		; HL->password buffer
;
.gotpass:	ex	de,hl		; DE->password
		ld	hl,pass_str
		ld	de,vars.ftp.pass
		call	issue_arg
		ret	c
;
		ld	de,400		; <400 ok, >=400 =>error
		sbc	hl,de
		ccf
		ret
;
;
anonymous_str:		db	9,"anonymous"
anonymous_str_size	equ	$-anonymous_str		; Includes length byte
;
localhost_str:		db	14,"anon@localhost"
localhost_str_size	equ	$-localhost_str		; Includes length byte
;
userprompt_str:		db	"User name [anonymous]: ",0
passprompt_str:		db	"Password [anon@localhost]: ",0
;
;
;------------------------------------------------------------------------------
; logout
;
; This is called to cleanly log out of the FTP session.
;
; In:  A=socket number
;
logout:		ld	(vars.ftp.socket),a
;
		ld	hl,quit_str
		jp	issue
;
;
;------------------------------------------------------------------------------
; dir
;
; Issues an FTP LIST command
;
; DIR is more complicated than most of the commands because the response to
; the LIST command is sent to the FTP data connection, so we have to issue
; a PASV command, open the channel...
;
; In:  A=socket number
;     DE->argment, length byte first
; Out: A=EXOS error code
;
dir:		ld	(vars.ftp.socket),a
;
		push	de		; Save ->arg
		 call	open_data	; Open data connection
		pop	de		; DE->arg
		ld	a,exos.ERR_FTPDATA
		jp	c,exos.check_stop
;
		ld	hl,list_str
		call	issue_arg	; Send LIST command
		jr	c,.timeout	; Go with Cy if timeout
;
		xor	a		; Socket 0
		call	read		; Read data from socket
		jr	c,.timeout	; Go with Cy if timeout
;
.print:		push	hl		; Save buffer start
		 add	hl,bc		; Point to last byte read
		 ld	(hl),0		; Terminate it
		pop	hl		; HL->response
;
		ex	de,hl		; DE->data
		call	io.str		; Print it
;
		xor	a		; Socket 0
		call	socket.get_rx_size; More than 1 buffer full?
		ld	a,h
		or	l
		jr	z,.done		; Go if not
;
		ld	c,l
		ld	b,h		; BC=remainder size
		ld	hl,vars.ftp.buffer_size-2; See if it will fit in buffer
		or	a
		sbc	hl,bc
		jr	nc,.doread	; Go if it will fit in buffer
;
		ld	bc,vars.ftp.buffer_size-2; Else limit to buffer size
.doread:	ld	hl,vars.ftp.buffer
		push	hl		; Save start of buffer
		push	bc		; Save bytes that will be in buffer
		 xor	a
		 call	socket.read	; Read response
		pop	bc		; BC=size of response
		pop	hl		; HL->response
		jr	.print
;
.done:		xor	a
		call	socket.read_end

		or	a		; NC=>No error
.timeout:	sbc	a,a		; ff=>error, 0 => ok
		and	exos.ERR_TIMEOUT; Error code or 0
.close:		push	af
		xor	a
		call	tcp.close	; Close data channel
		pop	af
		ret	nz		; Return if error
;
		ld	a,(vars.ftp.socket)
		call	is_response	; Get any response after data
;
		xor	a		; 0=>no error
		ret
;
;
;------------------------------------------------------------------------------
; status
;
; Issues an FTP SYST command
;
; In:  A=socket number
;
status:
		ld	(vars.ftp.socket),a
;
		ld	hl,syst_str
		jr	issue_print
;
;
;------------------------------------------------------------------------------
; chdir
;
; Issues an FTP PWD, CWD or CDUP command depending on the argument.
;
; In:  A=socket number
;     DE->argment, length byte first
;
chdir:		ld	(vars.ftp.socket),a
;
		ld	a,(de)
		or	a
		jr	z,.pwd		; No arg - just print current directory
;
		cp	2
		jr	nz,.cd		; Not ".." - cd to specified directory
;
		inc	de
		ld	a,(de)
		cp	'.'
		jr	nz,.deccd
		inc	de
		ld	a,(de)
		cp	'.'
		jr	z,.cdup
		dec	de
.deccd:		dec	de
;
.cd:		ld	hl,cwd_str	; Send CWD <dir> command
		jr	issue_arg
;
.cdup:		ld	hl,cdup_str	; Send CDUP command
		jr	issue
;
.pwd:		ld	hl,pwd_str	; Send PWD command
issue_print:	call	issue
		ld	de,vars.ftp.buffer	; Print response
		jp	io.str
;
;
;------------------------------------------------------------------------------
; mkdir
;
; Issues an FTP MKD command
;
; In:  A=socket number
;     DE->pathname, length byte first
;
mkdir:		ld	(vars.ftp.socket),a
;
		ld	hl,mkd_str
		jr	issue_arg		; Issue command and arg
;
;
;------------------------------------------------------------------------------
; rmdir
;
; Issues an FTP RMD command
;
; In:  A=socket number
;     DE->pathname, length byte first
;
rmdir:
		ld	(vars.ftp.socket),a
;
		ld	hl,rmd_str
		jr	issue_arg		; Issue command and arg
;
;
;------------------------------------------------------------------------------
; del
;
; Issues an FTP DELE command
;
; In:  A=socket number
;     DE->pathname, length byte first
;
del:
		ld	(vars.ftp.socket),a
;
		ld	hl,dele_str
		jr	issue_arg		; Issue command and arg

;------------------------------------------------------------------------------
; ren
;
; Issues FTP RNFR and RNTO commands
;
; In:  A=socket number
;     DE->from name, length byte first
;     HL->to name, length byte first
;
ren:
		ld	(vars.ftp.socket),a
;
		push	hl		; Save to name
		 ld	hl,rnfr_str
		 call	issue_arg	; Issue command and arg
		pop	de		; DE->to name
		ret	c
;
		ld	hl,rnto_str
		jr	issue_arg	; Issue command and arg
;
;
;------------------------------------------------------------------------------
; get_response
;
; After issuing an FTP command reads the response with timeout, and returns
; the response code
;
; Out: Cy=>we didn't get a response
;      HL=response code
;       A=EXOS error code corresponding to the FTP response code
issue:		ld	de,0
issue_arg:	call	issue_cmd
		jr	get_response
;
is_response:	ld	a,(vars.ftp.socket)	; See if any response yet
		call	socket.available
		ret	z
get_response:
		ld	a,(vars.ftp.socket)	; See if any response yet
		call	read
		ld	a,exos.ERR_TIMEOUT
		jp	c,exos.check_stop
;
.noerr:
		push	hl			; Save buffer start
		 add	hl,bc			; Point to last byte read
		 ld	(hl),0			; Terminate it
		 push	bc
		  ld	a,(vars.ftp.socket)
		  call	socket.read_end
		 pop	bc
		pop	hl			; HL->response
;
		bit	vars.trace.ftp,(iy+vars._trace)
		jr	z,.donetrace
;
		push	hl			; Save->response string
		push	bc			; Save #bytes
		 ld	de,trace.ftp.rx
		 call	trace
		 ex	de,hl			; DE->response string
		 call	io.str
		pop	bc			; BC=byte count
		pop	hl			; HL->response string
.donetrace:
;
		push	hl			; Save->response string
		push	bc			; Save byte count
		 call	read_code		; HL=response error/status code
		pop	bc			; BC=byte count
		pop	de			; DE->response string
;
		push	hl			; Save FTP response code
		 call	ftp_to_exos		; A=equivalent EXOS error code
		pop	hl			; HL=FTP response code
;
		bit	vars.trace.ftp,(iy+vars._trace)
		ret	z
;
		push	af			; Save EXOS error & NC
		push	de			; Save ->response code
		 push	hl			; Save response code
		   ld	de,trace.ftp.code		;      "Rx code="
		   call	trace			; "FTPn:"
		 pop	hl			; HL=response code
;
		 push	hl			; Save response code again
		  call	io.int			; Print it
		  call	io.crlf
		 pop	hl			; HL=response code
		pop	de			; DE->buffer
		pop	af			; A=EXOS error, F=NC
;
		ret
;
;
;------------------------------------------------------------------------------
; open_data
;
; opens and reads a FTP data channel
;
open_data:	call	send_pasv	; First get PASV parameters
		ret	c
;
		xor	a		; Socket 0
		ld	hl,4242h	; Our port number, any?
		ld	de,owner_data_str
		call	tcp.open
		ret	c
;
		xor	a		; Socket 0
		ld	hl,(vars.ftp.data_port)
		ld	de,vars.ftp.data_ip
		call	tcp.connect
		ret	nc
;
		xor	a
		call	tcp.close
		scf
		ret
;
;
;------------------------------------------------------------------------------
; read
;
; reads from an FTP socket into a buffer
; The caller must call socket.read_end afterwards
;
; In:  A=socket number
; Out: Cy=>timeout waiting for data
;      HL->data read
;      BC=size of data
read:
		ld	hl,(vars.ticks)
		ld	(vars.ftp.start),hl
;
.loop:
		push	af			; Save socket number
		 call	tcp.header		; Packet received?
		 jr	nz,.readit		; Go & read it if yes
;
		pop	af			; A=socket number
		push	af			; Save socket number
		 call	socket.is_closed	; Check socket not closed
		 jr	nz,.notclosed		; Go if ok
;
		pop	af			; Drop saved socket number
		scf
		ret
;
.notclosed:
		call	status.waiting		; Flash status indicator
;
		pop	af			; A=socket number
		call	exos.is_stop
		ret	c
;
		ld	hl,(vars.ticks)
		ld	bc,(vars.ftp.start)
		or	a
		sbc	hl,bc			; HL=duration in ticks
		ld	bc,TICKS_1m		; 1 minute timeout
		or	a
		sbc	hl,bc
		jr	c,.loop
;
		scf				; Timed out
		ret
;
.readit:	pop	af			; A=socket number
;
		ld	c,l
		ld	b,h			; BC=response size
		ld	hl,vars.ftp.buffer_size-2; See if it will fit in buffer
		or	a
		sbc	hl,bc
		jr	nc,.doread		; Go if it will fit in buffer
;
		ld	bc,vars.ftp.buffer_size-2; Else limit to buffer size
.doread:	ld	hl,vars.ftp.buffer
		push	hl			; Save start of buffer
		push	bc			; Save response size
		 call	socket.read		; Read response
		pop	bc			; BC=size of response
		pop	hl			; HL->response
;
		or	a			; No error
		ret
;
;
;------------------------------------------------------------------------------
; read_code
;
; Finds the response/error number at the beginning of the line in an
; FTP response. We don't just find the first one - if there is more than one
; line we return the last (ie most recent) one
; In:  HL->FTP response string
; Out: HL=code
;
read_code:
		ld	e,l		; DE->response
		ld	d,h
;
		or	a
		sbc	hl,hl		; HL=0 (last code found)

		; At this point we are at the beginning of the line
.first:		call	util.get_num16
;
		; We've done one line - now find the start of the next
.nextline:	ld	a,(de)		; Get char from response
		inc	de
		or	a
		ret	z		; Ret if end of response
;
		cp	CR		; If it's a CR we've found end of line
		jr	z,.skip
;
		cp	LF		; Ditto LF
		jr	nz,.nextline
;
		; Found first CR or LF, now skip all CRs & LFs
.skip:		ld	a,(de)
		inc	de
		or	a
		ret	z
;
		cp	CR
		jr	z,.skip
;
		cp	LF
		jr	z,.skip
;
		dec	de
		jr	.first		; First non-CRLF = start of line
;
;
;------------------------------------------------------------------------------
; issue_cmd
;
; Sends an ftp command with optional argument from command line
;
; In:  HL->FTP command
;      DE->arg, length byte first, or 0 if none
;      vars.ftp.socket
;
issue_cmd:	push	de		; Save ->arg
		 ld	de,vars.ftp.buffer
		 call	util.copystr	; Copy command string at (HL)
		pop	hl		; HL->arg
		ld	a,h
		or	l
		call	nz,util.copyarg	; Add arg to command string
;
		bit	vars.trace.ftp,(iy+vars._trace)
		jr	z,.notrace
;
		push	de		; Save end of command in buffer
		 ld	de,trace.ftp.tx	;      "Tx "
		 call	trace		; "FTPn:"
;
		 ld	de,vars.ftp.buffer
		 call	io.str		; Print FTP command before CRLF added
		 call	io.crlf
		pop	de		; DE->end of command in buffer
;
.notrace:	ld	hl,crlf_str	; FTP commands end in CRLF
		call	util.copystr

		ld	hl,vars.ftp.buffer
		call	util.strlen	; BC=total length of command, HL->start
;
		ld	a,(vars.ftp.socket)
		push	af
		 call	socket.write
		pop	af
;
		jp	tcp.send
;
crlf_str:	db	CR,LF,0
;
;
;------------------------------------------------------------------------------
; send_pasv
;
; Sends an FTP PASV command and parses the result
;
; Out:  Cy=>error
;       vars.ftp.data_ip and vars.ftp.data_port filled in
;
send_pasv:	ld	hl,pasv_str
		call	issue
		ret	c
;
		ld	de,vars.ftp.buffer+3	; Point passed response code
		call	findnum		; DE->next number in message
		ld	l,e
		ld	h,d		; HL->remaining message
		call	util.strlen	; BC=length of remaining message
		ld	b,c		; B=length of remaing message		
		dec	de		; Pretend to point to length byte
		ld	hl,vars.ftp.data_ip
		call	util.get_ip	; Interpret IP address
		call	findnum		; DE->first number after IP
		call	util.get_num16	; Assume port H for data connection
		ld	a,(de)
		cp	','		; Skip likely separators
		jr	z,.gotsep
		cp	'.'
		jr	z,.gotsep
		cp	' '
		jr	nz,.notsep
;
.gotsep:	push	hl		; Save port num H
		inc	de		; Skip separator
		call	util.get_num16	; HL=port num L
		pop	bc		; BC=port num H
		ld	h,c		; HL=port number
.notsep:	ld	(vars.ftp.data_port),hl
;
		bit	vars.trace.ftp,(iy+vars._trace)
		ret	z
;
		ld	de,trace.ftp.pasv	;      "pasv="
		call	trace			; "FTPn:"
;
		push	hl		; Save port number
		 ld	hl,vars.ftp.data_ip
		 call	io.ip		; Print ip address
		 ld	a,':'
		 call	io.char
		pop	hl
		jp	io.int		; And port no.
;
;
;
findnum:	dec	de
.loop:		inc	de		; Look for first numerical digit
		ld	a,(de)
		or	a
		ret	z
;
		call	util.isdig
		jr	c,.loop
;
		ret			; HL->first digit
;
;
;------------------------------------------------------------------------------
; trace_start
;
; Outputs "FTPn:<str>" at start of trace line
;
; In:  DE->str
;
trace:		call	io.start
		ld	a,'F'
		call	io.char
		ld	a,'T'
		call	io.char
		ld	a,'P'
		call	io.char
		ld	a,(vars.ftp.socket)
		add	a,'0'
		call	io.char
		ld	a,':'
		call	io.char
		jp	io.str
;
;
;==============================================================================
; The following functions are called by the EXOS FTP: device
;
;
; This is the data kept in EXOS channel RAM.
;
; EXOS channel RAM is accessed at (ix-1), (ix-2)...etc so our data here is
; accessed with (ix-1-<item>) eg (ix-1-socket)
;
; socket must be first as some of the generic device code expects it here.
;
		struct	ftp_channel	; Variables in EXOS channel RAM
socket		 byte			; WIZ socket # for this channel
data		 byte			; NZ=>data socket is open
		ends
;
;
;------------------------------------------------------------------------------
; device_open
;
; This is called by the EXOS device open function call
;
; In:  DE->filename, length byte first
;      IX->EXOS channel RAM
;       A=socket number
; Out: A=EXOS error code, Z not necessarily set appropriately
;
device_open:
		ld	hl,retr_str
		jr	opencreate
		
;
;
;------------------------------------------------------------------------------
; device_create
;
; This is called by the EXOS device create function call
; In:   A=socket number (control)
;      DE->filename, length byte first
;      IX->EXOS channel RAM
; Out: A=EXOS error code
;
device_create:
		ld	hl,stor_str

		; Open and create are identical except for the FTP command
		; string
opencreate:
		push	iy
		 ld	iy,vars
;		
		 ld	(vars.ftp.socket),a
		 ld	(ix-1-ftp_channel.data),0; 0=>no data channel open
;
		 call	status.start	; Start activity indicator

		 push	hl		; Save FTP command
		 push	de		; Save ->arg
		  call	open_data	; Open data connection
		 pop	de		; DE->arg
		 pop	hl		; HL->FTP command
		 ld	a,exos.ERR_NOCON
		 jr	c,.ret
;
		 xor	a		; Data channel; socket always 0
		 ld	(ix-1-ftp_channel.socket),a
		 ld	(ix-1-ftp_channel.data),0xff;	; NZ=>data socket open
;
		 call	issue_arg	; Send FTP command, HL=response code
		 ld	a,exos.ERR_TIMEOUT
		 jr	c,.ret
;
		 call	ftp_to_exos
.ret:		 push	af
	 	  call	status.stop	; Stop activity indicator
		 pop	af
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; device_close
;
; This is called by the EXOS device close function call
;
; In:   A=socket number (control)
;      IX->EXOS channel RAM
; Out: A=EXOS error code
;
device_close:
		push	iy
		 ld	iy,vars
;		
		 ld	(vars.ftp.socket),a
;
		 call	status.start	; Start activity indicator

		 xor	a
		 bit	0,(ix-1-ftp_channel.data);
		 call	nz,tcp.close	; Close data socket (socket = 0)
;
		 ld	(ix-1-ftp_channel.data),0; Not open now
;
		 call	is_response	; Read any final reponse to RETR/STOR

	 	 call	status.stop	; Stop activity indicator

		 xor	a		; No error
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; device_read_byte
;
; This is called by the EXOS device read_byte function call
;
; In:   A=socket number (control)
;      IX->EXOS channel RAM
; Out:  B=byte
;       A=EXOS error code
;
device_read_byte:
		push	iy
		 ld	iy,vars
;
; POKE 'd'
; POKE 'c'
 
		 ld	(vars.ftp.socket),a
;
		 call	status.start		; Start activity indicator
;
		 ld	de,vars.device.byte	; 1 byte buffer
		 ld	bc,1
		 xor	a			; Socket 0 for data
		 call	tcp.read_block		; Read 1 byte
		 ld	b,(iy+vars.device._byte)	; Return 1 byte in B
; POKE '='
; POKEBYTE b
		 push	af
	 	  call	status.stop		; Stop activity indicator
		 pop	af

		 jr	read_ret
;		
;
;------------------------------------------------------------------------------
; device_read_block
;
; This is called by the EXOS device read_block function call
;
; In:   A=socket number (control)
;      IX->EXOS channel RAM
;      DE->user's buffer
;      BC=byte count
; Out: A=EXOS error code
;
device_read_block:
		push	iy
		 ld	iy,vars
;
; POKE 'd'
; POKE 'b'
; POKEBYTE d
; POKEBYTE e
; POKE '('
; POKEBYTE b
; POKEBYTE c
; POKE ')'
		 ld	(vars.ftp.socket),a
		 ld	hl,tcp.read_block
		 call	device.block
;
read_ret:	pop	iy
		ret	nc
;
; POKE '!'
; POKEBYTE a
		sub	2
		ld	a,exos.ERR_EOF
		ret	m		; Code 1=>socket closed
;
		ld	a,exos.ERR_STOP
		ret	z		; Code 2=>STOP pressed
;
		ld	a,exos.ERR_TIMEOUT; Code 3=>timeout
		ret
;
;
;------------------------------------------------------------------------------
; device_write_byte
;
; This is called by the EXOS device write_byte function call
;
; In:   A=socket number (control)
;       B=byte
;      IX->EXOS channel RAM
; Out: A=EXOS error code
;
device_write_byte:
		push	iy
		 ld	iy,vars
;
		 ld	(vars.ftp.socket),a
;
		 call	status.start	; Start activity indicator
;
		 ld	de,vars.device.byte	; 1 byte buffer
		 ld	a,b
		 ld	(de),a
		 ld	bc,1
		 xor	a			; Socket 0 for data
		 call	tcp.write_block		; Write 1 byte
		 sbc	a,a			; Cy->FF, NC->0
		 and	exos.ERR_TIMEOUT	; Cy->error code, 0 if no error
;
		 push	af
	 	  call	status.stop		; Stop activity indicator
		 pop	af
		pop	iy
		ret
;		
;
;------------------------------------------------------------------------------
; device_write_block
;
; This is called by the EXOS device write_block function call
;
; In:   A=socket number (control)
;      IX->EXOS channel RAM
; Out: A=EXOS error code
;
device_write_block:
		push	iy
		 ld	iy,vars
;
		 ld	(vars.ftp.socket),a
		 ld	hl,tcp.write_block
		 call	device.block
		 sbc	a,a			; Cy->FF, NC->0
		 and	exos.ERR_TIMEOUT	; Cy->error code, 0 if no error
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; device_status
;
; This is called by the EXOS device get_read_status function call
;
; In:  A=socket number (control)
;     IX->EXOS channel RAM
; Out: A=EXOS error code
;      C=0=>byte ready, FF=>end of file, 1 otherwise
;
device_status:
		push	iy
		 ld	iy,vars
;
		 ld	(vars.ftp.socket),a
;
		 xor	a		; Data socket 0
		 call	tcp.status
		 ld	c,a
		 sbc	a,a
		 and	exos.ERR_TIMEOUT
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; ftp_to_exos
;
; Converts FTP response/error codes to EXOS error codes
;
; In:  HL=FTP response code
; Out:  A=EXOS error code if fatal, else 0
;      Cy set if A <> 0
;
ftp_to_exos:	ld	c,l
		ld	b,h		; BC=FTP response code
		ld	hl,responses
.loop:		ld	e,(hl)
		inc	hl
		ld	d,(hl)		; DE=response code form table
		inc	hl
		ld	a,(hl)		; A=equivalent EXOS code
		inc	hl
		or	a
		jr	z,.notintable	; Go with NC if end of table
;
		ex	de,hl		; DE->table, HL=response code from table
		or	a
		sbc	hl,bc		; Found matching response?
		scf
		ret	z		; Ret with EXOS code in A if yes
;
		ex	de,hl		; HL->table
		jr	.loop		; Try next entry
;
.notintable:				; NC here
		ld	hl,399		; >=400 are generally fatal
		sbc	hl,bc
		ld	a,exos.ERR_FTP
		ret	c		; Return with EXOS error if >=400
;
		xor	a		; Else no EXOS error
		ret
;
responses:	dw	550
		db	exos.ERR_NOFIL
;
		dw	0
		db	0
;
;
;------------------------------------------------------------------------------
; FTP commands that are sent
;
cwd_str:	db	"CWD ",0
pwd_str:	db	"PWD",0
cdup_str:	db	"CDUP",0
mkd_str:	db	"MKD ",0
rmd_str:	db	"RMD ",0
dele_str:	db	"DELE ",0
rnfr_str:	db	"RNFR ",0
rnto_str:	db	"RNTO ",0
user_str:	db	"USER ",0
pass_str:	db	"PASS ",0
pasv_str:	db	"PASV",0
list_str:	db	"LIST ",0
retr_str:	db	"RETR ",0
stor_str:	db	"STOR ",0
syst_str:	db	"SYST",0
quit_str:	db	"QUIT",0
;
;
owner_str:	db	"FTP",0
owner_data_str:	db	"DATA",0
;
;
;
		endmodule
