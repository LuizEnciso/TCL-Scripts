namespace eval networktools {
    variable channel "#IRC-Dev"
    variable ipzarate "200.1.177.23"
    variable ipctorey "200.1.177.24"

    bind pub - ".status" networktools::ping
    bind pub - ".resolv" networktools::resolv
}

proc networktools::resolv {nick uhost hand chan text} {
    if {$nick != "LuizEnciso"} {
        return 0
    }
    set hostname [lindex $text 0]
    if {$hostname == ""} { return 0 }
    dnslookup $hostname networktools::resolvdisplay
    return 0
}

proc networktools::resolvdisplay {ip hostname status} {
    puthelp "PRIVMSG $::networktools::channel :IP Resuelta para \002$hostname\002 es  \002$ip\002";
    return 0
}

proc networktools::ping {nick uhost hand chan text} {

    if {$nick != "LuizEnciso"} {
        return 0
    }

    set token [http::geturl http://200.1.177.24/doc/page/main.asp]
    


    if {$pingzarate > 0} {
        putserv "PRIVMSG $chan :\002Zarate\002: \0033UP\003";
    } else {
        putserv "PRIVMSG $chan :\002Zarate\002: \0034DOWN\003";
    }

    if {$pingctorey > 0} {
        putserv "PRIVMSG $chan :\002Wisse\002: \0033UP\003";
    } else {
        putserv "PRIVMSG $chan :\002Wisse\002: \0034DOWN\003";
    }
}
