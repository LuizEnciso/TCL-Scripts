package require sqlite3

namespace eval bncadmin {
    variable database "./bncadmin.db"

    variable dbpeak   "./peak.db"

    variable channel  "#IRC"

    variable url      "http://www.bncgratis.com"

    variable email    "bnc-request@bncgratis.com"

    bind pub - "!request"   bncadmin::request
    bind pub - "!reqinfo"   bncadmin::reqinfo
    bind pub - "!check"     bncadmin::check
    bind pub - "!emailreq"  bncadmin::emailreq

    bind msg - "!activate"  bncadmin::activate

    set randomanswers {
        {Procesando...}
        {Espera un momento...}
        {Notificando a Luiz}
    }

    setudef flag bncadmin
}

proc bncadmin::request { nick uhost hand chan text } {
    set username [lindex $text 0]
    set address  [lindex $text 1]
    set email    [lindex $text 2]

    if {$email == ""} {
        puthelp "PRIVMSG $chan :Sintaxis: \002$::lastbind usuario direccion.servidor tu-correo\002"
        puthelp "PRIVMSG $chan :\0021 BNC por red IRC\002, en total 4 permititdas. Para mas informacion: \002!info\002"
        puthelp "PRIVMSG $chan :Para \00312privacidad de correo\003 escribe \002\00312!emailreq\003\002"
        puthelp "PRIVMSG $chan :\0034El abuso del servicio ameritara la suspension del servicio\003"
        return
    }
    set now [clock seconds]
    bncadmin::adduser $username $email $address $now
    puthelp "PRIVMSG $chan :\00312Esta solicitud ha sido logueada\003 y esta a la espera de la revision de un miembro del staff. Escribe,"
    puthelp "PRIVMSG $chan :\002!check $username\002 para verificar el estado de tu solicitud. \0034Si deseas cancelar tu solicitud\003,"
    puthelp "PRIVMSG $chan :escribe, \002!cancel\002"
}

proc bncadmin::reqinfo { nick uhost hand chan text } {
    puthelp "PRIVMSG $chan :\0037INFO\003 - \002Limite\002: 1 BNC por red IRC, 4 en total por usuario. No solicites por otros, ellos necesitan hacer su propia solicitud."
}

proc bncadmin::check { nick uhost hand chan text } {
    set username [lindex $text 0]
    if {$username == ""} {
        puthelp "PRIVMSG $chan :.!."
        return 0
    }
    puthelp "PRIVMSG $chan :\002$username:\002 Esta solicitud esta a la espera de ser procesada. Info de la solicitud, \002server\002 VarServer \002email:\002 varMail"
    puthelp "PRIVMSG $chan :Si algun campo es incorrecto, por favor escribe \002!cancel\002"
}

proc bncadmin::emailreq { nick uhost hand chan text } {
    puthelp "PRIVMSG $chan :Si no quieres mostrar tu correo en publico, envia tu solicitud al correo \00312$bncadmin::email\003 adjuntando la siguiente informacion:"
    puthelp "PRIVMSG $chan :nombre de usuario y direccion del servidor irc. \0034Recuerda:\003 Las solicitudes enviadas por email pueden tardar mas."
}

proc bncadmin::activate { nick uhost hand text } {
    set username [lindex $text 0]
    set email "a"

    if {$username == ""} {
        puthelp "PRIVMSG $nick :Sintaxis: \002!activar cuenta\002"
    }
    puthelp "PRIVMSG $nick :La cuenta: $username ha sido activada."
    puthelp "PRIVMSG $nick :Los datos han sido enviados por correo a la direccion: $email"
    puthelp "PRIVMSG $bncadmin::channel :\0033Solicitud ACEPTADA\003 usuario: \002$username\002 - red: \002$network\002 - agregado por: \002$bcnadmin\002."
    puthelp "PRIVMSG $bncadmin::channel :La informacion de la cuenta ha sido enviada por email al correo con el que se hizo la solicitud."
}

############## TAREAS BASE DE DATOS ################

proc bncadmin::adduser {username email server regtime} {
    sqlite3 bdb $bncadmin::database
    bdb eval {INSERT INTO bncusers (username, email, server, regtime, status) VALUES ($username,$email,$server,$regtime,0)}
    bdb close
}

if {![file exists $bncadmin::database]} {
    sqlite3 bdb $bncadmin::database

    bdb eval {CREATE TABLE bncusers (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL COLLATE NOCASE, email TEXT NOT NULL COLLATE NOCASE,
                                    server TEXT NOT NULL COLLATE NOCASE, network TEXT NOT NULL COLLATE NOCASE, regtime INTEGER NOT NULL,
                                    status INTEGER NOT NULL, bncadmin TEXT, blockmsg TEXT)}
    bdb close
}

putlog "\002BNC Admin - Loaded\002"
