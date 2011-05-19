#  Author: Dan Stephenson
#  Date: 09/08/2005
#  Filename: sms.tcl
#  Function: Eggdrop interface to clickatell's HTTP/S SMS Gateway
#
#  Version: 1.1 *BeTA
#  History: 
#       - 09/08/2005: First Coded
#       - 16/06/2006: Added sms.dat for data handling
#                     Added !smsadd, !smsver, !smshelp
#                     tag and nick info to sms & chan work flag
#
#  Notes: Enable with .chanset #channel +sms

# packages

package require http

# vars

# script version
set smsver "1.1 *BeTA"

# work chan flags ..
setudef flag sms

# tag bottom of sms with irc nick and tagmsg ... 0=no 1=yes
set tagnick "1"
set tagname "1"
set tagmsg "irc.server.net"

# datafile
set datfile "scripts/sms.dat"

# clickatell details
set user "username"
set pass "password"
set id "clickatell_id_number"


# shouldnt need to edit these urls below, but can be edited if clickatell change their
# url structure, or if you wish to attempt to adapt script to another sms gateway 

set urlcreds "http://api.clickatell.com/http/getbalance?api_id=SMSID&user=SMSUSER&password=SMSPASS"
set url "http://api.clickatell.com/http/sendmsg?api_id=SMSID&user=SMSUSER&password=SMSPASS&to=NUMTOSEND&text=MSGTOSEND"


########## DO NOT EDIT BELOW UNLESS YOU KNOW TCL! ##########

# binds

namespace eval sms {
    variable pubsmsadd {!smsadd}
    variable pubbalbind {!smscreds}
    variable pubnumbind {!number}
    variable pubverbind {!smsver}
    variable pubhelpbind {!smshelp}
    variable pubbind {!sms}
    bind PUB o|o $pubsmsadd [namespace current]::smsadd 
    bind PUB o|o $pubnumbind [namespace current]::number
    bind PUB -|- $pubbalbind [namespace current]::credspublic
    bind PUB -|- $pubverbind [namespace current]::smsver
    bind PUB -|- $pubhelpbind [namespace current]::smshelp
    bind PUB -|- $pubbind [namespace current]::public
    namespace export getnames credspublic public private
}


proc sms::smsadd {nickname hostname handle channel arguments} {
    global chan datfile

    if ![channel get $channel sms] return

    set args [split $arguments]
    set data ""

    # check args are correct
    if {($arguments < 1) || ([llength $args] < 2)} {
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Format:\002 !smsadd <name> <number>"
        return 0
    }

    # check if names already added
    if {[validfeed [lindex $args 0] 1]} {
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Error:\002 User already exists!"
        return 0
    }

    # make sure no letters in sms number
    if {![ string is digit [lindex $args 1] ] } {
        putquick "PRIVMSG $channel : [lindex $args 1]"
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Error:\002 letters detected in <number> entry"
        return 0
    }

    # Complain and exit if input file does not exist
    if {![ file exists $datfile ] }  	{
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Error: \002File \"$datfile\" not found!"
        return 0
    }

    # Complain and exit if input file is not readable
    if {![ file readable $datfile ] }  	{
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Error:\002 Permission denied to read $datfile!"
        return 0
    }


   # save sms data
    if { [ catch { set fileId [open $datfile a] } err ] }  {
        putquick "PRIVMSG $channel :\[\002SMS\017\] Error:\002 $err"
        return 0
    }

    puts $fileId [lindex $args 0]:[lindex $args 1]
    close $fileId

    putquick "PRIVMSG $channel :\[\002SMS\017\] \002Added:\002 Name: [lindex $args 0] Number: [lindex $args 1]"
}


proc sms::public {nickname hostname handle channel arguments} {
    global tagnick tagname tagmsg url urlcreds user pass id
    variable token
    set args [split $arguments]

    if ![channel get $channel sms] return

    if {($arguments < 1) || ([llength $args] < 2)} {
        putquick "PRIVMSG $channel :\002Format:\002 !sms <name> <message>"
        putquick "PRIVMSG $channel :."
        putquick "PRIVMSG $channel :Available entries:"
        putquick "PRIVMSG $channel :[getnames]"
        return 0
    }

    if {![validfeed [lindex $args 0] 1]} {             
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Error:\002 please choose one of the following names: "
        putquick "PRIVMSG $channel :[getnames]"
        return 0
    }

    set nick [lindex $args 0]
    set number "0"
    set number [getnumber $nick]

    if {($nick == "") || ($number == "0")} {
        putlog "RSS: Warning: Couldn't load configuration for the \[$id\] feed."
        putquick "PRIVMSG $channel :\002Error:\002 couldnt get number for that user."
        return 0
    }

    set arguments [lreplace $args 0 0]

    #add tag and nick - if set in config above
    if {$tagnick eq "1"} {  
        set arguments "$arguments %5b $handle %2f $channel %5d"
    }
    if {$tagname eq "1"} {
        set arguments "$arguments %5b $tagmsg %5d"
    }

    # regsub some common irc chars for unicode
    regsub -all " " $arguments "%20" arguments
    regsub -all "#" $arguments "%23" arguments 
    regsub -all "&" $arguments "%26" arguments 
    regsub -all "@" $arguments "%40" arguments

    # regsub details into sms url
    set realurl $url
    regsub -all NUMTOSEND $realurl $number realurl
    regsub -all MSGTOSEND $realurl $arguments realurl
    regsub -all SMSID $realurl $id realurl
    regsub -all SMSUSER $realurl $user realurl
    regsub -all SMSPASS $realurl $pass realurl

    # regsub details into urlcreds url
    set realurlcreds $urlcreds
    regsub -all SMSID $realurlcreds $id realurlcreds
    regsub -all SMSUSER $realurlcreds $user realurlcreds
    regsub -all SMSPASS $realurlcreds $pass realurlcreds

    set token [http::geturl $realurl]
    set data_frm_url [http::data $token]

    putquick "PRIVMSG $channel :\002Sent:\002 $arguments"
    putquick "PRIVMSG $channel :\002To:\002 [lindex $args 0] ($number)"
    putquick "PRIVMSG $channel :\002Response:\002 $data_frm_url"

    set token [http::geturl $realurlcreds]
    set bal_frm_url [http::data $token]

    putquick "PRIVMSG $channel :\002Credits:\002 $bal_frm_url"
}

proc sms::number {nickname hostname handle channel arguments} {
    global chan datfile
    set args [split $arguments]

    if ![channel get $channel sms] return

    if {($arguments < 1) || ([llength $args] < 1)} {
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Format:\002 !number <name>"
        putquick "PRIVMSG $channel :."
        putquick "PRIVMSG $channel :Available entries:"
        putquick "PRIVMSG $channel :[getnames]"
        return 0
    }

    if {![validfeed [lindex $args 0] 1]} {
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Error:\002 please choose one of the following names: "
        putquick "PRIVMSG $channel :[getnames]"
        return 0
    }
    
    set nick [lindex $args 0]
    set number "0"
    set number [getnumber $nick]

    if {($nick == "") || ($number == "0")} {
        putlog "RSS: Warning: Couldn't load configuration for the \[$id\] feed."
        putquick "PRIVMSG $channel :\002Error:\002 couldnt get number for that user."
        return 0
    }

    putquick "PRIVMSG $channel :\[\002SMS\017\] \002[lindex $args 0]:\002 $number"
}


proc sms::validfeed {keyword type} {
    global datfile

    # Complain and exit if file does not exist
    if {![ file exists $datfile ] }     {
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Error: \002File \"$datfile\" not found!"
        return 0
    }

    # Complain and exit if file is not readable
    if {![ file readable $datfile ] }   {
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Error:\002 Permission denied to read $datfile!"
        return 0
    }

    # read sms data
    if { [ catch { set fileId [open $datfile r] } err ] }  {
        putquick "PRIVMSG $channel :\[\002SMS\017\] Error:\002 $err"
        return 0
    }

    set names [list]
    while {![eof $fileId]} {
        set line [gets $fileId]
        set data [split $line ":"]
        if {$data != ""} {        
            lappend names [lindex $data 0]
        }
    }
    close $fileId

    foreach id $names {
        if {[string equal -nocase $id $keyword]} {
            switch -exact -- $type {
                {1} { return 1 }
                {2} { return $id }
            }
        }
    }
    return 0
}


proc sms::getnames { } {
    global datfile

    # Complain and exit if file does not exist
    if {![ file exists $datfile ] }     {
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Error: \002File \"$datfile\" not found!"
        return 0
    }

    # Complain and exit if file is not readable
    if {![ file readable $datfile ] }   {
        putquick "PRIVMSG $channel :\[\002SMS\017\] \002Error:\002 Permission denied to read $datfile!"
        return 0
    }

    # read sms data
    if { [ catch { set fileId [open $datfile r] } err ] }  {
        putquick "PRIVMSG $channel :\[\002SMS\017\] Error:\002 $err"
        return 0
    }

    set names [list]
    while {![eof $fileId]} {
        set line [gets $fileId]
        set data [split $line ":"]
        if {$data != ""} {
            lappend names [lindex $data 0]
        }
    }
    close $fileId

    return $names
}


proc sms::getnumber {smsname} {
    global datfile
    set smsnum ""

    # read sms data
    if { [ catch { set fileId [open $datfile r] } err ] }  {
        putquick "PRIVMSG $channel :\[\002SMS\017\] Error:\002 $err"
        return 0
    }

    set names [list]
    while {![eof $fileId]} {
        set line [gets $fileId]
        set data [split $line ":"]
        if {$data != ""} {
            if {$smsname eq [lindex $data 0]} {
                set smsnum [lindex $data 1]
            }
        }
    }
    close $fileId

    return $smsnum
}


proc sms::smsver {nickname hostname handle channel arguments} {
    global smsver

    if ![channel get $channel sms] return

    putquick "PRIVMSG $channel :\[\002SMS\017\] ver. $smsver"
    putquick "PRIVMSG $channel :\002(C) 2005 EToS"
}

proc sms::credspublic {nickname hostname handle channel arguments} {
    global chan urlcreds user pass id

    if ![channel get $channel sms] return

    # regsub details into urlcreds url
    set realurlcreds $urlcreds
    regsub -all SMSID $realurlcreds $id realurlcreds
    regsub -all SMSUSER $realurlcreds $user realurlcreds
    regsub -all SMSPASS $realurlcreds $pass realurlcreds

    set token [http::geturl $realurlcreds]
    set bal_frm_url [http::data $token]

    putquick "PRIVMSG $channel :\[\002SMS\017\] \002Credits:\002 $bal_frm_url"
}

proc sms::smshelp {nickname hostname handle channel arguments} {
    global chan

    if ![channel get $channel sms] return

    putquick "PRIVMSG $channel :\[\002SMS\017\] \002CMDS HELP!:\017"
    putquick "PRIVMSG $channel : !sms <name> <message> - send a txt msg"
    putquick "PRIVMSG $channel : !number <name> - view a users number, ops only cmd"
    putquick "PRIVMSG $channel : !smscreds -  view credits on account"
    putquick "PRIVMSG $channel : !smsadd <name> <number> - ops only"
    putquick "PRIVMSG $channel : !smsdel - not implemented \(deliberately\)"
    putquick "PRIVMSG $channel : !smsver - version info"
    putquick "PRIVMSG $channel : !smshelp - err your here!"
}

putlog "Script loaded: SMS v1.1 \00302\002(C) 2005 EToS"
