#!/bin/bash
date=$(date +%Y%m%d-%H%M%S)
#-+-+-+-+-+-+ Configure de de ser necesario: -+-+-+-+-+-+
export PATH=$PATH:/root/MegaFuse #Directorio donde instalo o compilo MegaFuse
export PATH=$PATH:/root/megatools #Opcional, no necesaria. Directorio donde instalo o compilo megatools
MEGAFUSE_CONF=${MEGAFUSE_CONF:=~/.megafuse.conf} #Coloque la ruta de su archivo de configuracion en lugar de '~/.megafuse.conf'. Archivo default utilizado.
MEGAFUSE_LOG=/tmp/MegaFuse.$date.log #Ruta de archivo de logs de MegaFuse.
#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

#Solo permitiremos una instancia en ejecucion de este script a la vez:
pidof=$(pidof -x $(echo "$0" | awk -F\/ '{print $NF}'))
if [ "$(echo "$pidof" | wc -w)" -gt "1" ] ; then echo "Script en Ejecucion, saliendo..." ; exit -1; fi

MEGAFUSE=$(which MegaFuse)
IFS=$'\n'

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ] ; then
   echo -e "Ejecute:\n"
   echo -e "$0 /path/to/local/dir /path/to/mega/dir [--delete]\n"
   echo "or"
   echo -e "\nMEGAFUSE_CONF=/path/to/megafuse.conf $0 /path/to/local/dir /path/to/mega/dir [--delete]\n"
   echo -e "Opciones:\n  --delete : Elimina archivos/directorios en el directorio DESTINO que no se encuentren en el origen.\n"
   exit -1
fi
if [ "$3" != "" ] && [ "$3" != "--delete" ] ; then
   echo "Opcion '$3' no valida. Salir"
   exit 1
fi

if [ ! -f $MEGAFUSE_CONF ] ; then echo -e "\n $MEGAFUSE_CONF NO existe. Necesita configurar Usuario, Password y Punto de Montaje para utilizar el servicio de Mega como un file system, favor de revisar. Salir.\n"; exit -1; fi
mountpoint=$(grep MOUNTPOINT $MEGAFUSE_CONF | sed 's/ //g' | awk -F\= '{print $2}')
if [ "$mountpoint" == "" ] || [ ! -d $mountpoint ] ; then echo -e "\n Directorio de montaje '$mountpoint' NO existe. Revise $MEGAFUSE_CONF o cree el directorio '$mountpoint'. Salir. \n"; exit -1; fi


function mount_megafuse {
   df | grep "$mountpoint" | grep megafuse | grep -v pts >/dev/null 2>&1
   if [ "$?" != "0" ] ; then
      echo -e "\n + Intentando montar MegaFuse($mountpoint) ...\n"
      chmod 640 $MEGAFUSE_CONF #Solo mejorando la seguridad del archivo.
      #echo -e " Ejecutando: $comando_megafuse\n"
      mkdir /mnt/mymega #Dirty hack
      $MEGAFUSE -c $MEGAFUSE_CONF >> $MEGAFUSE_LOG 2>&1 & 
      pid_megafuse=$!
      #echo -e "Usted puede revisar el log del comando anterior con el comando 'tail -f $MEGAFUSE_LOG'\n"
      df | grep "$mountpoint" | grep megafuse | grep -v pts >/dev/null 2>&1
      montado=$?
      echo -n "Esperando que se monte MegaFuse ."
      segundos=0
      while [ ! "$montado" == "0" ]
      do
          echo -n " ."
          df | grep "$mountpoint" | grep megafuse | grep -v pts >/dev/null 2>&1
         montado=$?
         kill -s 0 $pid_megafuse >/dev/null 2>&1
         ejecutando=$?
         if [ "$ejecutando" != "0" ] || [ $segundos -gt 60 ] ; then
            echo -e "\nEl proceso '$pid_megafuse' termino o se supero el tiempo de $segundos segundos y NO pudo montarse el el filesystem $mountpoint. Revise su configuracion $MEGAFUSE_CONF o instalacion de MegaFuse. Salir."
            rmdir /mnt/mymega
            killall -9 MegaFuse
            exit -1
         fi
         sleep 2
         let segundos=segundos+2
      done
      rmdir /mnt/mymega
      echo -e "\nMegaFuse($mountpoint) esta montado OK."
      #df | grep "$mountpoint" | grep megafuse | grep -v pts
      #echo -e "\nNota: Por un bug en MegaFuse(Enero 2015) posiblemento no reporte correctamente el espacio disponible.\n"
   fi 
}
mount_megafuse

dir_origen=$(readlink -f $1)
dir_destino=$(readlink -f $2)
if [ ! -d $dir_origen ] || [ ! -d $dir_destino ] ; then
   echo "Directorio origen o destino no existen o no pueden ser leidos. Salir."
   exit -1
fi

if [ "$3" == "--delete" ] ; then
   #------------------------------------
   echo -e "\n + Buscando y eliminando directorios en el DESTINO que no se encuentren en el ORIGEN..."
   find $dir_destino -type d > /tmp/dirs_destino.$date.lst

   dir_o=$(echo $dir_origen | sed 's/\//\\\//g')
   dir_d=$(echo $dir_destino | sed 's/\//\\\//g')

   sed -i "s/$dir_d/$dir_o/g" /tmp/dirs_destino.$date.lst
   for i in $(cat /tmp/dirs_destino.$date.lst); do stat $i >/dev/null 2>&1 ; if [ "$?" != "0" ] ; then echo "$i"; fi; done | sort -r > /tmp/dirs_destino_borrar.$date.lst
   rm -f /tmp/dirs_destino.$date.lst
   sed -i "s/$dir_o/$dir_d/g" /tmp/dirs_destino_borrar.$date.lst
   for i in $(cat /tmp/dirs_destino_borrar.$date.lst)
   do
      #stat $i >/dev/null 2>&1 ; if [ "$?" != "0" ] ; then echo "No podre borrar DIR $i"; fi
      #En Mega, rmdir elimina directorios NO vacios:
      rmdir $i || rm -rf $i >/dev/null 2>&1 ; if [ "$?" != "0" ] ; then echo "No podre borrar DIR $i"; fi
      echo -n " ."
   done
   rm /tmp/dirs_destino_borrar.$date.lst
   #------------------------------------
   echo -e "\n + Buscando y eliminando archivos en el DESTINO que no se encuentren en el ORIGEN..."
   find $dir_destino -type f > /tmp/archs_destino.$date.lst
   sed -i "s/$dir_d/$dir_o/g" /tmp/archs_destino.$date.lst
   for i in $(cat /tmp/archs_destino.$date.lst); do stat $i >/dev/null 2>&1 ; if [ "$?" != "0" ] ; then echo "$i"; fi; done | sort -r > /tmp/archs_destino_borrar.$date.lst
   #rm -f /tmp/archs_destino.$date.lst
   sed -i "s/$dir_o/$dir_d/g" /tmp/archs_destino_borrar.$date.lst
   for i in $(cat /tmp/archs_destino_borrar.$date.lst)
   do
      #stat $i >/dev/null 2>&1 ; if [ "$?" != "0" ] ; then echo "No podre borrar ARCH $i"; fi
      rm -f $i >/dev/null 2>&1 ; if [ "$?" != "0" ] ; then echo "No podre borrar ARCH $i"; fi
      echo -n " ."
   done
   rm /tmp/archs_destino_borrar.$date.lst
fi

#------------------------------------
MEGASYNC=$(which megasync)
if [ ! -f $MEGASYNC ] || [ ! -f ~/.megarc ] ; then
   echo "No existe el ejecutable 'megasync' o su archivo de configuracion '.megarc'. No se utilizara."
else
   echo -e "\n + Copiando con 'megasync' archivos/directorios que no existen en el DESTINO...\n" #(Obtuve mejor velocidad de trasferencia.)
   fs_mega=$(df | grep "$mountpoint" | grep megafuse | grep -v pts | awk '{print $NF}'| sed 's/\//\\\//g')
   dir_d_mega=$(echo "$dir_destino" | sed "s/$fs_mega//g")
   echo "Desmontando '$mountpoint' temporalmente ..." #Fix Necesario para que 'No duplique' archivos la sincronizacion con 'cp -u' (bug raro de Mega)
   umount $mountpoint

   $MEGASYNC --reload -l $dir_origen/ -r /Root$dir_d_mega 2>/dev/null
   echo "'megasync' done."

   echo "Montando '$mountpoint' ..."
   mount_megafuse
fi
#------------------------------------
echo -e "\n + Sincronizando con 'cp -u' archivos/directorios que no existen en el DESTINO (Archivos actualizados)...\n"
sync
sleep 2
files="/tmp/files.list.$date"
dirs="/tmp/dirs.list.$date"
find $dir_origen -type f | sort > /tmp/archs_origen.$date.lst
find $dir_origen -type d | sort > /tmp/dirs_origen.$date.lst
if [ "$?" != "0" ]; then
   echo "Problema con el directorio origen( $dir_origen ). Revise."
   exit -1
fi

#Creamos todos los directorios destino.
echo "Creando directorios destino ..."
for absdirname in $(cat /tmp/dirs_origen.$date.lst)
do
   s2=$(echo $1 | sed 's/\//\\\//g')
   reldir=$(echo "$absdirname/" | sed "s/$s2//g")

   dirdestino="$2/$reldir"
   dirdestino=$(echo $dirdestino | sed 's/\/\//\//g')
   if [ ! -d "$dirdestino" ]; then echo -n " ."; mkdir -p $dirdestino; fi
done
echo "  Directorios destino [done]"

#Copiamos todos los archivos.
echo "Copiando/Actualizando archivos. [Leyenda: +=Archivo existe y no necesita actualiacion.]"
for absfilename in $(cat /tmp/archs_origen.$date.lst)
do
   dirname=$(dirname $absfilename)
   basename=$(basename $absfilename)

   s2=$(echo $1 | sed 's/\//\\\//g')
   reldir=$(echo "$dirname/" | sed "s/$s2//g")

   #echo "ABSFILENAME: $absfilename"
   #echo "DIRNAME: $dirname"
   #echo "BASENAME: $basename"
   #echo "RELDIR: $reldir"

   dirdestino="$2/$reldir"
   dirdestino=$(echo $dirdestino | sed 's/\/\//\//g')
   #dirdestino=$(printf '%q\n' "$dirdestino")
   #if [ ! -d "$dirdestino" ]; then mkdir -p $dirdestino; fi

   comando="cp -uv \"$absfilename\" \"$dirdestino\" &"
   comando=$(echo $comando | sed 's/\/\//\//g')
   #size=$(ls -lh $absfilename | awk '{print $5}')
   #echo -e "\n($size) $absfilename [iniciando copia]"
   #echo -e "\n($size) $basename [iniciando copia]"
   #echo "$comando"
   running=$(eval $comando)
   if [ "$running" != "" ] ; then
      size=$(ls -lh $absfilename | awk '{print $5}')
      echo -e "\n($size) $running\n (Copiando/Actualizando. Espere ...)"
   else
      echo -n "+"
   fi
   num=$(jobs -l | grep cp | wc -l)
   if [ "$num" -gt 2 ]; then
      echo -e "\n   Waiting {$num} processes..."
      wait $!
   fi
done
echo ""

#Esperamos terminen todos los procesos.
num=$(jobs -l | grep cp | wc -l)
while [ ! "$num" == "0" ]
do
   echo -e "\n   Waiting {$num} processes..."
   wait
   num=$(jobs -l | grep cp | wc -l)
   jobs -l
done

#------------------------------------

rm -f /tmp/*.$date.lst
find /tmp/ -name "MegaFuse.*.log" -type f -mmin +1440 -delete #Borramos archivos de logs viejos de mas de 24 horas(1440 min)
echo -e "\nEl FS MegaFuse($mountpoint) esta montado. Si necesita desmontarlo, ejecute el comando 'umount $mountpoint'\n"
#df | grep "$mountpoint" | grep megafuse | grep -v pts
echo -e "\nDone."
exit 0
