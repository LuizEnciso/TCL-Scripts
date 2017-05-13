package require sqlite3

namespace eval shelladmin {
    variable database "./shelladmin.db"

    variable dbpeak   "./peak.db"

    variable channel  "#IRC-Dev"

    variable url      "http://www.shells.com"

    variable hours_use    336

    bind pub - "!activar" shelladmin::aprobar
    bind pub - "!renovar" shelladmin:keep
    bind pub - "!info"    shelladmin::info

    bind pub m "!reg"     shelladmin::reg
    bind pub m "!ban"     shelladmin::banacc

    bind pub - "!help"    shelladmin::help
    bind pub - "!peak"    shelladmin::peak

    bind pub m "!uptime"  shelladmin:uptime

    bind join - *         shelladmin::join

    set randomanswers {
        {Procesando...}
        {Espera un momento...}
        {Notificando a Luiz}
    }

    setudef flag shelladmin
}

proc shelladmin::aprobar { nick uhost hand chan text } {

    if {![channel get $chan shelladmin]} { return 0 }

    set accountid [lindex $text 0]

    if {$accountid == ""} {
        puthelp "PRIVMSG $chan :$nick, escribe: $::lastbind \002cuenta\002"
        return 0
    }

    if {![shelladmin::findaccount $accountid]} {
        puthelp "PRIVMSG $chan :$nick, necesitas registrar una cuenta en la web."
    } elseif {[shelladmin::statusaccount $accountid] == 1} {
        puthelp "PRIVMSG $chan :$nick, tu cuenta ya se encuentra activada."
    } elseif {[shelladmin::statusaccount $accountid] == 2} {
        puthelp "PRIVMSG $chan :$nick, espera! parece que \002$accountid\002 hizo algunas cosas malas, como actividades ilegales (AutoBan)"
    }  else {
        puthelp "PRIVMSG $chan :[lindex $shelladmin::randomanswers [rand [llength $shelladmin::randomanswers]]]"
        puthelp "PRIVMSG $chan :Configurando cuenta..."
        puthelp "PRIVMSG $chan :$nick, tu cuenta ha sido aprobada y activada , visita $shelladmin::url para"
        puthelp "PRIVMSG $chan :mas informacion acerca de tu cuenta y de como acceder a ella."
        puthelp "PRIVMSG $chan :Tu cuenta expirara en $shelladmin::hours_use horas a menos que regreses a este canal"
        puthelp "PRIVMSG $chan :y escribas el comando: \002!renovar $accountid\002, antes del tiempo de expiracion."
        shelladmin::activate $accountid
        putlog "Creando nueva cuenta... ($accountid)"
    }
}

proc shelladmin::help {nick uhost hand chan text} {
    global botnick

    if {![channel get $chan shelladmin]} { return 0 }

    puthelp "PRIVMSG $chan :$nick, Hola! soy \002$botnick\002!. Registrate en $shelladmin::url y sigue las instrucciones."
    puthelp "PRIVMSG $chan :Mis comandos son: !activar !renovar !info"
}

proc shelladmin::keep {nick uhost hand chan text} {
}

proc shelladmin::calcexpiration {time} {
    set diff [expr {$time - [clock seconds]}]
    set horas [expr $diff / 3600]
    if {$horas < 0 } {
        return "Menos de 1 hora."
    } else {
        return "$horas horas."
    }
}

proc shelladmin::info {nick uhost hand chan text} {
    set accountid [lindex $text 0]

    if {$accountid == ""} {
        puthelp "PRIVMSG $chan :$nick, escribe: $::lastbind \002cuenta\002"
        return 0
    }

    if {![shelladmin::findaccount $accountid]} {
        puthelp "PRIVMSG $chan :$nick, Ese usuario no existe."
        return 0
    }

    set timereg [shelladmin::getregtime $accountid]
    set lastupdate [shelladmin::getlastupdate $accountid]
    set duration [shelladmin::getduration $accountid]
    set timeexpiration [shelladmin::calcexpiration $duration]

    puthelp "PRIVMSG $chan :$nick, Tu shell ha sido activada desde [clock format $timereg -format "%B %d, %Y, %l:%M %p"]. y la ultima renovacion fue en [clock format $lastupdate -format "%B %d, %Y, %l:%M %p"] tu shell tiene $timeexpiration antes de expirar. Necesitaras escribir el comando: \002!renovar $nick\002 para renovar tu cuenta por $shelladmin::hours_use horas."
}

proc shelladmin::peak {nick uhost hand chan text} {

    if {![channel get $chan shelladmin]} { return 0 }

    set fd [open $shelladmin::dbpeak "r"]
    set peak [gets $fd]
    close $fd
    puthelp "PRIVMSG $chan :$nick, he visto un pico de $peak de personas en $chan"
}

proc shelladmin:uptime {nick uhost hand chan text} {
    putserv "PRIVMSG $chan :[shelladmin::genuptime]"
}

proc shelladmin::join {nick uhost hand chan} {

    if {![channel get $chan shelladmin]} { return 0 }

    shelladmin::updatepeak
}

proc shelladmin::activate {accountid} {

    sqlite3 sdb $shelladmin::database
    sdb eval {UPDATE shelladmin SET status=1 WHERE accountid=$accountid}
    sdb close
}

proc shelladmin::banacc {nick uhost hand chan text} {
    set accountid [lindex $text 0]

    if {$accountid == ""} {
        puthelp "NOTICE $nick :\002Sintaxis:\002 $::lastbind \002cuenta\002"
        return 0
    }

    sqlite3 sdb $shelladmin::database
    sdb eval {UPDATE shelladmin SET status=2 WHERE accountid=$accountid}
    sdb close

    puthelp "PRIVMSG $shelladmin::channel :Administracion de cuentas: Abuso detectado desde: $accountid"
    puthelp "PRIVMSG $shelladmin::channel :Administracion de cuentas: Suspendiendo cuenta..."
    puthelp "PRIVMSG $shelladmin::channel :Administracion de cuentas: $accountid ha sido rechazado."
    puthelp "PRIVMSG $shelladmin::channel :Administracion de cuentas: Procesando..."
    puthelp "PRIVMSG $shelladmin::channel :Administracion de cuentas: El usuario esta baneado porque hizo cosas malas, como actividades ilegales (autoban)"

    puthelp "NOTICE $nick :La cuenta \002$accountid\002 ha sido baneada."
}

proc shelladmin::updatepeak {} {
    set fp [open $shelladmin::dbpeak "r"]
    set peak [read $fp]
    close $fp

    set fp [open $shelladmin::dbpeak "w"]
    puts $fp [expr $peak + 1]
    close $fp
}

proc shelladmin::reg {nick uhost hand chan text} {
    set accountid [lindex $text 0]

    if {$accountid == ""} {
        puthelp "NOTICE $nick :\002Sintaxis:\002 $::lastbind \002cuenta\002"
        return 0
    }

    if {![shelladmin::findaccount $accountid]} {
        shelladmin::adduser $accountid
        puthelp "NOTICE $chan :La cuenta \002$accountid\002 ha sido creada (falta de activacion)"
    }
}

proc shelladmin::adduser {accountid} {
    sqlite3 sdb $shelladmin::database
    set now [clock seconds]
    set bonus [clock add $now $shelladmin::hours_use hours]
    sdb eval {INSERT INTO shelladmin (accountid,regtime,duration,lastupdatetime,status) VALUES ($accountid,$now,$bonus,$now,0)}
    sdb close
}

proc shelladmin::statusaccount {accountid} {
    sqlite3 sdb $shelladmin::database

    set status [sdb eval {SELECT status FROM shelladmin WHERE accountid=$accountid}]
    sdb close

    return $status
}

proc shelladmin::findaccount {accountid} {
    sqlite3 sdb $shelladmin::database

    if {[llength [sdb eval {SELECT accountid FROM shelladmin WHERE accountid=$accountid}]] == 0} {
        sdb close
        return 0
    }
    sdb close

    return 1
}

proc shelladmin::getregtime {accountid} {
    sqlite3 sdb $shelladmin::database

    set regtime [sdb eval {SELECT regtime FROM shelladmin WHERE accountid=$accountid}]
    sdb close

    return $regtime
}

proc shelladmin::getduration {accountid} {
    sqlite3 sdb $shelladmin::database

    set duration [sdb eval {SELECT duration FROM shelladmin WHERE accountid=$accountid}]
    sdb close

    return $duration
}

proc shelladmin::getlastupdate {accountid} {
    sqlite3 sdb $shelladmin::database

    set lastupdate [sdb eval {SELECT lastupdatetime FROM shelladmin WHERE accountid=$accountid}]
    sdb close

    return $lastupdate
}

proc shelladmin::genuptime { } {
    if {[catch {exec uptime} uptime]} { set uptime "Uptime no disponible." }
    if {[catch {exec uname -o} machine]} { set machine [unames] }
    if {[catch {exec hostname} hostname]} { set hostname [info hostname] }
    return "Uptime para $hostname ($machine): es $uptime"
}

if {![file exists $shelladmin::database]} {
    sqlite3 sdb $shelladmin::database

    sdb eval {CREATE TABLE shelladmin (id INTEGER PRIMARY KEY AUTOINCREMENT, accountid TEXT NOT NULL COLLATE NOCASE, regtime INTEGER NOT NULL, duration INTEGER NOT NULL, lastupdatetime INTEGER NOT NULL, status INTEGER NOT NULL)}
    sdb close
}

if {![file exists $shelladmin::dbpeak]} {
    set fp [open $shelladmin::dbpeak "w"]
    puts $fp "0"
    close $fp
}

putlog "\002Shell Admin v1.0 - Loaded\002"
