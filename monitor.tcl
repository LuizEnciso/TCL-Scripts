###############################################################################################
#
# DESCRIPCION DE DIRECTIVAS DE CONFIGURACION:
#
# channel - Nombre del canal donde el bot notificara los eventos.
# owner   - Administrador del bot.
#
# badnicks - Lista de nicks prohibidos
# badnicks_enable - Con 1 habilita la restricion de nicks para desactivar poner 0
# badnicks_kickreason - Mensaje de expulsion en nicks prohibidos.
#
# badwords - Lista de palabras phohibidas
# badwords_enable - Con 1 habilita la proteccion de palabras prohibidas para desactivar poner 0
# badwords_kickreason - Mensaje de expulsion en palabras prohibidas.
#
###############################################################################################

namespace eval monitor {

    variable channel  "#IRC"

    variable owner "Kalibre"

    set badnicks {
        "emiliostuff"
        "emilio"
    }
    variable badnicks_enable 1
    variable badnicks_kickreason "Nick no permitido."

    set badwords {
        "subefotos.com"
        "facebook.com/profile"
    }
    variable badwords_enable 1
    variable badwords_kickreason "Fuera pedofilo alcoholico."

    ############# NO TOCAR DE AQUI EN ADELANTE ##################

    bind part - * monitor::part
    bind join - * monitor::join
    bind nick - * monitor::nick
    bind kick - * monitor::kick
    bind mode - * monitor::mode
    bind sign - * monitor::quit

    bind pubm - * monitor::pubm
    bind msgm - * monitor::msgm
}

proc msg { target text } {
    putserv "PRIVMSG $target :$text"
}

proc kickban { chan nick uhost reason duration } {
    newchanban $chan [maskhost *!$uhost 2] $::botnick $reason $duration
    putserv "KICK $chan $nick :$reason"
}

proc monitor::part { nick uhost hand chan text } {
    if {[isbotnick $nick] || $chan == $monitor::channel} {
        return 0
    }
    msg $monitor::channel "\0034$nick\003 se retira del canal \002$chan\002"
}

proc monitor::join { nick uhost hand chan } {
    if {[isbotnick $nick] || $chan == $monitor::channel} {
        return 0
    }
    msg $monitor::channel "\0033$nick\003 ingresa al canal \002$chan\002"
    if {$monitor::badnicks_enable == 1} {
        foreach badnick [string tolower $monitor::badnicks] {
            if {([string match -nocase *$badnick* $nick])} {
                if {[botisop $chan]} {
                    kickban $chan $nick $uhost $::botnick $monitor::badnicks_kickreason 60
                    msg $monitor::channel "\00312\[BADNICK\]\003 \0034$nick\003 ha sido expulsado del canal \002$chan\002"
                }
            }
        }
        return 0
    }
}

proc monitor::nick { nick uhost hand chan newnick } {
    if {[isbotnick $nick] || $chan == $monitor::channel} {
        return 0
    }
    msg $monitor::channel "\00312$nick\003 se cambia de nick a \0034$newnick\003"
    if {$monitor::badnicks_enable == 1} {
        foreach badnick [string tolower $monitor::badnicks] {
            if {([string match -nocase *$badnick* $newnick])} {
                if {[botisop $chan]} {
                    kickban $chan $nick $uhost $monitor::badnicks_kickreason 60
                    msg $monitor::channel "\00312\[BADNICK\]\003 \0034$newnick\003 ha sido expulsado del canal \002$chan\002"
                }
            }
        }
    }
}

proc monitor::kick { nick uhost hand chan target text } {
    if {[isbotnick $nick] || $chan == $monitor::channel} {
        return 0
    }
    msg $monitor::channel "\0034$target\003 ha sido expulsado de \002$chan\002 por \00312$target\003 (motivo: $text)"
}

proc monitor::mode { nick uhost hand chan modes target } {
    if {$chan == $monitor::channel} {
        return 0
    }
    if { $target == "" } {
        msg $monitor::channel "\00312$nick\003 cambia los modos de \002$chan\002 a \00312$modes\003"
    } else {
        if {$modes == "+b"} {
            if {$nick != $::botnick} {
                msg $monitor::channel "\0034\[BAN\]\003 \002$nick\002 ha establecido el siguiente ban (\0032$target\003) en \00312$chan\003"
            }
        } elseif {$modes == "-b"} {
            if {$nick != $::botnick} {
                msg $monitor::channel "\0036\[UNBAN\]\003 \002$nick\002 ha retirado el siguiente ban (\0032$target\003) en \00312$chan\003"
            }
        } else {
            msg $monitor::channel "\00312$nick\003 modifica los modos de \0034$target\003 en \002$chan\002 (\00312$modes\003)"
        }
    }
}

proc monitor::quit { nick uhost hand chan text } {
    if {[isbotnick $nick] || $chan == $monitor::channel} {
        return 0
    }
    msg $monitor::channel "\0034$nick\003 se ha desconectado de la red ($text)"
}

proc monitor::pubm { nick uhost hand chan text } {
    if {[isbotnick $nick] || $chan == $monitor::channel} {
        return 0
    }

    if {$monitor::badwords_enable == 1} {
        foreach badword [string tolower $monitor::badwords] {
            if {([string match -nocase *$badword* $text])} {
                if {[botisop $chan]} {
                    kickban $chan $nick $uhost $monitor::badwords_kickreason 60
                    msg $monitor::channel "\00312\[BADWORD\]\003 \0034$nick\003 ha sido expulsado del canal \00312$chan\003 (coincidencia: $badword)"
                }
            }
        }
    }
}

proc monitor::msgm { nick uhost hand text } {
    if {[isbotnick $nick] || $nick != $monitor::owner} {
        return 0
    }
    set cmd [lindex $text 0]
    set param [lindex $text 1]
    set cmd [string toupper $cmd]

    if {$cmd == "HELP"} {
        msg $nick "Comandos disponibles de \002$::botnick\002"
        msg $nick " "
        msg $nick "\00312MONITOR\003 - Agrega un canal la lista de canales monitoreados."
        msg $nick "\00312UNMONITOR\003 - Remueve un canal de la lista de canales monitoreados."
        msg $nick "\00312RELOAD\003 - Recarga la configuracion del bot."
        msg $nick "\00312CHANNELS\003 - Lista de canales monitoreados."
        msg $nick " "
        msg $nick "\002FIN de la Ayuda\002"
    } elseif {$cmd == "RELOAD"} {
         msg $nick "Ok, recargando configuracion."
         rehash
    } elseif {$cmd == "MONITOR"} {
        if {$param == ""} {
            msg $nick "\002Sintaxis:\002 \00312MONITOR #canal\003"
        } else {
            msg $nick "Ingresando a \002$param\002..."
            channel add $param
        }
    } elseif {$cmd == "UNMONITOR"} {
        if {$param == ""} {
            msg $nick "\002Sintaxis:\002 \00312UNMONITOR #canal\003"
        } else {
            msg $nick "Saliendo de \002$param\002..."
            channel remove $param
        }
    } elseif {$cmd == "CHANNELS"} {
        set i 0
        msg $nick "Lista de Canales Monitoreados:"
        foreach c [channels] {
            if {$c != $monitor::channel} {
                msg $nick $c
                incr i
            }
        }
        msg $nick "Total de canales: \002$i\002"
    } else {
        msg $nick "Comando Desconocido."
    }
}

putlog "\002Monitor TCL v1.0 - Loaded (Comandos: HELP RELOAD MONITOR UNMONITOR CHANNELS).\002"
