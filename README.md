myMegaSync

myMegaSync: Script bash para sincronizar recursivamente archivos locales de un sistema Linux hacia el servicio de almacenamiento Mega (http://mega.co.nz). Basado en MegaFuse y Megatools(opcional)

Requisitos:

+ Sistema Linux con soporte para FUSE.

+ Instale y configure MegaFuse(https://github.com/matteoserva/MegaFuse) <- Obligatorio.

+ Instale Megatools(https://github.com/megous/megatools) <- Opcional.

Probado en Debian GNU/Linux 7 (wheezy). Si usted tiene otra distribucion Linux, puede probar chroot-distros(https://github.com/joseccnet/chroot-distros), una manera fácil y rápida de tener un ambiente Linux(en jaula chroot) en las distribuciones Linux más importantes: Debian, Ubuntu, Centos, Fedora, OpenSuse o KaliLinux. Arquitecturas i386 y x86_64

Con esta herramienta, usted podra realizar respaldos de su sistema Linux sincronizando directorios completos hacia el servicio de almacenamiento Mega (http://mega.co.nz).

¿Cómo funciona?

chmod 750 ./myMegaSync.sh

Ejecute:

./myMegaSync.sh /path/to/local/dir /path/to/mega/dir [--delete]

or

MEGAFUSE_CONF=/path/to/megafuse.conf ./myMegaSync.sh /path/to/local/dir /path/to/mega/dir [--delete]

Opciones:
  --delete : Elimina archivos/directorios en el directorio DESTINO que no se encuentren en el origen.

Observe que utilizando la variable 'MEGAFUSE_CONF', usted podra utilizar más de una cuenta de Mega (http://mega.co.nz).

Una vez que pruebe el funcionamiento de la herramienta por línea de comando, usted puede programar crones para que periodicamente respalde o sincronice sus archivos, ejemplo:

crontab -l
30 0,12 * * * MEGAFUSE_CONF=/root/.megafuse.cuenta01.conf /root/bin/myMegaSync.sh /home/me/proyecto /mnt/mega/respaldo_proyecto --delete >> /tmp/log_myMegaSync.log 2>&1

En el cron de ejemplo, a las 00:30 y 12:30 se respalda el directorio /home/me/proyecto en el directorio /respaldo_proyecto de Mega.

Nota: en las primeras lineas del script 'myMegaSync.sh' puede configurar algunas variables:

 #-+-+-+-+-+-+ Configure de de ser necesario: -+-+-+-+-+-+

export PATH=$PATH:/root/MegaFuse #Directorio donde instalo o compilo MegaFuse
export PATH=$PATH:/root/megatools #Opcional, no necesaria. Directorio donde instalo o compilo megatools
MEGAFUSE_CONF=${MEGAFUSE_CONF:=~/.megafuse.conf} #Coloque la ruta de su archivo de configuracion en lugar de '~/.megafuse.conf'. Archivo default utilizado.
MEGAFUSE_LOG=/tmp/MegaFuse.$date.log #Ruta de archivo de logs de MegaFuse.

 #-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 

+ Ejemplo de archivo de configuración para MegaFuse:

cat /root/.megafuse.conf
USERNAME = myemail@mailexample.com
PASSWORD = Pa$w0rDM3g4
 #### you can specify a mountpoint here, only absolute paths are supported.
MOUNTPOINT = /mnt/mega

+ Ejemplo de archivo de configuración para Megatools:

cat /root/.megarc
[Login]
Username = myemail@mailexample.com
Password = Pa$w0rDM3g4

Nota de responsabilidad: Usted es responsable de la utilización de estos scripts de forma correcta, por favor revise y pruebe estos de manera exhaustiva en un ambiente controlado antes de llevarlos a producción.
