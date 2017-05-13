
package require sqlite3

namespace eval ::helper {
    variable database    "./helper.db"
	variable opers_help  "#Test-"
	variable opers_notif "#IRC-Dev"
	variable host_opers  "Turtle.power"
	variable host_admins "admin.irc-dev.es"

    variable scan_chan   5

    bind nick - * ::helper::nick
	bind join - * ::helper::join
    bind part - * ::helper::part
    bind msgm - * ::helper::msgm
    bind pubm - * ::helper::pubm

    variable countopers 0
}

proc ::helper::db_adduser {nick} {
    sqlite3 hdb $helper::database
    if {[llength [hdb eval {SELECT nickname FROM helper WHERE nickname=$nick}]] == 0} {
        set now [clock seconds]
        hdb eval {INSERT INTO helper (nickname,join_time,status) VALUES ($nick,$now,0)}
    }
    hdb close
}

proc ::helper::db_deluser {nick} {
    sqlite3 hdb $helper::database
    hdb eval {DELETE FROM helper WHERE nickname=$nick}
    hdb close

}

proc ::helper::db_modstatus {nick status} {
    sqlite3 hdb $helper::database
    hdb eval {UPDATE helper set status=$status WHERE nickname=$nick}
    hdb close
}

proc ::helper::db_status {nick} {
    sqlite3 hdb $helper::database
    set status [hdb eval {SELECT status FROM helper WHERE nickname=$nick}]
    if {$status == ""} {
        set status -1
    }
    hdb close

    return $status
}

proc ::helper::intromsg {target} {
    puthelp "PRIVMSG $target :Hola, soy el encargado de ponerte en contacto con un OPER. \002Por favor, podrias describirme en una linea el problema?\002"
}

proc ::helper::isoper {uhost} {
    set host [lindex [split $uhost @] 1]
    if {$host == $helper::host_opers} {
        return 1
    }
    return 0
}

proc ::helper::searchoper { chan } {
    set rand [expr int(rand()*$helper::countopers)]
}

proc ::helper:scan_chan {} {
    if {[info exists helper_timerid]} {unset helper_timerid}
    foreach nick [chanlist $helper::opers_help] {
        if {[isbotnick $nick]} { continue }
        if {[matchattr $nick +z]} { continue }
        if {[::helper::db_status $nick] != 3 && [::helper::db_status $nick] != 1} {
            putserv "KICK $helper::opers_help $nick :No puede permanecer dentro del canal."
        }
    }
    set helper_timerid [timer $helper::opers_help ::helper:scan_chan]
}

proc ::helper::nick {nick uhost hand chan newnick} {
    if {$helper::opers_notif == $chan} { return 0 }
    #putserv "KICK $helper::opers_notif $newnick :Si no estas disponible no puedes permanecer en el canal."
}

proc ::helper::join {nick uhost hand chan} {
    if {[isbotnick $nick] && $chan == $helper::opers_notif} {
        foreach user [chanlist $chan] {
            incr helper::countopers
        }
    } else {
        return 0
    }

    if {$helper::opers_notif == $chan} {
        incr helper::countopers
    }
    if {($helper::opers_help == $chan) && (![helper::isoper $uhost])} {
        puthelp "PRIVMSG $helper::opers_notif :El usuario \002$nick!$uhost\002 acaba de entrar en $helper::opers_help"
        ::helper::db_adduser $nick
        if {[::helper::db_status $nick] == 0} {
            ::helper::intromsg $nick
        }
    }
}

proc ::helper::part {nick uhost hand chan text} {
    if {[isbotnick $nick]} {
        return 0
    }
    if {$helper::opers_notif == $chan} {
        if {$helper::countopers == 0} {
            return 0
        }
        set helper::countopers [expr $helper::countopers -1]
    }
    if {$helper::opers_help == $chan} {
        puthelp "PRIVMSG $helper::opers_notif :El usuario \002$nick!$uhost\002 ha salido de $helper::opers_help"
        if {[::helper::db_status $nick] != 3} {
            ::helper::db_deluser $nick
        }
    }
}

proc ::helper::msgm {nick uhost hand text} {
    if {[matchattr $nick +z]} {
        set cmd [lindex $text 0]
        set target [lindex $text 1]
        if {$cmd == "" || $target == ""} {
            puthelp "PRIVMSG $nick :Sintaxis: <comando> <parametros>"
            return 0
        }
        set cmd [string toupper $cmd]
        if {$cmd == "ACEPTA"} {
            ::helper::aceptar $nick $target
        } elseif {$cmd == "FINALIZA"} {
            ::helper::finaliza $nick $target
        } elseif {$cmd == "SPAM"} {
            ::helper::spam $target
        } else {
            puthelp "PRIVMSG $nick :Comando desconocido."
        }
    } else {
        if {![onchan $nick $helper::opers_help]} { return 0 }
        if {$helper::countopers == 0} {
            puthelp "PRIVMSG $nick :Lamentablemente en este momento no hay ningun OPER disponible. Por favor plantea tu duda un poco mas tarde."
            putserv "KICK $nick $nick $helper::opers_help :Por favor, vuelve mas tarde"
            return 0
        }
        if {[::helper::db_status $nick] == 4} {
            puthelp "PRIVMSG $nick :Ya has sido atendido, si deseas hacer otra consulta debes salir y entrar del canal $nick $helper::opers_help"
        } elseif {[::helper::db_status $nick] == 1} {
            puthelp "PRIVMSG $nick :Te rogamos un poco de paciencia. En breve se pondra en contacto contigo un OPER."
        } elseif {[::helper::db_status $nick] == 3} {
            puthelp "PRIVMSG $nick :Tu consulta esta siendo atendida. No se admite mas de una consulta al mismo tiempo."
        } elseif {[::helper::db_status $nick] == -1} {
            putserv "KICK $nick $nick $helper::opers_help :Por favor, vuelve a ingresar."
        } else {
        # Selecciono un oper disponible
        set nickoper "LuizEnciso"
        ::helper::db_modstatus $nick 1
        puthelp "PRIVMSG $nickoper :El usuario $nick solicita ayuda sobre.. $text"
        puthelp "PRIVMSG $nick :Gracias, en breve te informare del nick del OPERador/a que te va a ayudar. Por favor, no abandones el canal mientras eres atendido/a."
        puthelp "PRIVMSG $nickoper :Para aceptar la peticion escribe \002ACEPTA $nick\002."
        puthelp "PRIVMSG $nickoper :Para rechazar la peticion escribe \002RECHAZA $nick <motivo>\002."
        puthelp "PRIVMSG $nickoper :Si se trata de spam molesto o pesad@ de turno, escribe \002SPAM $nick\002"
        }
    }
}

proc ::helper::pubm {nick uhost hand chan text} {
    if {($chan == $helper::opers_help) && (![::helper::isoper $uhost])} {
        putserv "KICK $chan $nick :Por favor, no hables en el general o seras expulsado del canal. Gracias."
    }
}

proc ::helper::aceptar {nick target} {
    if {[::helper::db_status $target] == 3} {
        puthelp "PRIVMSG $nick :El usuario ya se encuentra siendo atendido por un OPERador."
        return 0
    }

    if {[::helper::db_status $target] == 1} {
        ::helper::db_modstatus $target 3
        puthelp "PRIVMSG $helper::opers_notif :El usuario $target ha sido asignado al OPERador $nick"
        puthelp "PRIVMSG $nick :Has aceptado la solicitud de ayuda de $target. Para finalizar escribe: \002FINALIZA $target\002"
        puthelp "PRIVMSG $target :El OPERador $nick se pondra en contacto contigo en breve."
        return 0
    }

    puthelp "PRIVMSG $nick :El usuario $target no ha solicitado tu ayuda!. Te has pensado que eres Teresa de Calcuta? ;-)"
    return 0
}

proc ::helper::finaliza {nick target} {
    if {[::helper::db_status $target] == 0} {
        puthelp "PRIVMSG $nick :El usuario $target no ha solicitado tu ayuda!. Te has pensado que eres Teresa de Calcuta? ;-)"
    } elseif {[::helper::db_status $target] == 1} {
        puthelp "PRIVMSG $nick :Quieres acabar con el antes de haberle atendido? Estas seguro? Has bebido? :P"
    } elseif {[::helper::db_status $target] == 4} {
        puthelp "PRIVMSG $nick :El usuario $target ya ha sido atendido."
    } elseif {[::helper::db_status $target] == 3} {
        ::helper::db_modstatus $target 4
        puthelp "PRIVMSG $helper::opers_notif :El usuario $target ha terminado de ser atendido por \002$nick\002"
        puthelp "PRIVMSG $nick :Se ha finalizado la session con $target."
        puthelp "PRIVMSG $target :El OPERador que te estaba atendiendo ha dado por resulelta tu consulta, por favor abandona el canal."
    } else {
        return 0
    }
}

proc ::helper::spam {target} {
}


if {![file exists $helper::database]} {
    sqlite3 hdb $helper::database

    hdb eval {CREATE TABLE helper (id INTEGER PRIMARY KEY AUTOINCREMENT, nickname TEXT NOT NULL COLLATE NOCASE, join_time INTEGER NOT NULL, status INTEGER NOT NULL)}
    hdb close
}

putlog "\002Helper Script - Loaded\002"
